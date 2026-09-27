import SwiftUI

/// 游戏主菜单视图（横屏沉浸式美拉德暖棕高级感 UI）
public struct MainMenuView: View {
    @ObservedObject var settings = GameSettings.shared
    @State private var showingLevelSelect = false
    @State private var showingSettings = false
    @State private var refreshTrigger = false
    @State private var isBackdropBreathing = false
    @State private var isLogoFloating = false

    public init() {}

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack {
                    // 美拉德主背景（GPT 生成的咖啡棕织物光晕纹理，缓慢呼吸式微缩放）
                    Image("maillard_bg_main")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(isBackdropBreathing ? 1.05 : 1.0)
                        .ignoresSafeArea()
                        .overlay(
                            LinearGradient(
                                colors: [Color.black.opacity(0.10), Color.clear, Color.black.opacity(0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .ignoresSafeArea()
                        )
                        .onAppear {
                            withAnimation(.easeInOut(duration: 7.0).repeatForever(autoreverses: true)) {
                                isBackdropBreathing = true
                            }
                        }

                    HStack(spacing: 40) {
                        // 左侧：品牌 Logo 与艺术标识
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                Image("sprite_puzzle_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 52)
                                    .shadow(color: Color.black.opacity(0.45), radius: 8, y: 4)
                                    .offset(y: isLogoFloating ? -4 : 3)
                                    .onAppear {
                                        withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                                            isLogoFloating = true
                                        }
                                    }

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

                        // 右侧：主操作按钮组
                        VStack(spacing: 18) {
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
            }) {
                SettingsView()
            }
            .onAppear {
                refreshTrigger.toggle()
            }
        }
    }
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
