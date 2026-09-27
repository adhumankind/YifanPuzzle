import SwiftUI

/// 关卡选择视图（5 等级先缓后陡梯度切换，横向翻页式卡片，美拉德暖棕主题）
public struct LevelSelectView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedLevelIndex: Int = 0
    @State private var selectedImageForPlay: (PuzzleImageItem, PuzzleLevel)? = nil
    @State private var refreshTrigger = false

    private let config = PuzzleConfig.default

    public init() {}

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                // 美拉德通用底纹（深可可棕织物纹理）
                Image("maillard_bg_plain")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.16).ignoresSafeArea())

                VStack(spacing: 12) {
                    // 顶部导航栏
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
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(MaillardTheme.cream)
                            .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1)

                        Spacer()

                        // 当前解锁总星数
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
                    .padding(.top, max(12, proxy.safeAreaInsets.top + 6))

                    // 等级选择分段器 (35, 70, 160, 350, 700 块)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(config.levels.indices, id: \.self) { idx in
                                let lvl = config.levels[idx]
                                let unlocked = ProgressManager.shared.isLevelUnlocked(lvl)

                                    Button {
                                        if unlocked {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                selectedLevelIndex = idx
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
                                        Text("第\(lvl.id)级: \(lvl.pieceCount)块")
                                            .font(.system(size: 14, weight: .bold, design: .serif))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
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
                                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedLevelIndex)
                                }
                                .disabled(!unlocked)
                            }
                        }
                        .padding(.leading, max(24, proxy.safeAreaInsets.leading + 12))
                        .padding(.trailing, max(24, proxy.safeAreaInsets.trailing + 12))
                    }

                    // 当前选定等级下的图案展示列表
                    let currentLevel = config.levels[selectedLevelIndex]
                    let allItems = PuzzleImageRepository.shared.allItems()
                    let levelItems = allItems.filter { currentLevel.imageIds.contains($0.id) }
                    let displayItems = levelItems.isEmpty ? Array(allItems.prefix(2)) : levelItems

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(displayItems) { item in
                                LevelImageCard(item: item, level: currentLevel) {
                                    selectedImageForPlay = (item, currentLevel)
                                }
                                .id("\(item.id)-\(currentLevel.id)-\(refreshTrigger)")
                            }
                        }
                        .padding(.leading, max(28, proxy.safeAreaInsets.leading + 16))
                        .padding(.trailing, max(28, proxy.safeAreaInsets.trailing + 16))
                        .padding(.vertical, 10)
                    }

                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .fullScreenCover(item: Binding(
            get: { selectedImageForPlay.map { PlayParams(item: $0.0, level: $0.1) } },
            set: { _ in
                selectedImageForPlay = nil
                refreshTrigger.toggle()
            }
        )) { params in
            GamePlayView(imageItem: params.item, level: params.level)
        }
    }
}

private struct PlayParams: Identifiable {
    let id = UUID()
    let item: PuzzleImageItem
    let level: PuzzleLevel
}

private struct LevelImageCard: View {
    let item: PuzzleImageItem
    let level: PuzzleLevel
    let onPlay: () -> Void

    private func formatDisplayTime(_ seconds: Double) -> String {
        let sec = Int(seconds)
        if sec < 60 {
            return "\(sec)秒"
        } else {
            return "\(sec / 60)分\(sec % 60)秒"
        }
    }

    var body: some View {
        let record = ProgressManager.shared.getRecord(imageId: item.id, levelId: level.id)
        let isDone = record?.isCompleted ?? false
        let hasResume = SessionSaveManager.shared.load().map { $0.imageId == item.id && $0.levelId == level.id } ?? false

        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                // 缩略图
                if let uiImg = PuzzleImageRepository.shared.loadImage(for: item) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 280, height: 158)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(MaillardTheme.gold.opacity(0.35), lineWidth: 1)
                        )
                } else {
                    Rectangle()
                        .fill(MaillardTheme.surface)
                        .frame(width: 280, height: 158)
                        .cornerRadius(12)
                }

                if isDone {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("已完成")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MaillardTheme.goldGradient)
                    .foregroundColor(MaillardTheme.deep)
                    .cornerRadius(8)
                    .padding(8)
                } else if hasResume {
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                        Text("有存档")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MaillardTheme.caramel)
                    .foregroundColor(MaillardTheme.deep)
                    .cornerRadius(8)
                    .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(MaillardTheme.cream)
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text(item.theme)
                            .font(.caption.bold())
                    }
                    .foregroundColor(MaillardTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MaillardTheme.gold.opacity(0.14))
                    .cornerRadius(6)
                }

                Text(item.description)
                    .font(.system(size: 12))
                    .foregroundColor(MaillardTheme.muted)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .topLeading)

                // 标签展示（大面积天空、宠物等线索提示）
                HStack(spacing: 6) {
                    ForEach(item.tags.prefix(3), id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.system(size: 10))
                            .foregroundColor(MaillardTheme.muted.opacity(0.85))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(MaillardTheme.warmGlass)
                            .cornerRadius(4)
                    }
                }

                HStack {
                    if let best = record?.bestTimeInSeconds, best > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill")
                                .font(.system(size: 10))
                            Text("最佳: \(formatDisplayTime(best))")
                                .font(.caption2.bold())
                        }
                        .foregroundColor(MaillardTheme.gold)
                    }
                    Spacer()
                    Button(hasResume ? "继续拼图" : "立即拼图", action: onPlay)
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundColor(hasResume ? MaillardTheme.cream : MaillardTheme.deep)
                        .frame(width: 106, height: 37)
                        .background(
                            Image(hasResume ? "sprite_btn_brown" : "sprite_btn_gold")
                                .resizable()
                                .scaledToFit()
                        )
                }
                .padding(.top, 4)
            }
            .frame(width: 280)
        }
        .padding(14)
        .background(
            Image("maillard_card")
                .resizable()
                .scaledToFill()
                .clipped()
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(MaillardTheme.warmStroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.35), radius: 12, y: 5)
    }
}
