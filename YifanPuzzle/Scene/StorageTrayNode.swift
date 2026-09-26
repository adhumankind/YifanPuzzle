import SpriteKit
import UIKit

/// 5 格临时存放托盘节点
public final class StorageTrayNode: SKNode {
    public static let slotCount = 5

    private let backgroundNode: SKShapeNode
    private var slotNodes: [SKShapeNode] = []
    public private(set) var slotPieces: [Int: PuzzlePieceNode] = [:] // slotIndex (0-4) -> piece

    public let traySize: CGSize
    public let slotSize: CGSize

    public init(trayWidth: CGFloat, trayHeight: CGFloat = 80) {
        self.traySize = CGSize(width: trayWidth, height: trayHeight)
        let slotW = (trayWidth - CGFloat(Self.slotCount + 1) * 12) / CGFloat(Self.slotCount)
        let slotH = trayHeight - 20
        self.slotSize = CGSize(width: slotW, height: slotH)

        // 托盘底座：带有微圆角和 3D 毛玻璃质感半透明深色托盘
        let bgRect = CGRect(x: -trayWidth / 2, y: -trayHeight / 2, width: trayWidth, height: trayHeight)
        self.backgroundNode = SKShapeNode(rect: bgRect, cornerRadius: 18)
        self.backgroundNode.fillColor = UIColor(red: 0.12, green: 0.14, blue: 0.18, alpha: 0.88)
        self.backgroundNode.strokeColor = UIColor(white: 1.0, alpha: 0.22)
        self.backgroundNode.lineWidth = 1.5

        super.init()
        self.name = "StorageTrayNode"
        self.zPosition = 50 // 悬浮在游戏界面底部

        addChild(backgroundNode)

        // 构建 5 个独立凹槽格子
        let startX = -trayWidth / 2 + 12 + slotW / 2
        for i in 0 ..< Self.slotCount {
            let cx = startX + CGFloat(i) * (slotW + 12)
            let slotRect = CGRect(x: -slotW / 2, y: -slotH / 2, width: slotW, height: slotH)
            let slot = SKShapeNode(rect: slotRect, cornerRadius: 10)
            slot.position = CGPoint(x: cx, y: 0)
            slot.fillColor = UIColor(white: 0.05, alpha: 0.6)
            slot.strokeColor = UIColor(white: 1.0, alpha: 0.12)
            slot.lineWidth = 1.0
            slot.name = "tray_slot_\(i)"

            // 格子内部序号标签
            let label = SKLabelNode(fontNamed: "PingFangSC-Semibold")
            label.text = "\(i + 1)"
            label.fontSize = 14
            label.fontColor = UIColor(white: 1.0, alpha: 0.25)
            label.verticalAlignmentMode = .center
            label.horizontalAlignmentMode = .center
            slot.addChild(label)

            addChild(slot)
            slotNodes.append(slot)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 检测落点是否在托盘的某一个格子里
    public func hitSlotIndex(at scenePoint: CGPoint) -> Int? {
        let trayLocalPoint = convert(scenePoint, from: parent ?? self)
        for (i, slot) in slotNodes.enumerated() {
            let slotLocal = slot.convert(trayLocalPoint, from: self)
            let halfW = slotSize.width / 2
            let halfH = slotSize.height / 2
            if abs(slotLocal.x) <= halfW && abs(slotLocal.y) <= halfH {
                return i
            }
        }
        return nil
    }

    /// 获取某格子的全局世界坐标
    public func worldPosition(forSlot slotIndex: Int) -> CGPoint {
        guard slotIndex >= 0 && slotIndex < slotNodes.count else { return position }
        let slot = slotNodes[slotIndex]
        return convert(slot.position, to: parent ?? self)
    }

    /// 放入碎片到托盘
    public func placePiece(_ piece: PuzzlePieceNode, intoSlot slotIndex: Int) {
        // 如果该格已被占用，先移出原有碎片
        if let existing = slotPieces[slotIndex], existing != piece {
            existing.traySlotIndex = nil
            existing.run(SKAction.move(by: CGVector(dx: 0, dy: 60), duration: 0.15))
        }

        slotPieces[slotIndex] = piece
        piece.traySlotIndex = slotIndex

        let targetPos = worldPosition(forSlot: slotIndex)

        // 缩放适配托盘格子
        let scaleX = (slotSize.width * 0.85) / piece.surfaceSprite.size.width
        let scaleY = (slotSize.height * 0.85) / piece.surfaceSprite.size.height
        let fitScale = min(scaleX, scaleY, 0.8)

        let move = SKAction.move(to: targetPos, duration: 0.18)
        move.timingMode = .easeOut
        let scale = SKAction.scale(to: fitScale, duration: 0.18)
        let rotate = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)

        piece.run(SKAction.group([move, scale, rotate]))
    }

    /// 从托盘取出碎片
    public func removePiece(fromSlot slotIndex: Int) {
        if let p = slotPieces[slotIndex] {
            p.traySlotIndex = nil
            slotPieces.removeValue(forKey: slotIndex)
        }
    }

    /// 查找碎片所在槽位
    public func slotForPiece(_ piece: PuzzlePieceNode) -> Int? {
        return slotPieces.first { $0.value == piece }?.key
    }
}
