import Foundation

/// Token-bucket rate limiter modeled after Shinsou's RateLimitInterceptor.
///
/// Usage:
/// ```
/// let limiter = RateLimiter(permits: 5, period: 1.0)  // 5 requests/sec
/// limiter.acquire()  // blocks until a permit is available
/// ```
final class RateLimiter {
    private let permits: Int
    private let periodSeconds: TimeInterval
    private var requestTimestamps: [CFAbsoluteTime] = []
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 1)

    /// - Parameters:
    ///   - permits: Number of requests allowed within the period.
    ///   - period: The time window in seconds.
    init(permits: Int, period: TimeInterval) {
        self.permits = max(1, permits)
        self.periodSeconds = max(0.1, period)
    }

    /// Blocks the calling thread until a permit is available.
    func acquire() {
        semaphore.wait()
        defer { semaphore.signal() }

        lock.lock()
        let now = CFAbsoluteTimeGetCurrent()
        let windowStart = now - periodSeconds

        // Remove expired timestamps
        while !requestTimestamps.isEmpty && requestTimestamps.first! <= windowStart {
            requestTimestamps.removeFirst()
        }

        if requestTimestamps.count >= permits {
            // Must wait until the oldest request expires
            let oldestTimestamp = requestTimestamps.first!
            let waitTime = oldestTimestamp + periodSeconds - now
            lock.unlock()

            if waitTime > 0 {
                Thread.sleep(forTimeInterval: waitTime)
            }

            // Re-acquire and clean up after waiting
            lock.lock()
            let newNow = CFAbsoluteTimeGetCurrent()
            let newWindowStart = newNow - periodSeconds
            while !requestTimestamps.isEmpty && requestTimestamps.first! <= newWindowStart {
                requestTimestamps.removeFirst()
            }
            requestTimestamps.append(newNow)
            lock.unlock()
        } else {
            requestTimestamps.append(now)
            lock.unlock()
        }
    }
}

// MARK: - Per-host rate limiter registry

/// Manages per-host rate limiters so each domain gets its own bucket.
final class RateLimiterRegistry {
    static let shared = RateLimiterRegistry()

    private var limiters: [String: RateLimiter] = [:]
    private let lock = NSLock()

    /// Default: 3 requests per second per host
    var defaultPermits: Int = 3
    var defaultPeriod: TimeInterval = 1.0

    private init() {}

    /// Get or create a rate limiter for the given host.
    func limiter(for host: String) -> RateLimiter {
        lock.lock()
        defer { lock.unlock() }

        if let existing = limiters[host] {
            return existing
        }

        let limiter = RateLimiter(permits: defaultPermits, period: defaultPeriod)
        limiters[host] = limiter
        return limiter
    }

    /// Register a custom rate limit for a specific host.
    func register(host: String, permits: Int, period: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        limiters[host] = RateLimiter(permits: permits, period: period)
    }
}
