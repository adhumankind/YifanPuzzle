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

    /// 成就定义（成就系统雏形：中心思想是鼓励体验拼图乐趣，绝不惩罚玩家）
    public enum Achievement: String, CaseIterable {
        case firstWin       // 初次通关
        case noAssistWin    // 不用道具独立完成
        case level5Win      // 完成第 5 级 700 块
        case allImagesDone  // 收集完成全部图案

        public var title: String {
            switch self {
            case .firstWin: return "初次通关"
            case .noAssistWin: return "独立完成"
            case .level5Win: return "登峰造极"
            case .allImagesDone: return "收藏大家"
            }
        }

        public var spriteName: String {
            switch self {
            case .firstWin: return "sprite_ach_first"
            case .noAssistWin: return "sprite_ach_solo"
            case .level5Win: return "sprite_ach_peak"
            case .allImagesDone: return "sprite_ach_all"
            }
        }
    }

    private let userDefaultsKey = "com.yifan.puzzle.records"
    private let achievementsKey = "com.yifan.puzzle.achievements"
    private var records: [String: LevelRecord] = [:] // key: "\(imageId)_\(levelId)"
    private var unlocked: Set<String> = []
    private let lock = NSLock()

    private init() {
        loadRecords()
        unlocked = Set(UserDefaults.standard.stringArray(forKey: achievementsKey) ?? [])
    }

    private func recordKey(imageId: String, levelId: Int) -> String {
        return "\(imageId)_\(levelId)"
    }

    private func loadRecords() {
        lock.lock()
        defer { lock.unlock() }
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
        lock.lock()
        defer { lock.unlock() }
        return records[recordKey(imageId: imageId, levelId: levelId)]
    }

    public func markCompleted(imageId: String, levelId: Int, elapsedSeconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
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
        lock.lock()
        defer { lock.unlock() }
        return records.values.filter { $0.isCompleted }.count
    }

    /// 通关后评估成就解锁情况，返回本次新解锁的成就
    public func evaluateAchievements(imageId: String, levelId: Int, usedAssistProps: Bool) -> [Achievement] {
        lock.lock()
        defer { lock.unlock() }

        var newlyUnlocked: [Achievement] = []
        func unlock(_ achievement: Achievement, when condition: Bool) {
            guard condition, !unlocked.contains(achievement.rawValue) else { return }
            unlocked.insert(achievement.rawValue)
            newlyUnlocked.append(achievement)
        }

        unlock(.firstWin, when: true)
        unlock(.noAssistWin, when: !usedAssistProps)
        unlock(.level5Win, when: levelId == 5)
        let totalImages = PuzzleImageRepository.shared.allItems().count
        let completedImages = Set(records.values.filter { $0.isCompleted }.map { $0.imageId }).count
        unlock(.allImagesDone, when: totalImages > 0 && completedImages >= totalImages)

        if !newlyUnlocked.isEmpty {
            UserDefaults.standard.set(Array(unlocked), forKey: achievementsKey)
        }
        return newlyUnlocked
    }

    /// 当前已解锁的全部成就（按枚举定义顺序）
    public func allAchievements() -> [(achievement: Achievement, isUnlocked: Bool)] {
        lock.lock()
        defer { lock.unlock() }
        return Achievement.allCases.map { ($0, unlocked.contains($0.rawValue)) }
    }

    /// 判断某个等级是否已解锁
    public func isLevelUnlocked(_ level: PuzzleLevel) -> Bool {
        if level.unlockRequiredStars == 0 { return true }
        return completedCount() >= level.unlockRequiredStars
    }

    /// 重置所有进度
    public func resetAllProgress() {
        lock.lock()
        defer { lock.unlock() }
        records.removeAll()
        unlocked.removeAll()
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: achievementsKey)
    }
}
