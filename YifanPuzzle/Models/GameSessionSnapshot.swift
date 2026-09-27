import Foundation
import CoreGraphics

/// 单块碎片的保存状态
public struct SavedPieceState: Codable {
    public let id: Int
    public let currentX: CGFloat
    public let currentY: CGFloat
    public let rotation: CGFloat
    public let isPlaced: Bool
    public let traySlotIndex: Int? // 若在5格托盘中，保存格子编号 0-4
    public let groupId: Int
}

/// 局中存档快照
public struct GameSessionSnapshot: Codable {
    public let imageId: String
    public let levelId: Int
    public let elapsedTime: TimeInterval
    public let pieces: [SavedPieceState]
    public let splitRatio: Double
    public let timestamp: Date
    public let usedAssistProps: Bool? // 旧版本快照无此字段，解码为 nil
}

/// 局中保存管理器
public final class SessionSaveManager {
    public static let shared = SessionSaveManager()

    private let saveKey = "com.yifan.puzzle.session_snapshot"

    private init() {}

    public func save(snapshot: GameSessionSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: saveKey)
        }
    }

    public func load() -> GameSessionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: saveKey),
              let snapshot = try? JSONDecoder().decode(GameSessionSnapshot.self, from: data) else {
            return nil
        }
        return snapshot
    }

    public func clear() {
        UserDefaults.standard.removeObject(forKey: saveKey)
    }
}
