import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Combine

/// 透過 KVO 監聽系統音量變化來偵測音量鍵按下事件。
/// 偵測到音量變化後立即將音量重設回原始值，實現「無聲」攔截音量鍵作為翻頁控制。
///
/// 架構分為兩層：
/// - **HUD 抑制層**（常駐）：`installHUDSuppression()` / `removeHUDSuppression()`
///   管理 MPVolumeView + 靜音音效，設定開啟時即啟動，確保音量 HUD 永遠不會出現。
/// - **事件監聽層**（閱讀器）：`startListening()` / `stopListening()`
///   管理 KVO 監聽，僅在閱讀器開啟時啟用，偵測音量變化觸發翻頁。
final class VolumeButtonHandler: NSObject, ObservableObject {

    enum VolumeButtonEvent {
        case up, down
    }

    /// 單例，供 App 層級在啟動時安裝 HUD 抑制。
    static let shared = VolumeButtonHandler()

    /// 音量鍵事件回呼
    var onVolumeButtonPressed: ((VolumeButtonEvent) -> Void)?

    private var audioSession: AVAudioSession?
    private var volumeView: MPVolumeView?
    private var silentPlayer: AVAudioPlayer?
    private var previousVolume: Float = 0.5
    private var isObserving = false
    private var isHUDSuppressed = false

    /// 音量變化的最小閾值，低於此值視為浮點誤差或重設回彈，直接忽略。
    private let volumeThreshold: Float = 0.001

    private override init() {
        super.init()
    }

    // MARK: - HUD 抑制層（常駐）

