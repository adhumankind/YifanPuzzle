import AVFoundation
import UIKit

/// 游戏触觉震动与轻量级音效合成引擎
public final class GameFeedbackEngine {
    public static let shared = GameFeedbackEngine()

    private var audioPlayers: [String: [AVAudioPlayer]] = [:]
    private var playerIndices: [String: Int] = [:]
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareHaptics()
        setupAudioSession()
        preloadSounds()
    }

    private func prepareHaptics() {
        impactLight.prepare()
        impactMedium.prepare()
        notificationFeedback.prepare()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    /// 预加载内置或程序化合成的短音效（无外部音频文件时使用内存中 PCM 合成）
    private func preloadSounds() {
        // 尝试从 Bundle 加载真实音频，若无则使用程序化生成的真实微敲击声
        if audioPlayers["snap"] == nil {
            let pool = (0..<4).compactMap { _ in makeSyntheticSound(frequency: 880, duration: 0.08, type: .snap) }
            audioPlayers["snap"] = pool
            playerIndices["snap"] = 0
        }
        if audioPlayers["pickup"] == nil {
            let pool = (0..<3).compactMap { _ in makeSyntheticSound(frequency: 440, duration: 0.05, type: .soft) }
            audioPlayers["pickup"] = pool
            playerIndices["pickup"] = 0
        }
        if audioPlayers["win"] == nil {
            let pool = (0..<2).compactMap { _ in makeSyntheticSound(frequency: 660, duration: 0.35, type: .chime) }
            audioPlayers["win"] = pool
            playerIndices["win"] = 0
        }
    }

    /// 播放拾取音效与触感
    public func triggerPickup() {
        if GameSettings.shared.hapticsEnabled {
            impactLight.impactOccurred(intensity: 0.6)
        }
        if GameSettings.shared.soundEnabled {
            playSound("pickup")
        }
    }

    /// 播放放下音效与触感
    public func triggerDrop() {
        if GameSettings.shared.hapticsEnabled {
            impactLight.impactOccurred(intensity: 0.4)
        }
    }

    /// 播放磁吸入位音效与清脆震动反馈
    public func triggerSnap() {
        if GameSettings.shared.hapticsEnabled {
            impactMedium.impactOccurred(intensity: 0.85)
        }
        if GameSettings.shared.soundEnabled {
            playSound("snap")
        }
    }

    /// 播放完成关卡庆祝反馈
    public func triggerVictory() {
        if GameSettings.shared.hapticsEnabled {
            notificationFeedback.notificationOccurred(.success)
        }
        if GameSettings.shared.soundEnabled {
            playSound("win")
        }
    }

    private func playSound(_ name: String) {
        guard let pool = audioPlayers[name], !pool.isEmpty else { return }
        let currentIndex = playerIndices[name] ?? 0
        let player = pool[currentIndex]
        playerIndices[name] = (currentIndex + 1) % pool.count

        player.currentTime = 0
        player.play()
    }

    private enum SyntheticType { case snap, soft, chime }

    /// 生成轻快清脆的 16-bit PCM WAV 音效
    private func makeSyntheticSound(frequency: Double, duration: Double, type: SyntheticType) -> AVAudioPlayer? {
        let sampleRate: Double = 44100.0
        let totalSamples = Int(sampleRate * duration)
        var samples = [Int16]()
        samples.reserveCapacity(totalSamples)

        for i in 0 ..< totalSamples {
            let t = Double(i) / sampleRate
            let progress = Double(i) / Double(totalSamples)

            // 音量包络衰减
            let envelope: Double
            switch type {
            case .snap:
                envelope = pow(1.0 - progress, 2.5) // 急速衰减，表现咔哒硬木质感
            case .soft:
                envelope = pow(1.0 - progress, 1.8)
            case .chime:
                envelope = (1.0 - progress) * (sin(progress * .pi * 4) * 0.2 + 0.8)
            }

            // 基础正弦波与谐波混响
            let angle = 2.0 * .pi * frequency * t
            let harmonic = 2.0 * .pi * (frequency * 1.5) * t
            let raw = sin(angle) * 0.7 + sin(harmonic) * 0.3
            let val = Int16(clamping: Int(raw * envelope * 28000.0))
            samples.append(val)
        }

        // 构建标准 RIFF WAV 头
        var data = Data()
        let byteRate = Int32(sampleRate * 2)
        let blockAlign = Int16(2)
        let bitsPerSample = Int16(16)
        let dataSize = Int32(samples.count * 2)
        let chunkSize = 36 + dataSize

        data.append(contentsOf: "RIFF".utf8)
        var cs = chunkSize; data.append(Data(bytes: &cs, count: 4))
        data.append(contentsOf: "WAVE".utf8)
        data.append(contentsOf: "fmt ".utf8)
        var sub1: Int32 = 16; data.append(Data(bytes: &sub1, count: 4))
        var audioFmt: Int16 = 1; data.append(Data(bytes: &audioFmt, count: 2))
        var numChannels: Int16 = 1; data.append(Data(bytes: &numChannels, count: 2))
        var sr = Int32(sampleRate); data.append(Data(bytes: &sr, count: 4))
        var br = byteRate; data.append(Data(bytes: &br, count: 4))
        var ba = blockAlign; data.append(Data(bytes: &ba, count: 2))
        var bps = bitsPerSample; data.append(Data(bytes: &bps, count: 2))
        data.append(contentsOf: "data".utf8)
        var ds = dataSize; data.append(Data(bytes: &ds, count: 4))

        samples.withUnsafeBytes { buffer in
            data.append(contentsOf: buffer)
        }

        return try? AVAudioPlayer(data: data)
    }
}
