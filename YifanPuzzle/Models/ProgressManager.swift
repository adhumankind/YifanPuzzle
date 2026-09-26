import Foundation

/// 拼图游玩进度与单关卡记录
public struct LevelRecord: Codable {
    public let imageId: String
    public let levelId: Int
    public var isCompleted: Bool
    public var bestTimeInSeconds: TimeInterval
    public var completedDate: Date?

    public init(imageId: String, levelId: Int, isCompleted: Bool = false, bestTimeInSeconds: TimeInterval = 0, completedDate: Date? = nil) {
        self.imageId = imageId
        self.levelId = levelId
        self.isCompleted = isCompleted
        self.bestTimeInSeconds = bestTimeInSeconds
        self.completedDate = completedDate
    }
}

/// 进度存档管理器
public final class ProgressManager {
    public static let shared = ProgressManager()

    private let userDefaultsKey = "com.yifan.puzzle.records"
    private var records: [String: LevelRecord] = [:] // key: "\(imageId)_\(levelId)"

    private init() {
        loadRecords()
    }

    private func recordKey(imageId: String, levelId: Int) -> String {
        return "\(imageId)_\(levelId)"
    }

    private func loadRecords() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([String: LevelRecord].self, from: data) {
            self.records = decoded
        }
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }

    public func getRecord(imageId: String, levelId: Int) -> LevelRecord? {
        return records[recordKey(imageId: imageId, levelId: levelId)]
    }

    public func markCompleted(imageId: String, levelId: Int, elapsedSeconds: TimeInterval) {
        let key = recordKey(imageId: imageId, levelId: levelId)
        var record = records[key] ?? LevelRecord(imageId: imageId, levelId: levelId)
        record.isCompleted = true
        record.completedDate = Date()
        if record.bestTimeInSeconds == 0 || elapsedSeconds < record.bestTimeInSeconds {
            record.bestTimeInSeconds = elapsedSeconds
        }
        records[key] = record
        saveRecords()
    }

    /// 计算已完成的总关卡星数（用于判断下一等级解锁）
    public func completedCount() -> Int {
        return records.values.filter { $0.isCompleted }.count
    }

    /// 判断某个等级是否已解锁
    public func isLevelUnlocked(_ level: PuzzleLevel) -> Bool {
        if level.unlockRequiredStars == 0 { return true }
        return completedCount() >= level.unlockRequiredStars
    }

    /// 重置所有进度
    public func resetAllProgress() {
        records.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
}
