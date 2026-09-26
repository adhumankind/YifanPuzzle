import SwiftUI
import SpriteKit

/// 对局主容器视图（纯横屏 HUD + SpriteKit 底层场景）
public struct GamePlayView: View {
    @Environment(\.dismiss) var dismiss
    public let imageItem: PuzzleImageItem
    public let level: PuzzleLevel

    @State private var placedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerActive = true
    @State private var showingPreview = false
    @State private var showingVictory = false
    @State private var finalElapsed: TimeInterval = 0

    // 内部持有的 SpriteKit 游戏场景
    @State private var scene: PuzzleGameScene? = nil

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init(imageItem: PuzzleImageItem, level: PuzzleLevel) {
        self.imageItem = imageItem
        self.level = level
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                // SpriteKit 游戏场景
                if let scene = scene {
                    PuzzleGameViewRepresentable(scene: scene)
                        .ignoresSafeArea()
                }

                // 顶部悬浮控制栏 HUD
                VStack {
                    HStack(spacing: 16) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 40, height: 40)
                                .background(Color.black.opacity(0.55))
                                .clipShape(Circle())
                        }

                        // 关卡信息与进度
                        VStack(alignment: .leading, spacing: 2) {
                            Text(imageItem.title)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("第\(level.id)级 · 进度: \(placedCount)/\(totalCount > 0 ? totalCount : level.pieceCount)")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.7))
                        }

                        Spacer()

                        // 计时器显示
                        HStack(spacing: 6) {
                            Image(systemName: "stopwatch.fill")
                                .foregroundColor(.yellow)
                            Text(formatTime(elapsedTime))
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(12)

                        // 原图预览按钮
                        Button {
                            showingPreview.toggle()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.fill")
                                Text("看原图")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.85))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                    Spacer()
                }

                // 原图高清浮层弹窗
                if showingPreview {
                    ZStack {
                        Color.black.opacity(0.8).ignoresSafeArea()
                            .onTapGesture { showingPreview = false }

                        VStack(spacing: 12) {
                            if let uiImg = PuzzleImageRepository.shared.loadImage(for: imageItem) {
                                Image(uiImage: uiImg)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: proxy.size.width * 0.75, maxHeight: proxy.size.height * 0.75)
                                    .cornerRadius(12)
                                    .shadow(radius: 20)
                            }
                            Button("关闭原图") {
                                showingPreview = false
                            }
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }

                // 胜利结算浮层
                if showingVictory {
                    VictoryCelebrationView(
                        imageItem: imageItem,
                        level: level,
                        elapsedTime: finalElapsed,
                        onReplay: {
                            showingVictory = false
                            setupScene(size: proxy.size)
                        },
                        onBack: {
                            dismiss()
                        }
                    )
                }
            }
            .onAppear {
                setupScene(size: proxy.size)
            }
            .onReceive(timer) { _ in
                if timerActive && !showingVictory {
                    elapsedTime += 1
                }
            }
        }
    }

    private func setupScene(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let img = PuzzleImageRepository.shared.loadImage(for: imageItem) ?? PuzzleImageRepository.generateFallbackImage(title: imageItem.title)
        let s = PuzzleGameScene(size: size, imageItem: imageItem, level: level, sourceImage: img)
        self.placedCount = 0
        self.totalCount = level.pieceCount
        self.elapsedTime = 0
        self.timerActive = true

        s.onProgressUpdate = { [weak s] placed, total in
            _ = s
            self.placedCount = placed
            self.totalCount = total
        }

        s.onGameCompleted = { [weak s] elapsed in
            _ = s
            self.timerActive = false
            self.finalElapsed = elapsed
            self.showingVictory = true
        }

        self.scene = s
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
