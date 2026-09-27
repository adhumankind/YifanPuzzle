import SwiftUI

/// 游戏功能设置面板
public struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var settings = GameSettings.shared
    @State private var showingResetAlert = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.12, green: 0.14, blue: 0.18).ignoresSafeArea()

                Form {
                    Section {
                        // 核心需求开关：卡片自由角度摆放
                        Toggle(isOn: $settings.allowFreeRotation) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("拼图碎片自由角度摆放")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                Text("开启后碎片散落带有随机旋转角度，需人工双指旋转调整方向对准后方可吸附；关闭后全部正向摆放无需旋转。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.65))
                            }
                            .padding(.vertical, 4)
                        }
                    } header: {
                        Text("核心操作模式")
                            .foregroundColor(.cyan)
                    }

                    Section {
                        Toggle("拼图咔哒吸附与拾取音效", isOn: $settings.soundEnabled)
                            .onChange(of: settings.soundEnabled) { enabled in
                                if enabled {
                                    GameFeedbackEngine.shared.triggerSnap()
                                }
                            }
                        Toggle("清脆触感震动反馈", isOn: $settings.hapticsEnabled)
                            .onChange(of: settings.hapticsEnabled) { enabled in
                                if enabled {
                                    GameFeedbackEngine.shared.triggerSnap()
                                }
                            }
                        Toggle("原图半透明虚影辅助参考", isOn: $settings.showGhostOutline)
                        Toggle("陀螺仪 3D 景深视差效果", isOn: $settings.parallax3DEnabled)
                    } header: {
                        Text("视听与触觉反馈")
                            .foregroundColor(.cyan)
                    }

                    Section {
                        Button(role: .destructive) {
                            showingResetAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("重置所有关卡与通关纪录")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                            }
                        }
                    } header: {
                        Text("存档数据")
                            .foregroundColor(.gray)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("游戏设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
            .alert("确认重置？", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) {}
                Button("确定重置", role: .destructive) {
                    ProgressManager.shared.resetAllProgress()
                    SessionSaveManager.shared.clear()
                    GameSettings.shared.resetToDefaults()
                }
            } message: {
                Text("此操作将清空所有已通关星级、历史最佳用时以及中途保存的拼图进度，并将游戏设置恢复为默认值，无法撤回。")
            }
        }
    }
}
