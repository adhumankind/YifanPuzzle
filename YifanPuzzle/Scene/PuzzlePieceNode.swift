import SpriteKit
import UIKit

/// 单块碎片的 SpriteKit 游戏节点包装
public final class PuzzlePieceNode: SKNode {
    public let pieceData: PuzzlePieceData

    // 视觉子节点
    public let shadowSprite: SKSpriteNode
    public let bevelSprite: SKSpriteNode
    public let surfaceSprite: SKSpriteNode

    // 状态属性
    public var isPlaced: Bool = false
    public var traySlotIndex: Int? = nil // 若在 5 格托盘中，保存其格子编号 0-4
    public var groupId: Int // 成组编号，相邻吸附成组后拥有相同的 groupId

    // 初始位置与正确吸附位置（拼图板坐标系下）
    public var correctBoardPosition: CGPoint = .zero

    public init(pieceData: PuzzlePieceData, textures: PuzzlePieceRenderer.RenderedPieceTexture) {
        self.pieceData = pieceData
        self.groupId = pieceData.id

        // 阴影节点（层级最底 zPosition: 0）
        self.shadowSprite = SKSpriteNode(texture: textures.shadowTexture)
        self.shadowSprite.zPosition = 0
        self.shadowSprite.alpha = 0.55

        // 挤出厚度暗边节点（zPosition: 1）
        self.bevelSprite = SKSpriteNode(texture: textures.bevelThicknessTexture)
        self.bevelSprite.zPosition = 1

        // 正面图案表层节点（zPosition: 2）
        self.surfaceSprite = SKSpriteNode(texture: textures.surfaceTexture)
        self.surfaceSprite.zPosition = 2

        super.init()

        self.name = "piece_\(pieceData.id)"
        self.isUserInteractionEnabled = false // 统一由主 Scene 集中分发手势，保障组拖动性能

        addChild(shadowSprite)
        addChild(bevelSprite)
        addChild(surfaceSprite)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 拿起动画：3D 立体抬升、放大 1.08 倍、阴影拉开并模糊加深
    public func animatePickup() {
        guard !isPlaced else { return }
        removeAction(forKey: "drop")

        let liftAction = SKAction.group([
            SKAction.scale(to: 1.08, duration: 0.12),
            SKAction.run {
                self.shadowSprite.run(SKAction.group([
                    SKAction.move(to: CGPoint(x: 8.0, y: -10.0), duration: 0.12),
                    SKAction.fadeAlpha(to: 0.75, duration: 0.12)
                ]))
            }
        ])
        liftAction.timingMode = .easeOut
        run(liftAction, withKey: "pickup")
    }

    /// 放下动画：恢复原始大小、阴影贴回
    public func animateDrop() {
        guard !isPlaced else { return }
        removeAction(forKey: "pickup")

        let dropAction = SKAction.group([
            SKAction.scale(to: 1.0, duration: 0.15),
            SKAction.run {
                self.shadowSprite.run(SKAction.group([
                    SKAction.move(to: .zero, duration: 0.15),
                    SKAction.fadeAlpha(to: 0.55, duration: 0.15)
                ]))
            }
        ])
        dropAction.timingMode = .easeOut
        run(dropAction, withKey: "drop")
    }

    /// 成功磁吸归位动画：平滑弹簧入位、归正角度、移除阴影、锁定不可拖动
    public func animateSnap(to targetPosition: CGPoint, completion: (() -> Void)? = nil) {
        self.isPlaced = true
        self.traySlotIndex = nil
        self.zPosition = 10 // 拼好后固定在拼图底板平整层

        let moveAction = SKAction.move(to: targetPosition, duration: 0.18)
        moveAction.timingMode = .easeOut

        let rotateAction = SKAction.rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        rotateAction.timingMode = .easeOut

        let scaleAction = SKAction.scale(to: 1.0, duration: 0.18)
        scaleAction.timingMode = .easeOut

        let shadowFade = SKAction.run {
            self.shadowSprite.run(SKAction.fadeOut(withDuration: 0.15))
        }

        let snapGroup = SKAction.group([moveAction, rotateAction, scaleAction, shadowFade])
        run(snapGroup) {
            completion?()
        }
    }
}
