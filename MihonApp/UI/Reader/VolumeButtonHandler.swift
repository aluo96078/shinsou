import Foundation
import AVFoundation
import MediaPlayer
import UIKit
import Combine

/// 透過 KVO 監聽系統音量變化來偵測音量鍵按下事件。
/// 偵測到音量變化後立即將音量重設回原始值，實現「無聲」攔截音量鍵作為翻頁控制。
final class VolumeButtonHandler: NSObject, ObservableObject {

    enum VolumeButtonEvent {
        case up, down
    }

    /// 音量鍵事件回呼
    var onVolumeButtonPressed: ((VolumeButtonEvent) -> Void)?

    private var audioSession: AVAudioSession?
    private var volumeView: MPVolumeView?
    private var silentPlayer: AVAudioPlayer?
    private var previousVolume: Float = 0.5
    private var isObserving = false
    private var isResetting = false

    // MARK: - Public

    func start() {
        guard !isObserving else { return }
        setupAudioSession()
        setupVolumeObserver()
    }

    func stop() {
        removeVolumeObserver()
    }

    deinit {
        removeVolumeObserver()
    }

    // MARK: - Audio Session

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        audioSession = session
        previousVolume = session.outputVolume
    }

    private func reassertAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
    }

    // MARK: - Volume Observer

    private func setupVolumeObserver() {
        guard let session = audioSession else { return }

        // KVO 監聽 outputVolume
        if !isObserving {
            session.addObserver(self, forKeyPath: "outputVolume", options: [.new], context: nil)
            isObserving = true
        }

        // 音頻中斷處理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )

        // 播放靜音音效，保持 audio session 活躍以抑制系統音量 HUD
        if silentPlayer == nil {
            if let player = try? AVAudioPlayer(data: makeSilentWavData()) {
                player.numberOfLoops = -1
                player.volume = 0
                player.play()
                silentPlayer = player
            }
        }

        // 隱藏的 MPVolumeView，用於透過 UISlider 程式化設定音量
        DispatchQueue.main.async { [weak self] in
            let vv = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
            vv.alpha = 0.01
            if let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap({ $0.windows })
                .first(where: { $0.isKeyWindow }) {
                window.addSubview(vv)
            }
            self?.volumeView = vv
        }
    }

    private func removeVolumeObserver() {
        if isObserving {
            audioSession?.removeObserver(self, forKeyPath: "outputVolume")
            isObserving = false
        }
        NotificationCenter.default.removeObserver(self)
        silentPlayer?.stop()
        silentPlayer = nil
        let vv = volumeView
        volumeView = nil
        audioSession = nil
        onVolumeButtonPressed = nil
        if Thread.isMainThread {
            vv?.removeFromSuperview()
        } else {
            DispatchQueue.main.async {
                vv?.removeFromSuperview()
            }
        }
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

            // 跳過自身重設音量所觸發的回呼
            if self.isResetting {
                self.isResetting = false
                return
            }

            // 偵測方向
            if newVolume > self.previousVolume {
                self.onVolumeButtonPressed?(.up)
            } else if newVolume < self.previousVolume {
                self.onVolumeButtonPressed?(.down)
            }

            // 重設回使用者原始音量，確保可連續偵測
            self.isResetting = true
            if let slider = self.volumeView?.subviews.compactMap({ $0 as? UISlider }).first {
                slider.value = self.previousVolume
            }
        }
    }

    // MARK: - Interruption

    @objc private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
        if type == .ended {
            reassertAudioSession()
        }
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
