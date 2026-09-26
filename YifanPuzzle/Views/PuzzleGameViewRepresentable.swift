import SwiftUI
import SpriteKit

/// SpriteKit 游戏视图的 SwiftUI 包装器
public struct PuzzleGameViewRepresentable: UIViewRepresentable {
    public let scene: PuzzleGameScene

    public init(scene: PuzzleGameScene) {
        self.scene = scene
    }

    public func makeUIView(context: Context) -> SKView {
        let skView = SKView()
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.backgroundColor = .clear
        skView.presentScene(scene)
        return skView
    }

    public func updateUIView(_ uiView: SKView, context: Context) {
        // 尺寸变更自适应
        if uiView.bounds.size != scene.size && uiView.bounds.size.width > 0 {
            scene.size = uiView.bounds.size
        }
    }
}
