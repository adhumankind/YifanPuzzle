import SwiftUI

/// 游戏主菜单视图（横屏沉浸式卡片式 UI）
public struct MainMenuView: View {
    @ObservedObject var settings = GameSettings.shared
    @State private var showingLevelSelect = false
    @State private var showingSettings = false
    @State private var refreshTrigger = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                // 渐变天空与自然背景
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.15, blue: 0.24),
                        Color(red: 0.18, green: 0.25, blue: 0.38),
                        Color(red: 0.14, green: 0.20, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                HStack(spacing: 40) {
                    // 左侧：品牌 Logo 与艺术标识
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "puzzlepiece.extension.fill")
                                .font(.system(size: 44, weight: .bold))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan.opacity(0.6), radius: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("一凡拼图")
                                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 4, y: 2)

                                Text("Yifan Puzzle · 触手可及的匠心手感")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        Text("精选 10 款绚丽天空与林木原画，5 级进阶递增，配合 3D 浮雕厚度与智能磁吸，重拾指尖拼合的美好时光。")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                            .lineSpacing(4)
                            .frame(maxWidth: 360, alignment: .leading)

                        Spacer().frame(height: 10)

                        // 快速关卡统计徽章
                        HStack(spacing: 16) {
                            BadgeItem(title: "已收录图案", value: "\(PuzzleImageRepository.shared.allItems().count) 张")
                            BadgeItem(title: "挑战等级", value: "5 个梯度")
                            BadgeItem(title: "已通关", value: "\(ProgressManager.shared.completedCount()) 关")
                                .id(refreshTrigger)
                        }
                    }
                    .padding(.leading, 30)

                    Spacer()

                    // 右侧：主操作按钮组
                    VStack(spacing: 18) {
                        Button {
                            showingLevelSelect = true
                        } label: {
                            HStack {
                                Image(systemName: "play.fill")
                                    .font(.title2)
                                Text("开始游戏")
                                    .font(.system(size: 20, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 240, height: 60)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(18)
                            .shadow(color: .blue.opacity(0.5), radius: 12, y: 4)
                        }

                        Button {
                            showingSettings = true
                        } label: {
                            HStack {
                                Image(systemName: "gearshape.fill")
                                    .font(.title3)
                                Text("游戏设置")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(width: 240, height: 50)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                    .padding(.trailing, 40)
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
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.cyan)
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .cornerRadius(10)
    }
}
