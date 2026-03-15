import Foundation
import ShinsouSourceAPI

/// Concurrently searches across multiple catalogue sources to find the best
/// matching manga for a given title, then ranks results by title similarity.
actor SmartSearchEngine {

    // MARK: - Public API

    /// Searches all provided sources for manga matching `manga.title`.
    /// - Returns: An array of (source, results) pairs, sorted by the best
    ///   similarity score of the top result in each source (descending).
    func smartSearch(
        title: String,
        sources: [any CatalogueSource]
    ) async -> [(source: any CatalogueSource, results: [SManga])] {
        let cleaned = cleanTitle(title)
        guard !cleaned.isEmpty else { return [] }

        // Run all source searches concurrently.
        var rawResults: [(source: any CatalogueSource, results: [SManga])] = []

        await withTaskGroup(of: (any CatalogueSource, [SManga]).self) { group in
            for source in sources {
                group.addTask {
                    do {
                        let page = try await source.getSearchManga(
                            page: 0,
                            query: cleaned,
                            filters: []
                        )
                        // Sort the individual source results by similarity.
                        let sorted = page.mangas.sorted { lhs, rhs in
                            self.titleSimilarity(cleaned, lhs.title) >
                            self.titleSimilarity(cleaned, rhs.title)
                        }
                        return (source, sorted)
                    } catch {
                        return (source, [])
                    }
                }
            }

            for await pair in group {
                rawResults.append(pair)
            }
        }

        // Sort source groups so the group with the best top-result score comes first.
        let sorted = rawResults.sorted { lhs, rhs in
            let lScore = lhs.results.first.map { titleSimilarity(cleaned, $0.title) } ?? 0
            let rScore = rhs.results.first.map { titleSimilarity(cleaned, $0.title) } ?? 0
            return lScore > rScore
        }

        return sorted
    }

    // MARK: - Title Cleaning

    /// Strips common noise from a manga title so cross-source searches work better.
    ///
    /// Examples of removed content:
    /// - Text inside parentheses / square brackets: `(Manga)`, `[Web Comic]`
    /// - Common marketing suffixes: `- Manga Adaptation`, `: The Comic`, etc.
    nonisolated func cleanTitle(_ title: String) -> String {
        var cleaned = title

        // Remove content enclosed in round brackets.
        while let range = cleaned.range(of: #"\([^)]*\)"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        // Remove content enclosed in square brackets.
        while let range = cleaned.range(of: #"\[[^\]]*\]"#, options: .regularExpression) {
            cleaned.removeSubrange(range)
        }
        // Remove common suffixes (case-insensitive).
        let suffixes = [
            #"[\s:–\-]+manga$"#,
            #"[\s:–\-]+manhwa$"#,
            #"[\s:–\-]+manhua$"#,
            #"[\s:–\-]+the\s+comic$"#,
            #"[\s:–\-]+comic$"#,
            #"[\s:–\-]+manga\s+adaptation$"#,
            #"[\s:–\-]+official\s+comic$"#,
            #"[\s:–\-]+web$"#,
        ]
        for suffix in suffixes {
            if let range = cleaned.range(of: suffix, options: [.regularExpression, .caseInsensitive]) {
                cleaned.removeSubrange(range)
            }
        }

        return cleaned.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Title Similarity

    /// Returns a normalized similarity score in [0, 1] between two strings.
    /// Uses Levenshtein edit distance on lowercased strings.
    nonisolated func titleSimilarity(_ a: String, _ b: String) -> Double {
        let s1 = a.lowercased()
        let s2 = b.lowercased()

        guard !s1.isEmpty, !s2.isEmpty else {
            return s1.isEmpty && s2.isEmpty ? 1.0 : 0.0
        }

        // Fast path: exact match.
        if s1 == s2 { return 1.0 }

        // Fast path: one contains the other.
        if s1.contains(s2) || s2.contains(s1) {
            let longer = Double(max(s1.count, s2.count))
            let shorter = Double(min(s1.count, s2.count))
            return shorter / longer
        }

        let distance = levenshtein(s1, s2)
        let maxLen = Double(max(s1.count, s2.count))
        return 1.0 - (Double(distance) / maxLen)
    }

    // MARK: - Levenshtein Distance

    /// Classic dynamic-programming Levenshtein edit distance.
    private nonisolated func levenshtein(_ s: String, _ t: String) -> Int {
        let sChars = Array(s)
        let tChars = Array(t)
        let m = sChars.count
        let n = tChars.count

        // Use a single rolling row for O(n) space.
        var prev = Array(0...n)           // prev[j] = distance(s[0..<0], t[0..<j])
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            for j in 1...n {
                if sChars[i - 1] == tChars[j - 1] {
                    curr[j] = prev[j - 1]
                } else {
                    curr[j] = 1 + min(prev[j], curr[j - 1], prev[j - 1])
                }
            }
            swap(&prev, &curr)
        }
        return prev[n]
    }
}
