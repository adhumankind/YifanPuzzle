import SwiftUI

/// 游戏主菜单视图（横屏沉浸式美拉德暖棕高级感 UI）
public struct MainMenuView: View {
    @ObservedObject var settings = GameSettings.shared
    @State private var showingLevelSelect = false
    @State private var showingSettings = false
    @State private var refreshTrigger = false
    @State private var resumeTarget: ResumeTarget? = nil
    @State private var showingResumeGame = false

    public init() {}

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    // 暖棕兜底（即使背景图异常也绝不以纯黑呈现）
                    MaillardTheme.deep.ignoresSafeArea()

                    // 美拉德主背景（GPT 生成的咖啡棕织物光晕纹理）
                    Image("maillard_bg_main")
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.08), Color.clear, Color.black.opacity(0.24)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )

                    HStack(spacing: 40) {
                        // 左侧：品牌 Logo 与艺术标识
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                Image("sprite_puzzle_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 52)
                                    .shadow(color: Color.black.opacity(0.45), radius: 8, y: 4)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text("一凡爱拼图")
                                        .font(.system(size: 38, weight: .heavy, design: .serif))
                                        .foregroundColor(MaillardTheme.cream)
                                        .shadow(color: Color.black.opacity(0.45), radius: 5, y: 2)

                                    Text("YIFAN PUZZLE · 触手可及的匠心手感")
                                        .font(.system(size: 12, weight: .semibold))
                                        .tracking(1.5)
                                        .foregroundColor(MaillardTheme.muted)
                                }
                            }

                            Text("精选 10 款绚丽天空与林木原画，5 级进阶递增，配合 3D 浮雕厚度与智能磁吸，重拾指尖拼合的美好时光。")
                                .font(.system(size: 14))
                                .foregroundColor(MaillardTheme.cream.opacity(0.82))
                                .lineSpacing(4)
                                .frame(maxWidth: 360, alignment: .leading)

                            Spacer().frame(height: 10)

                            // 快速关卡统计徽章
                            HStack(spacing: 16) {
                                BadgeItem(title: "已收录图案", value: "\(PuzzleImageRepository.shared.allItems().count) 张")
                                BadgeItem(title: "挑战等级", value: "5 个梯度")
                                BadgeItem(title: "已通关", value: "\(ProgressManager.shared.completedCount()) 关")
                                    .id(refreshTrigger)
                                BadgeItem(title: "已获成就", value: "\(ProgressManager.shared.allAchievements().filter { $0.isUnlocked }.count)/\(ProgressManager.Achievement.allCases.count)")
                                    .id(refreshTrigger)
                            }
                        }
                        .padding(.leading, max(30, proxy.safeAreaInsets.leading + 16))

                        Spacer()

                        // 右侧：主操作按钮组（有对局存档时顶部出现断点直达横幅）
                        VStack(spacing: 18) {
                            if let target = resumeTarget {
                                Button {
                                    showingResumeGame = true
                                } label: {
                                    HStack(spacing: 10) {
                                        Image(systemName: "play.circle.fill")
                                            .font(.title3)
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text("继续上次拼图")
                                                .font(.system(size: 15, weight: .bold, design: .serif))
                                            Text("《\(target.item.title)》· 第\(target.level.id)级 (\(target.level.pieceCount)块)")
                                                .font(.system(size: 11))
                                                .opacity(0.8)
                                        }
                                    }
                                    .foregroundColor(MaillardTheme.cream)
                                    .frame(width: 320, height: 58)
                                    .background(MaillardTheme.warmGlass)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(MaillardTheme.gold.opacity(0.4), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(MaillardTheme.pressStyle)
                            }

                            Button {
                                showingLevelSelect = true
                            } label: {
                                HStack {
                                    Image(systemName: "play.fill")
                                        .font(.title3)
                                    Text("开始游戏")
                                        .font(.system(size: 20, weight: .bold, design: .serif))
                                }
                                .foregroundColor(MaillardTheme.deep)
                                .frame(width: 236, height: 83)
                                .background(
                                    Image("sprite_btn_gold")
                                        .resizable()
                                        .scaledToFit()
                                        .shadow(color: Color.black.opacity(0.40), radius: 10, y: 5)
                                )
                            }
                            .buttonStyle(MaillardTheme.pressStyle)

                            Button {
                                showingSettings = true
                            } label: {
                                HStack {
                                    Image(systemName: "gearshape.fill")
                                        .font(.body)
                                    Text("游戏设置")
                                        .font(.system(size: 17, weight: .semibold, design: .serif))
                                }
                                .foregroundColor(MaillardTheme.cream)
                                .frame(width: 236, height: 83)
                                .background(
                                    Image("sprite_btn_brown")
                                        .resizable()
                                        .scaledToFit()
                                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                                )
                            }
                            .buttonStyle(MaillardTheme.pressStyle)
                        }
                        .padding(.trailing, max(40, proxy.safeAreaInsets.trailing + 20))
                    }
                }
            }
            .navigationDestination(isPresented: $showingLevelSelect) {
                LevelSelectView()
            }
            .sheet(isPresented: $showingSettings, onDismiss: {
                refreshTrigger.toggle()
                loadResumeTarget()
            }) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingResumeGame) {
                if let target = resumeTarget {
                    GamePlayView(imageItem: target.item, level: target.level)
                }
            }
            .onAppear {
                refreshTrigger.toggle()
                loadResumeTarget()
            }
        }
    }
    /// 读取对局存档，解析断点直达目标（图 + 级）
    private func loadResumeTarget() {
        guard let snap = SessionSaveManager.shared.load() else {
            resumeTarget = nil
            return
        }
        let level = PuzzleConfig.default.levels.first { $0.id == snap.levelId }
        let item = PuzzleImageRepository.shared.allItems().first { $0.id == snap.imageId }
        if let level = level, let item = item {
            resumeTarget = ResumeTarget(item: item, level: level)
        } else {
            resumeTarget = nil
        }
    }
}

/// 断点直达目标（有对局存档时主菜单横幅使用）
private struct ResumeTarget {
    let item: PuzzleImageItem
    let level: PuzzleLevel
}

private struct BadgeItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundColor(MaillardTheme.gold)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(MaillardTheme.muted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(MaillardTheme.warmGlass)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
        )
    }
}
