import SwiftUI

/// 关卡选择视图（参考知名拼图游戏横屏布局：左大图预览 + 右信息与大按钮 + 底部缩略图切换）
public struct LevelSelectView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedLevelIndex: Int = 0
    @State private var selectedImageIndex: Int = 0
    @State private var selectedImageForPlay: (PuzzleImageItem, PuzzleLevel)? = nil
    @State private var refreshTrigger = false
    @State private var showingFullPreview = false
    @State private var resumeImageId: String? = nil // 当前有对局存档的图案 id（单存档槽）

    private let config = PuzzleConfig.default

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 暖棕兜底（即使背景图异常也绝不以纯黑呈现）
                MaillardTheme.deep.ignoresSafeArea()

                // 美拉德通用底纹（深可可棕织物纹理）
                Image("maillard_bg_plain")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.16).ignoresSafeArea())

                VStack(spacing: 10) {
                    headerBar(proxy: proxy)

                    levelChips

                    // 主区域：左大图预览 + 右信息与开始按钮
                    mainArea(proxy: proxy)

                    thumbnailStrip
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            refreshTrigger.toggle()
            refreshResumeState()
        }
        .onChange(of: refreshTrigger) { _ in
            refreshResumeState()
        }
        .fullScreenCover(item: Binding(
            get: { selectedImageForPlay.map { PlayParams(item: $0.0, level: $0.1) } },
            set: { _ in
                selectedImageForPlay = nil
                refreshTrigger.toggle()
            }
        )) { params in
            GamePlayView(imageItem: params.item, level: params.level)
        }
        .fullScreenCover(isPresented: $showingFullPreview) {
            // 大图全屏查看（轻点任意处返回）
            ZStack {
                Color.black.opacity(0.93).ignoresSafeArea()
                    .onTapGesture {
                        showingFullPreview = false
                    }
                VStack(spacing: 14) {
                    if let item = selectedDisplayItem, let uiImg = PuzzleImageRepository.shared.loadImage(for: item) {
                        Image(uiImage: uiImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 1100, maxHeight: 560)
                            .cornerRadius(14)
                            .shadow(radius: 24)
                        Text(item.title)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(MaillardTheme.cream)
                    }
                    Text("轻点任意处返回")
                        .font(.system(size: 12))
                        .foregroundColor(MaillardTheme.muted)
                }
            }
        }
        .onAppear { refreshTrigger.toggle() }
    }

    // MARK: - 顶部导航栏

    private func headerBar(proxy: GeometryProxy) -> some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                    Text("返回主页")
                }
                .foregroundColor(MaillardTheme.cream)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(MaillardTheme.warmGlass)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
                )
            }

            Spacer()

            Text("选择挑战等级与图案")
                .font(.system(size: 19, weight: .bold, design: .serif))
                .foregroundColor(MaillardTheme.cream)
                .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)

            Spacer()

            HStack(spacing: 5) {
                Image("sprite_star")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .shadow(color: Color.black.opacity(0.40), radius: 3, y: 1)
                Text("\(ProgressManager.shared.completedCount())")
                    .foregroundColor(MaillardTheme.cream)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .id(refreshTrigger)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 6)
            .background(MaillardTheme.warmGlass)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
            )
        }
        .padding(.leading, max(24, proxy.safeAreaInsets.leading + 12))
        .padding(.trailing, max(24, proxy.safeAreaInsets.trailing + 12))
        .padding(.top, max(10, proxy.safeAreaInsets.top + 5))
    }

    // MARK: - 等级（难度梯度）选择器

    private var levelChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(config.levels.indices, id: \.self) { idx in
                    let lvl = config.levels[idx]
                    let unlocked = ProgressManager.shared.isLevelUnlocked(lvl)

                    Button {
                        if unlocked {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedLevelIndex = idx
                                selectedImageIndex = 0
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if !unlocked {
                                Image("sprite_lock")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                                    .opacity(0.85)
                            } else if lvl.id == config.levels.last?.id {
                                Image("sprite_crown")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 16)
                            } else {
                                Image("sprite_star")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                            }
                            Text("第\(lvl.id)级 · \(lvl.pieceCount)块")
                                .font(.system(size: 14, weight: .bold, design: .serif))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .foregroundColor(
                            selectedLevelIndex == idx ? MaillardTheme.deep
                            : (unlocked ? MaillardTheme.cream : MaillardTheme.muted.opacity(0.5))
                        )
                        .background(
                            Group {
                                if selectedLevelIndex == idx {
                                    RoundedRectangle(cornerRadius: 12).fill(MaillardTheme.goldGradient)
                                } else {
                                    RoundedRectangle(cornerRadius: 12).fill(MaillardTheme.warmGlass)
                                }
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedLevelIndex == idx ? Color.white.opacity(0.30) : MaillardTheme.warmStroke, lineWidth: 0.8)
                        )
                        .scaleEffect(selectedLevelIndex == idx ? 1.04 : 1.0)
                        .shadow(color: selectedLevelIndex == idx ? MaillardTheme.gold.opacity(0.35) : Color.clear, radius: 8, y: 2)
                        .overlay(alignment: .topTrailing) {
                            // 本关全部图案完成时，芯片右上角佩戴小金冠
                            if unlocked && isLevelFullyCompleted(lvl) {
                                Image("sprite_crown")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 15)
                                    .offset(x: 8, y: -7)
                                    .shadow(color: Color.black.opacity(0.4), radius: 2)
                            }
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLevelIndex)
                    }
                    .disabled(!unlocked)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - 主区域（左大图 + 右信息）

    private func mainArea(proxy: GeometryProxy) -> some View {
        let currentLevel = config.levels[selectedLevelIndex]
        let allItems = PuzzleImageRepository.shared.allItems()
        let levelItems = allItems.filter { currentLevel.imageIds.contains($0.id) }
        let displayItems = levelItems.isEmpty ? Array(allItems.prefix(2)) : levelItems
        let safeIndex = min(selectedImageIndex, max(0, displayItems.count - 1))
        let item = displayItems[safeIndex]
        let record = ProgressManager.shared.getRecord(imageId: item.id, levelId: currentLevel.id)
        let isDone = record?.isCompleted ?? false
        // 有存档判定走缓存的"图_级"复合键，避免随姿态视差的高频重渲染反复解码快照
        let hasResume = resumeImageId == "\(item.id)_\(currentLevel.id)"
        // 收紧顶栏/芯片/缩略图占位，保证 iPhone 17（402pt 高）下大按钮完整可见
        let previewH = min(max(proxy.size.height - 232, 120), 240)
        // 小横屏（高度 < 390pt，如 SE）自动切换紧凑排版，防止内容溢出裁切
        let compact = proxy.size.height < 390

        return HStack(spacing: compact ? 18 : 30) {
            Spacer(minLength: 0)

            // 左：高清大图预览（点击可全屏查看）
            ZStack {
                if let uiImg = PuzzleImageRepository.shared.loadImage(for: item) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle().fill(MaillardTheme.surface)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingFullPreview = true
            }
            .frame(width: previewH * 16 / 9, height: previewH)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(MaillardTheme.gold.opacity(0.4), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.45), radius: 14, y: 6)
            .shadow(color: MaillardTheme.gold.opacity(0.35), radius: 16)

            // 右：图案信息与大号开始按钮
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Text(item.title)
                        .font(.system(size: compact ? 20 : 24, weight: .bold, design: .serif))
                        .foregroundColor(MaillardTheme.cream)
                    Text(item.theme)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(MaillardTheme.gold)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(MaillardTheme.gold.opacity(0.14))
                        .cornerRadius(7)
                    if isDone {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                            Text("已完成")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(MaillardTheme.deep)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(MaillardTheme.goldGradient)
                        .cornerRadius(7)
                    } else if hasResume {
                        Text("有存档 · 可续玩")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(MaillardTheme.cream)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(MaillardTheme.caramel)
                            .cornerRadius(7)
                    }
                }

                Text(item.description)
                    .font(.system(size: 13))
                    .foregroundColor(MaillardTheme.muted)
                    .lineLimit(compact ? 1 : 2)
                    .lineSpacing(3)
                    .frame(maxWidth: 460, alignment: .leading)

                HStack(spacing: 12) {
                    if let best = record?.bestTimeInSeconds, best > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill")
                            Text("最佳 \(formatDisplayTime(best))")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundColor(MaillardTheme.gold)
                    }
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 11))
                            .foregroundColor(MaillardTheme.muted.opacity(0.85))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MaillardTheme.warmGlass)
                            .cornerRadius(5)
                    }
                }

                Spacer(minLength: 4)

                // 大号开始按钮（经典拼图游戏布局，永远完整可见可点）
                Button {
                    selectedImageForPlay = (item, currentLevel)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "play.fill")
                            .font(.system(size: compact ? 17 : 19, weight: .bold))
                        Text(hasResume ? "继续拼图" : "开始拼图")
                            .font(.system(size: compact ? 18 : 21, weight: .bold, design: .serif))
                    }
                    .foregroundColor(hasResume ? MaillardTheme.cream : MaillardTheme.deep)
                    .frame(width: compact ? 224 : 250, height: compact ? 74 : 84)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(hasResume ? MaillardTheme.caramelGradient : MaillardTheme.goldGradient)
                            Image(hasResume ? "sprite_btn_brown" : "sprite_btn_gold")
                                .resizable()
                                .scaledToFit()
                                .shadow(color: Color.black.opacity(0.45), radius: 12, y: 6)
                        }
                    )
                }
                .padding(.bottom, 2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .id("\(item.id)-\(currentLevel.id)-\(refreshTrigger)")
    }

    // MARK: - 底部缩略图切换条

    private var thumbnailStrip: some View {
        let currentLevel = config.levels[selectedLevelIndex]
        let allItems = PuzzleImageRepository.shared.allItems()
        let levelItems = allItems.filter { currentLevel.imageIds.contains($0.id) }
        let displayItems = levelItems.isEmpty ? Array(allItems.prefix(2)) : levelItems

        return HStack(spacing: 16) {
            ForEach(displayItems.indices, id: \.self) { idx in
                let item = displayItems[idx]
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        selectedImageIndex = idx
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        if let uiImg = PuzzleImageRepository.shared.loadImage(for: item) {
                            Image(uiImage: uiImg)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 124, height: 66)
                                .clipShape(RoundedRectangle(cornerRadius: 9))
                        } else {
                            RoundedRectangle(cornerRadius: 9)
                                .fill(MaillardTheme.surface)
                                .frame(width: 124, height: 66)
                        }
                        if ProgressManager.shared.getRecord(imageId: item.id, levelId: currentLevel.id)?.isCompleted == true {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 13))
                                .foregroundColor(MaillardTheme.gold)
                                .shadow(color: Color.black.opacity(0.6), radius: 2)
                                .padding(4)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 9)
                            .stroke(
                                selectedImageIndex == idx ? MaillardTheme.gold : Color.white.opacity(0.15),
                                lineWidth: selectedImageIndex == idx ? 2.5 : 1
                            )
                    )
                    .scaleEffect(selectedImageIndex == idx ? 1.05 : 1.0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.7), value: selectedImageIndex)
                }
                .buttonStyle(MaillardTheme.pressStyle)
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
    }

    /// 当前选中的图案（供全屏预览使用）
    private var selectedDisplayItem: PuzzleImageItem? {
        let currentLevel = config.levels[selectedLevelIndex]
        let allItems = PuzzleImageRepository.shared.allItems()
        let levelItems = allItems.filter { currentLevel.imageIds.contains($0.id) }
        let displayItems = levelItems.isEmpty ? Array(allItems.prefix(2)) : levelItems
        let safeIndex = min(selectedImageIndex, max(0, displayItems.count - 1))
        return displayItems[safeIndex]
    }

    /// 刷新"有对局存档"的复合键缓存
    private func refreshResumeState() {
        resumeImageId = SessionSaveManager.shared.load().map { "\($0.imageId)_\($0.levelId)" }
    }

    /// 判断某等级下的全部图案是否均已通关（用于小金冠标识）
    private func isLevelFullyCompleted(_ level: PuzzleLevel) -> Bool {
        let items = PuzzleImageRepository.shared.allItems().filter { level.imageIds.contains($0.id) }
        guard !items.isEmpty else { return false }
        return items.allSatisfy { item in
            ProgressManager.shared.getRecord(imageId: item.id, levelId: level.id)?.isCompleted == true
        }
    }

    private func formatDisplayTime(_ seconds: Double) -> String {
        let sec = Int(seconds)
        if sec < 60 {
            return "\(sec)秒"
        } else {
            return "\(sec / 60)分\(sec % 60)秒"
        }
    }
}

private struct PlayParams: Identifiable {
    let id = UUID()
    let item: PuzzleImageItem
    let level: PuzzleLevel
}
