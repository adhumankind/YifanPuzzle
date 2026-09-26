import Foundation
import Combine

/// 游戏全局偏好设置管理器
public final class GameSettings: ObservableObject {
    public static let shared = GameSettings()

    // 用户在需求中明确要求的设置项：是否允许卡片自由角度摆放
    @Published public var allowFreeRotation: Bool {
        didSet { UserDefaults.standard.set(allowFreeRotation, forKey: "allowFreeRotation") }
    }

    // 辅助设置项
    @Published public var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: "soundEnabled") }
    }

    @Published public var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: "hapticsEnabled") }
    }

    @Published public var showGhostOutline: Bool {
        didSet { UserDefaults.standard.set(showGhostOutline, forKey: "showGhostOutline") }
    }

    @Published public var parallax3DEnabled: Bool {
        didSet { UserDefaults.standard.set(parallax3DEnabled, forKey: "parallax3DEnabled") }
    }

    @Published public var splitRatio: Double {
        didSet { UserDefaults.standard.set(splitRatio, forKey: "splitRatio") }
    }

    private init() {
        self.allowFreeRotation = UserDefaults.standard.object(forKey: "allowFreeRotation") as? Bool ?? false
        self.soundEnabled = UserDefaults.standard.object(forKey: "soundEnabled") as? Bool ?? true
        self.hapticsEnabled = UserDefaults.standard.object(forKey: "hapticsEnabled") as? Bool ?? true
        self.showGhostOutline = UserDefaults.standard.object(forKey: "showGhostOutline") as? Bool ?? true
        self.parallax3DEnabled = UserDefaults.standard.object(forKey: "parallax3DEnabled") as? Bool ?? true
        self.splitRatio = UserDefaults.standard.object(forKey: "splitRatio") as? Double ?? 0.75
    }
}
