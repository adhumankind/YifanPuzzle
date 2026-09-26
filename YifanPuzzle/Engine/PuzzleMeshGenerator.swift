import Foundation
import CoreGraphics
import UIKit

/// 边缘榫卯类型：平直外边框、凸起、凹陷
public enum EdgeTabType: Int, Codable {
    case flat = 0     // 外边缘平直
    case tabOut = 1   // 凸出卡榫
    case tabIn = -1   // 凹入卡槽

    public var inverted: EdgeTabType {
        switch self {
        case .flat: return .flat
        case .tabOut: return .tabIn
        case .tabIn: return .tabOut
        }
    }
}

/// 单块碎片的四边边缘形态
public struct PieceEdges: Codable, Equatable {
    public let top: EdgeTabType
    public let right: EdgeTabType
    public let bottom: EdgeTabType
    public let left: EdgeTabType

    public init(top: EdgeTabType, right: EdgeTabType, bottom: EdgeTabType, left: EdgeTabType) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

/// 单块碎片的数据描述
public struct PuzzlePieceData: Identifiable, Codable {
    public let id: Int                 // 唯一序号 0 ..< pieceCount
    public let row: Int                // 网格行 (0 ..< rows)
    public let col: Int                // 网格列 (0 ..< cols)
    public let edges: PieceEdges       // 四边边缘榫卯定义
    public let targetGridNormalized: CGPoint // 归一化正确位置 (0.0 - 1.0)
    public let normalizedSize: CGSize  // 归一化宽高

    public init(id: Int, row: Int, col: Int, edges: PieceEdges, targetGridNormalized: CGPoint, normalizedSize: CGSize) {
        self.id = id
        self.row = row
        self.col = col
        self.edges = edges
        self.targetGridNormalized = targetGridNormalized
        self.normalizedSize = normalizedSize
    }
}

/// 伪随机数生成器（线性同余），保证同一张图和同一关卡每次切割算法结果绝对一致且无锁
public struct SeededRandom {
    private var state: UInt64

    public init(seed: UInt64) {
        self.state = seed != 0 ? seed : 0xDEADBEEFCAFE
    }

    public mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    public mutating func nextBool() -> Bool {
        return (next() & 0x1) == 1
    }
}

/// 网格切割生成器
public final class PuzzleMeshGenerator {

    /// 基于列数、行数和随机种子，生成整套碎片的边缘互锁结构
    public static func generateGrid(columns: Int, rows: Int, seed: UInt64) -> [PuzzlePieceData] {
        var rng = SeededRandom(seed: seed)

        // 水平内边缘数组：(rows - 1) 行，每行 columns 条边缘
        // horizontalEdges[r][c] 表示第 r 行底边（也是第 r+1 行顶边）的卡榫朝向
        var horizontalEdges: [[EdgeTabType]] = Array(repeating: Array(repeating: .flat, count: columns), count: max(0, rows - 1))
        for r in 0 ..< max(0, rows - 1) {
            for c in 0 ..< columns {
                horizontalEdges[r][c] = rng.nextBool() ? .tabOut : .tabIn
            }
        }

        // 垂直内边缘数组：rows 行，每行 (columns - 1) 条边缘
        // verticalEdges[r][c] 表示第 c 列右边（也是第 c+1 列左边）的卡榫朝向
        var verticalEdges: [[EdgeTabType]] = Array(repeating: Array(repeating: .flat, count: max(0, columns - 1)), count: rows)
        for r in 0 ..< rows {
            for c in 0 ..< max(0, columns - 1) {
                verticalEdges[r][c] = rng.nextBool() ? .tabOut : .tabIn
            }
        }

        var pieces: [PuzzlePieceData] = []
        let normWidth = 1.0 / CGFloat(columns)
        let normHeight = 1.0 / CGFloat(rows)

        var pieceId = 0
        for r in 0 ..< rows {
            for c in 0 ..< columns {
                // Top
                let top: EdgeTabType
                if r == 0 {
                    top = .flat
                } else {
                    top = horizontalEdges[r - 1][c].inverted
                }

                // Bottom
                let bottom: EdgeTabType
                if r == rows - 1 {
                    bottom = .flat
                } else {
                    bottom = horizontalEdges[r][c]
                }

                // Left
                let left: EdgeTabType
                if c == 0 {
                    left = .flat
                } else {
                    left = verticalEdges[r][c - 1].inverted
                }

                // Right
                let right: EdgeTabType
                if c == columns - 1 {
                    right = .flat
                } else {
                    right = verticalEdges[r][c]
                }

                let edges = PieceEdges(top: top, right: right, bottom: bottom, left: left)
                let targetX = (CGFloat(c) + 0.5) * normWidth
                let targetY = (CGFloat(r) + 0.5) * normHeight

                let piece = PuzzlePieceData(
                    id: pieceId,
                    row: r,
                    col: c,
                    edges: edges,
                    targetGridNormalized: CGPoint(x: targetX, y: targetY),
                    normalizedSize: CGSize(width: normWidth, height: normHeight)
                )
                pieces.append(piece)
                pieceId += 1
            }
        }

        return pieces
    }
}
