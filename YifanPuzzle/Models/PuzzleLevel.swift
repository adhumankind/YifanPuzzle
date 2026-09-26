import Foundation

/// 拼图等级定义模型
public struct PuzzleLevel: Identifiable, Codable, Hashable {
    public let id: Int                   // 等级 1-5（以后可扩展更多级）
    public let name: String              // 等级名称，如 "初出茅庐", "熟能生巧"
    public let pieceCount: Int           // 碎片总数：35, 70, 160, 350, 700
    public let gridColumns: Int          // 横向切分列数
    public let gridRows: Int             // 纵向切分行数
    public let description: String       // 难度说明
    public let imageIds: [String]        // 该等级关联的初始图库 ID
    public let unlockRequiredStars: Int  // 解锁条件：需要此前完成的关卡数

    public init(id: Int, name: String, pieceCount: Int, gridColumns: Int, gridRows: Int, description: String, imageIds: [String], unlockRequiredStars: Int = 0) {
        self.id = id
        self.name = name
        self.pieceCount = pieceCount
        self.gridColumns = gridColumns
        self.gridRows = gridRows
        self.description = description
        self.imageIds = imageIds
        self.unlockRequiredStars = unlockRequiredStars
    }

    /// 校验切分行列积与 pieceCount 是否一致
    public var isValidGrid: Bool {
        return gridColumns * gridRows == pieceCount
    }
}

/// 关卡总配置包装器
public struct PuzzleConfig: Codable {
    public var version: String
    public var levels: [PuzzleLevel]

    public init(version: String = "1.0", levels: [PuzzleLevel]) {
        self.version = version
        self.levels = levels
    }

    /// 默认先缓后陡 5 级配置（35, 70, 160, 350, 700）
    /// 7×5=35, 10×7=70, 16×10=160, 25×14=350, 35×20=700 (均为接近 16:9 的标准网格)
    public static let `default`: PuzzleConfig = {
        let l1 = PuzzleLevel(id: 1, name: "初出茅庐", pieceCount: 35, gridColumns: 7, gridRows: 5, description: "入门级 35 块，轻快易上手", imageIds: ["puzzle_01", "puzzle_02"], unlockRequiredStars: 0)
        let l2 = PuzzleLevel(id: 2, name: "渐入佳境", pieceCount: 70, gridColumns: 10, gridRows: 7, description: "进阶级 70 块，适合休闲挑战", imageIds: ["puzzle_03", "puzzle_04"], unlockRequiredStars: 1)
        let l3 = PuzzleLevel(id: 3, name: "熟能生巧", pieceCount: 160, gridColumns: 16, gridRows: 10, description: "高手级 160 块，考验观察力", imageIds: ["puzzle_05", "puzzle_06"], unlockRequiredStars: 2)
        let l4 = PuzzleLevel(id: 4, name: "炉火纯青", pieceCount: 350, gridColumns: 25, gridRows: 14, description: "大师级 350 块，专注沉浸", imageIds: ["puzzle_07", "puzzle_08"], unlockRequiredStars: 3)
        let l5 = PuzzleLevel(id: 5, name: "登峰造极", pieceCount: 700, gridColumns: 35, gridRows: 20, description: "宗师级 700 块，终极耐力挑战", imageIds: ["puzzle_09", "puzzle_10"], unlockRequiredStars: 4)
        return PuzzleConfig(levels: [l1, l2, l3, l4, l5])
    }()
}
