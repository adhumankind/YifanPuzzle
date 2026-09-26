import Foundation
import CoreGraphics

/// 拼图磁吸判定与成组系统
public final class SnapEngine {

    /// 判断单块拼图或碎片组是否接近其在拼图板上的目标位置
    /// - Parameters:
    ///   - currentPos: 当前中心坐标 (游戏场景中以拼图板为基准的相对坐标)
    ///   - targetPos: 理论上拼图板上的正确坐标
    ///   - pieceSize: 碎片的尺寸基准
    ///   - currentRotation: 当前碎片的旋转角度（弧度）
    ///   - allowFreeRotation: 是否开启了自由旋转
    /// - Returns: 是否触发磁吸
    public static func checkSnap(
        currentPos: CGPoint,
        targetPos: CGPoint,
        pieceSize: CGSize,
        currentRotation: CGFloat,
        allowFreeRotation: Bool
    ) -> Bool {
        // 1. 距离检测：当移动到正确位置约 40%~45% 碎片尺寸内即判定有效
        let dx = currentPos.x - targetPos.x
        let dy = currentPos.y - targetPos.y
        let distance = sqrt(dx * dx + dy * dy)
        let snapThreshold = min(pieceSize.width, pieceSize.height) * 0.45

        guard distance <= snapThreshold else { return false }

        // 2. 角度检测：若开启了自由角度旋转，必须旋转到接近 0°（正负 12°，约 0.21 弧度以内）才允许吸附
        if allowFreeRotation {
            let normalizedRotation = abs(currentRotation.truncatingRemainder(dividingBy: .pi * 2))
            let diffFromZero = min(normalizedRotation, .pi * 2 - normalizedRotation)
            let maxAngleTolerance: CGFloat = 12.0 * (.pi / 180.0) // 12度容差
            if diffFromZero > maxAngleTolerance {
                return false
            }
        }

        return true
    }

    /// 检测两块未拼好的碎片之间是否为网格相邻块，且相对距离满足互相咬合吸附
    public static func checkAdjacentPiecesSnap(
        pieceA: PuzzlePieceData,
        posA: CGPoint,
        rotA: CGFloat,
        pieceB: PuzzlePieceData,
        posB: CGPoint,
        rotB: CGFloat,
        pieceSize: CGSize,
        allowFreeRotation: Bool
    ) -> Bool {
        // 判断是否为上下或左右相邻
        let rowDiff = pieceB.row - pieceA.row
        let colDiff = pieceB.col - pieceA.col

        let isNeighbor = (abs(rowDiff) == 1 && colDiff == 0) || (abs(colDiff) == 1 && rowDiff == 0)
        guard isNeighbor else { return false }

        // 若开启自由旋转，两块碎片的相对旋转差必须很小
        if allowFreeRotation {
            let rotDiff = abs((rotA - rotB).truncatingRemainder(dividingBy: .pi * 2))
            let diff = min(rotDiff, .pi * 2 - rotDiff)
            if diff > 12.0 * (.pi / 180.0) {
                return false
            }
        }

        // 计算理论相对位移矢量
        let expectedDeltaX = CGFloat(colDiff) * pieceSize.width
        let expectedDeltaY = CGFloat(rowDiff) * pieceSize.height

        let actualDeltaX = posB.x - posA.x
        let actualDeltaY = posB.y - posA.y

        let errorX = actualDeltaX - expectedDeltaX
        let errorY = actualDeltaY - expectedDeltaY
        let errorDist = sqrt(errorX * errorX + errorY * errorY)

        let threshold = min(pieceSize.width, pieceSize.height) * 0.35
        return errorDist <= threshold
    }
}
