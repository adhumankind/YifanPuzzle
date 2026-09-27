import SwiftUI
import SpriteKit

/// 对局主容器视图（纯横屏 HUD + SpriteKit 底层场景）
public struct GamePlayView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @State private var currentImageItem: PuzzleImageItem
    @State private var currentLevel: PuzzleLevel

    @State private var placedCount: Int = 0
    @State private var totalCount: Int = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var timerActive = true
    @State private var showingPreview = false
    @State private var showingVictory = false
    @State private var showingSettings = false
    @State private var isLoadingPieces = true
    @State private var finalElapsed: TimeInterval = 0
    @State private var isUnderlayOn: Bool = GameSettings.shared.showGhostOutline
    @State private var showGuide = !UserDefaults.standard.bool(forKey: "com.yifan.puzzle.guide_seen")
    @StateObject private var tiltObserver = PreviewTiltObserver()

    // 内部持有的 SpriteKit 游戏场景
    @State private var scene: PuzzleGameScene? = nil

    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    public init(imageItem: PuzzleImageItem, level: PuzzleLevel) {
        _currentImageItem = State(initialValue: imageItem)
        _currentLevel = State(initialValue: level)
    }

    public var body: some View {
        GeometryReader { proxy in
            gameContent(proxy: proxy)
                .onAppear {
                    setupScene(size: proxy.size)
                }
                .onReceive(timer) { _ in
                    if timerActive && !showingVictory {
                        elapsedTime += 1
                    }
                }
                .sheet(isPresented: $showingSettings, onDismiss: {
                    timerActive = true
                }) {
                    SettingsView()
                        .onAppear {
                            timerActive = false
                        }
                }
                .onChange(of: GameSettings.shared.allowFreeRotation) { allow in
                    scene?.applyRotationSettingChanged(allowFree: allow)
                }
                .onChange(of: GameSettings.shared.showGhostOutline) { show in
                    isUnderlayOn = show
                    scene?.applyGhostOutlineSettingChanged(showGhost: show)
                }
                .onChange(of: GameSettings.shared.parallax3DEnabled) { enabled in
                    scene?.applyParallaxSettingChanged(enabled: enabled)
                }
                .onChange(of: scenePhase) { phase in
                    switch phase {
                    case .active:
                        if !showingSettings && !showingVictory {
                            timerActive = true
                        }
                    case .inactive, .background:
                        timerActive = false
                        scene?.cancelActiveDragging()
                    @unknown default:
                        break
                    }
                }
                .onChange(of: showingPreview) { showing in
                    // 看原图浮层的姿态视差与视差开关联动
                    if showing && GameSettings.shared.parallax3DEnabled {
                        tiltObserver.start()
                    } else {
                        tiltObserver.stop()
                    }
                }
        }
    }

    // MARK: - 主内容（拆分子视图，降低 SwiftUI 类型检查复杂度）

    @ViewBuilder
    private func gameContent(proxy: GeometryProxy) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // SpriteKit 游戏场景
            if let scene = scene {
                PuzzleGameViewRepresentable(scene: scene)
                    .ignoresSafeArea()
            }

            topHUD(proxy: proxy)
            propToolbar(proxy: proxy)

            // 首次进入对局的轻量引导浮层（加载完成后才出现；轻点任意处或 7 秒后自动淡出）
            if showGuide && !isLoadingPieces {
                guideOverlay
            }

            // 原图高清浮层弹窗
            if showingPreview {
                previewOverlay(proxy: proxy)
            }

            // 胜利结算浮层
            if showingVictory {
                victoryOverlay(proxy: proxy)
            }

            // 首次加载/高阶大关卡切片渲染遮罩过渡动画
            if isLoadingPieces {
                loadingOverlay
            }
        }
    }

    // MARK: - 顶部悬浮控制栏 HUD

    private func topHUD(proxy: GeometryProxy) -> some View {
        VStack {
            HStack(spacing: 16) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(MaillardTheme.cream)
                        .frame(width: 40, height: 40)
                        .background(MaillardTheme.warmGlass)
                        .overlay(Circle().stroke(MaillardTheme.warmStroke, lineWidth: 0.8))
                        .clipShape(Circle())
                }

                // 关卡信息与进度
                VStack(alignment: .leading, spacing: 2) {
                    Text(currentImageItem.title)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(MaillardTheme.cream)
                    Text("第\(currentLevel.id)级 · 进度: \(placedCount)/\(totalCount > 0 ? totalCount : currentLevel.pieceCount)")
                        .font(.system(size: 11))
                        .foregroundColor(MaillardTheme.muted)
                }

                Spacer()

                // 计时器显示
                HStack(spacing: 6) {
                    Image(systemName: "stopwatch.fill")
                        .foregroundColor(MaillardTheme.gold)
                    Text(formatTime(elapsedTime))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(MaillardTheme.cream)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MaillardTheme.warmGlass)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
                )

                // 原图预览按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPreview.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "eye.fill")
                        Text("看原图")
                    }
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(MaillardTheme.deep)
                    .frame(width: 94, height: 34)
                    .background(
                        Image("sprite_btn_gold")
                            .resizable()
                            .scaledToFit()
                            .shadow(color: Color.black.opacity(0.30), radius: 5, y: 2)
                    )
                }

                // 参考底图快捷开关（极淡单色半透明，随时对照）
                Button {
                    isUnderlayOn.toggle()
                    GameSettings.shared.showGhostOutline = isUnderlayOn
                    scene?.applyGhostOutlineSettingChanged(showGhost: isUnderlayOn)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isUnderlayOn ? "ruler.fill" : "ruler")
                        Text("底图")
                    }
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .foregroundColor(isUnderlayOn ? MaillardTheme.deep : MaillardTheme.cream)
                    .frame(width: 78, height: 34)
                    .background(
                        Group {
                            if isUnderlayOn {
                                Rectangle().fill(MaillardTheme.goldGradient)
                            } else {
                                Rectangle().fill(MaillardTheme.warmGlass)
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isUnderlayOn ? Color.white.opacity(0.25) : MaillardTheme.warmStroke, lineWidth: 0.8)
                    )
                    .cornerRadius(12)
                }

                // 局中快速设置按钮（随时切换自由角度/音效）
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(MaillardTheme.cream)
                        .frame(width: 36, height: 36)
                        .background(MaillardTheme.warmGlass)
                        .overlay(Circle().stroke(MaillardTheme.warmStroke, lineWidth: 0.8))
                        .clipShape(Circle())
                }
            }
            .padding(.leading, max(24, proxy.safeAreaInsets.leading + 12))
            .padding(.trailing, max(24, proxy.safeAreaInsets.trailing + 12))
            .padding(.top, max(12, proxy.safeAreaInsets.top + 6))

            Spacer()
        }
    }

    // MARK: - 底部左侧无限辅助道具

    private func propToolbar(proxy: GeometryProxy) -> some View {
        HStack(spacing: 18) {
            Button {
                scene?.giveHint()
            } label: {
                propIcon("sprite_magnifier")
            }
            .buttonStyle(MaillardTheme.pressStyle)

            Button {
                scene?.autoPlaceOnePiece()
            } label: {
                propIcon("sprite_wand")
            }
            .buttonStyle(MaillardTheme.pressStyle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .padding(.leading, max(18, proxy.safeAreaInsets.leading + 10))
        .padding(.bottom, max(14, proxy.safeAreaInsets.bottom + 8))
    }

    // MARK: - 首次引导浮层

    private var guideOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    dismissGuide()
                }

            VStack(spacing: 14) {
                Image("sprite_hand")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 92)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, y: 4)

                Text("欢迎来到一凡爱拼图")
                    .font(.system(size: 22, weight: .heavy, design: .serif))
                    .foregroundColor(MaillardTheme.cream)

                Text("拖动碎片到左侧拼图板，位置正确会自动咔哒吸附；\n左下角两只道具无限次帮你找位置、自动拼块。")
                    .font(.system(size: 13))
                    .foregroundColor(MaillardTheme.cream.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)

                Text("轻点任意处开始")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(MaillardTheme.gold)
                    .padding(.top, 4)
            }
            .padding(28)
            .background(MaillardTheme.espresso.opacity(0.92))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(MaillardTheme.gold.opacity(0.35), lineWidth: 1.2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 24)
            .padding(.horizontal, 60)
        }
        .transition(.opacity)
        .task {
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            if showGuide {
                dismissGuide()
            }
        }
    }

    private func dismissGuide() {
        withAnimation(.easeInOut(duration: 0.35)) {
            showGuide = false
        }
        UserDefaults.standard.set(true, forKey: "com.yifan.puzzle.guide_seen")
    }

    // MARK: - 原图高清浮层弹窗

    private func previewOverlay(proxy: GeometryProxy) -> some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPreview = false
                    }
                }

            VStack(spacing: 12) {
                if let uiImg = PuzzleImageRepository.shared.loadImage(for: currentImageItem) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: proxy.size.width * 0.75, maxHeight: proxy.size.height * 0.75)
                        .cornerRadius(12)
                        .shadow(radius: 20)
                        .rotation3DEffect(
                            .degrees(Double(min(max(tiltObserver.roll, -0.3), 0.3)) * (GameSettings.shared.parallax3DEnabled ? 9 : 0)),
                            axis: (x: 0, y: 1, z: 0),
                            perspective: 0.6
                        )
                        .rotation3DEffect(
                            .degrees(Double(min(max(tiltObserver.pitch, -0.3), 0.3)) * (GameSettings.shared.parallax3DEnabled ? -7 : 0)),
                            axis: (x: 1, y: 0, z: 0),
                            perspective: 0.6
                        )
                        .animation(.linear(duration: 0.08), value: tiltObserver.roll)
                }
                Button("关闭原图") {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingPreview = false
                    }
                }
                .font(.system(size: 14, weight: .bold, design: .serif))
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(MaillardTheme.warmGlass)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
                )
                .foregroundColor(MaillardTheme.cream)
                .cornerRadius(10)
            }
        }
        .transition(.opacity)
    }

    // MARK: - 胜利结算浮层

    private func victoryOverlay(proxy: GeometryProxy) -> some View {
        VictoryCelebrationView(
            imageItem: currentImageItem,
            level: currentLevel,
            elapsedTime: finalElapsed,
            newAchievements: scene?.newlyEarnedAchievements ?? [],
            onNext: nextAvailablePuzzleParams().map { nextItem, nextLvl in
                {
                    switchToNextPuzzle(item: nextItem, level: nextLvl, size: proxy.size)
                }
            },
            onReplay: {
                showingVictory = false
                setupScene(size: proxy.size)
            },
            onBack: {
                dismiss()
            }
        )
    }

    // MARK: - 加载遮罩

    private var loadingOverlay: some View {
        ZStack {
            MaillardTheme.deep.ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: MaillardTheme.gold))
                    .scaleEffect(1.6)

                VStack(spacing: 6) {
                    Text("正在为您精心雕琢 \(currentLevel.pieceCount) 块 3D 拼图...")
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(MaillardTheme.cream)

                    Text("程序化贝塞尔锯齿切片 & 浮雕光影贴图合成中")
                        .font(.system(size: 12))
                        .foregroundColor(MaillardTheme.muted)
                }
            }
        }
        .transition(.opacity)
    }

    // MARK: - 场景构建与流转

    private func setupScene(size: CGSize) {
        guard size.width > 0 && size.height > 0 else { return }
        let img = PuzzleImageRepository.shared.loadImage(for: currentImageItem) ?? PuzzleImageRepository.generateFallbackImage(title: currentImageItem.title)
        let s = PuzzleGameScene(size: size, imageItem: currentImageItem, level: currentLevel, sourceImage: img)
        self.totalCount = currentLevel.pieceCount

        // 尝试恢复已保存的计时进度
        if let snapshot = SessionSaveManager.shared.load(), snapshot.imageId == currentImageItem.id && snapshot.levelId == currentLevel.id {
            self.elapsedTime = snapshot.elapsedTime
        } else {
            self.elapsedTime = 0
        }
        self.timerActive = true

        s.onProgressUpdate = { [weak s] placed, total in
            _ = s
            self.placedCount = placed
            self.totalCount = total
        }

        s.onPiecesReady = { [weak s] in
            _ = s
            withAnimation(.easeInOut(duration: 0.3)) {
                self.isLoadingPieces = false
            }
        }

        s.onGameCompleted = { [weak s] elapsed in
            _ = s
            self.timerActive = false
            self.finalElapsed = elapsed
            self.showingVictory = true
        }

        self.scene = s
    }

    private func nextAvailablePuzzleParams() -> (PuzzleImageItem, PuzzleLevel)? {
        let config = PuzzleConfig.default
        let allItems = PuzzleImageRepository.shared.allItems()

        // 1. 同一等级下的下一幅图
        let currentLevelItems = allItems.filter { currentLevel.imageIds.contains($0.id) }
        if let currentIndex = currentLevelItems.firstIndex(where: { $0.id == currentImageItem.id }),
           currentIndex + 1 < currentLevelItems.count {
            return (currentLevelItems[currentIndex + 1], currentLevel)
        }

        // 2. 跨入下一关卡的第 1 幅图
        if let lvlIndex = config.levels.firstIndex(where: { $0.id == currentLevel.id }),
           lvlIndex + 1 < config.levels.count {
            let nextLevel = config.levels[lvlIndex + 1]
            if ProgressManager.shared.isLevelUnlocked(nextLevel) {
                let nextLevelItems = allItems.filter { nextLevel.imageIds.contains($0.id) }
                if let firstItem = nextLevelItems.first {
                    return (firstItem, nextLevel)
                }
            }
        }

        return nil
    }

    private func switchToNextPuzzle(item: PuzzleImageItem, level: PuzzleLevel, size: CGSize) {
        self.showingVictory = false
        self.isLoadingPieces = true
        self.currentImageItem = item
        self.currentLevel = level
        self.placedCount = 0
        self.totalCount = level.pieceCount
        setupScene(size: size)
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d:%02d", m, s)
    }

    /// 无限辅助道具按钮外观（金色立体图标 + ∞ 次数角标）
    private func propIcon(_ name: String) -> some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(height: 40)
            .shadow(color: Color.black.opacity(0.40), radius: 5, y: 2)
            .overlay(alignment: .topTrailing) {
                Text("∞")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(MaillardTheme.cream)
                    .padding(3)
                    .background(Circle().fill(MaillardTheme.caramel))
                    .offset(x: 9, y: -7)
            }
    }
}