    /// 安裝 HUD 抑制：將 MPVolumeView 加入視窗 + 播放靜音音效。
    /// 設定開啟時由 App 層級呼叫，進入閱讀器前就已就位。
    func installHUDSuppression() {
        guard !isHUDSuppressed else { return }
        isHUDSuppressed = true

        setupAudioSession()
        startSilentPlayback()
        installVolumeView()
        clampVolumeToSafeRange()

        // 監聽 App 回到前景，自動修復可能失效的 HUD 抑制
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    /// 移除 HUD 抑制，恢復系統預設音量 HUD 行為。
    func removeHUDSuppression() {
        guard isHUDSuppressed else { return }

        // 如果還在監聽中，先停止
        stopListening()

        isHUDSuppressed = false
        NotificationCenter.default.removeObserver(self)

        silentPlayer?.stop()
        silentPlayer = nil

        let vv = volumeView
        volumeView = nil
        audioSession = nil

        if Thread.isMainThread {
            vv?.removeFromSuperview()
        } else {
            DispatchQueue.main.async { vv?.removeFromSuperview() }
        }
    }

    // MARK: - 事件監聽層（閱讀器）

    /// 開始監聽音量變化（進入閱讀器時呼叫）。
    /// 如果 HUD 抑制尚未安裝，會自動安裝。
    func startListening() {
        if !isHUDSuppressed {
            installHUDSuppression()
        }

        // 確保基礎設施健康
        ensureInfrastructureHealthy()

        guard let session = audioSession, !isObserving else { return }

        // 重新讀取當前音量
        previousVolume = session.outputVolume
        clampVolumeToSafeRange()

        session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
        isObserving = true
    }

    /// 停止監聽音量變化（離開閱讀器時呼叫）。
    /// 注意：不會移除 HUD 抑制，MPVolumeView 保持常駐。
    func stopListening() {
        if isObserving {
            audioSession?.removeObserver(self, forKeyPath: "outputVolume")
            isObserving = false
        }
        onVolumeButtonPressed = nil
    }

    // MARK: - Legacy API

    func start() { startListening() }
    func stop() { stopListening() }

    deinit {
        if isObserving {
            audioSession?.removeObserver(self, forKeyPath: "outputVolume")
        }
        NotificationCenter.default.removeObserver(self)
        silentPlayer?.stop()
        volumeView?.removeFromSuperview()
    }

    // MARK: - KVO

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume",
              let newVolume = change?[.newKey] as? Float else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            let delta = newVolume - self.previousVolume

            // 忽略微小變化：重設回彈、浮點誤差
            // 當我們把音量重設回 previousVolume 時，KVO 會再次觸發，
            // 但 delta ≈ 0，自然被忽略，不需要 isResetting flag。
            guard abs(delta) > self.volumeThreshold else { return }

            // 偵測方向並觸發翻頁
            if delta > 0 {
                self.onVolumeButtonPressed?(.up)
            } else {
                self.onVolumeButtonPressed?(.down)
            }

            // 重設回原始音量，確保可連續偵測
            if !self.resetVolume() {
                // 重設失敗（slider 不可用），接受新音量作為基準
                self.previousVolume = newVolume
                // 重新檢查邊界
                self.clampVolumeToSafeRange()
            }
        }
    }

    // MARK: - Private: Setup

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        audioSession = session
        previousVolume = session.outputVolume

        // 音頻中斷處理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
    }

    private func startSilentPlayback() {
        guard silentPlayer == nil || silentPlayer?.isPlaying == false else { return }
        silentPlayer?.stop()
        if let player = try? AVAudioPlayer(data: makeSilentWavData()) {
            player.numberOfLoops = -1
            player.volume = 0
            player.play()
            silentPlayer = player
        }
    }

    private func installVolumeView() {
        guard volumeView == nil || volumeView?.superview == nil else { return }
        volumeView?.removeFromSuperview()
        let vv = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        vv.alpha = 0.01
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) {
            window.addSubview(vv)
        }
        vv.layoutIfNeeded()
        volumeView = vv
    }

    // MARK: - Private: Health Check

    /// 確保所有基礎設施仍然健康（靜音播放器在跑、MPVolumeView 在視窗中）。
    /// App 回到前景或開始監聽時呼叫。
    private func ensureInfrastructureHealthy() {
        guard isHUDSuppressed else { return }

        // 重新啟用 audio session（可能在背景被中斷）
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        audioSession = session

        // 確保靜音播放器在跑
        if silentPlayer == nil || silentPlayer?.isPlaying == false {
            startSilentPlayback()
        }

        // 確保 MPVolumeView 在視窗中
        if volumeView?.superview == nil {
            installVolumeView()
        }
    }

    // MARK: - Private: Volume Control

    /// 確保音量在安全範圍內（不在邊界 0 或 1），否則某個方向的按鍵不會觸發 KVO。
    private func clampVolumeToSafeRange() {
        let vol = previousVolume
        if vol <= 0.01 || vol >= 0.99 {
            previousVolume = 0.5
            _ = resetVolume()
        }
    }

    /// 透過 MPVolumeView 的 UISlider 將系統音量重設回 previousVolume。
    /// 回傳是否成功。
    @discardableResult
    private func resetVolume() -> Bool {
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else {
            return false
        }
        slider.value = previousVolume
        return true
    }

    // MARK: - Notifications

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended {
            ensureInfrastructureHealthy()
        }
    }

    /// App 回到前景時，修復可能在背景中失效的基礎設施。
    @objc private func handleDidBecomeActive() {
        ensureInfrastructureHealthy()
    }

    // MARK: - Silent WAV

    /// 產生靜音 WAV 資料（0.1 秒，8000Hz，8-bit mono）
    private func makeSilentWavData() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize: UInt32 = sampleRate / 10
        var d = Data()
        func appendU32(_ v: UInt32) { d.append(contentsOf: withUnsafeBytes(of: v.littleEndian, Array.init)) }
        func appendU16(_ v: UInt16) { d.append(contentsOf: withUnsafeBytes(of: v.littleEndian, Array.init)) }
        d.append(contentsOf: "RIFF".utf8)
        appendU32(36 + dataSize)
        d.append(contentsOf: "WAVE".utf8)
        d.append(contentsOf: "fmt ".utf8)
        appendU32(16)
        appendU16(1)          // PCM
        appendU16(1)          // mono
        appendU32(sampleRate)
        appendU32(sampleRate) // byteRate
        appendU16(1)          // blockAlign
        appendU16(8)          // bitsPerSample
        d.append(contentsOf: "data".utf8)
        appendU32(dataSize)
        d.append(contentsOf: [UInt8](repeating: 0x80, count: Int(dataSize)))
        return d
    }
}
