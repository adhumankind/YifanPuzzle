import SwiftUI

/// 胜利庆祝与结算视图（美拉德香槟金成就主题）
public struct VictoryCelebrationView: View {
    public let imageItem: PuzzleImageItem
    public let level: PuzzleLevel
    public let elapsedTime: TimeInterval
    public let newAchievements: [ProgressManager.Achievement]
    public let usedAssistProps: Bool
    public let onNext: (() -> Void)?
    public let onReplay: () -> Void
    public let onBack: () -> Void

    @State private var appearScale: CGFloat = 0.8
    @State private var appearOpacity: Double = 0.0

    public init(
        imageItem: PuzzleImageItem,
        level: PuzzleLevel,
        elapsedTime: TimeInterval,
        newAchievements: [ProgressManager.Achievement] = [],
        usedAssistProps: Bool = false,
        onNext: (() -> Void)? = nil,
        onReplay: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.imageItem = imageItem
        self.level = level
        self.elapsedTime = elapsedTime
        self.newAchievements = newAchievements
        self.usedAssistProps = usedAssistProps
        self.onNext = onNext
        self.onReplay = onReplay
        self.onBack = onBack
    }

    public var body: some View {
        GeometryReader { geo in
            // 小屏（如 SE 横屏 375pt 高）下整体等比缩小，保证按钮永远完整可见
            let fitScale = min(1.0, geo.size.height / 500.0)
            ZStack {
                Color.black.opacity(0.72).ignoresSafeArea()

            VStack(spacing: 16) {
                // 奖杯与成就勋章
                Image("sprite_trophy")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 88)
                    .shadow(color: MaillardTheme.gold.opacity(0.45), radius: 16)

                Text("挑战成功！完美拼合")
                    .font(.system(size: 26, weight: .heavy, design: .serif))
                    .foregroundColor(MaillardTheme.cream)

                Text("你已完成《\(imageItem.title)》· 第\(level.id)级 (\(level.pieceCount)块)")
                    .font(.system(size: 14))
                    .foregroundColor(MaillardTheme.muted)

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("本次用时")
                            .font(.caption)
                            .foregroundColor(MaillardTheme.muted)
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(MaillardTheme.gold)
                    }

                    if let best = ProgressManager.shared.getRecord(imageId: imageItem.id, levelId: level.id)?.bestTimeInSeconds {
                        VStack(spacing: 4) {
                            Text("最佳纪录")
                                .font(.caption)
                                .foregroundColor(MaillardTheme.muted)
                            Text(formatTime(best))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(MaillardTheme.caramel)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(MaillardTheme.warmGlass)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(MaillardTheme.warmStroke, lineWidth: 0.8)
                )

                // 成就墙（本次新解锁的成就带"新"角标高亮）
                let achievementEntries = ProgressManager.shared.allAchievements()
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(achievementEntries, id: \.achievement.rawValue) { entry in
                        let isNew = newAchievements.contains(entry.achievement)
                        HStack(spacing: 6) {
                            Image(entry.achievement.spriteName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 24)
                                .opacity(entry.isUnlocked ? 1 : 0.28)
                            Text(entry.achievement.title)
                                .font(.system(size: 12, weight: entry.isUnlocked ? .bold : .regular))
                                .foregroundColor(entry.isUnlocked ? MaillardTheme.cream : MaillardTheme.muted.opacity(0.55))
                            if isNew {
                                Text("新")
                                    .font(.system(size: 9, weight: .black))
                                    .foregroundColor(MaillardTheme.deep)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(MaillardTheme.goldGradient)
                                    .cornerRadius(4)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity)
                        .background(entry.isUnlocked ? MaillardTheme.warmGlass : Color.black.opacity(0.14))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 2)

                // 道具使用回顾（中心思想：不设阻碍，顺便引导冲击"独立完成"徽章）
                HStack(spacing: 6) {
                    Image(systemName: usedAssistProps ? "wand.and.stars" : "checkmark.seal.fill")
                        .font(.system(size: 12))
                    Text(usedAssistProps ? "本局使用了道具 · 全程不用可赢取「独立完成」徽章" : "全程未用道具 · 干净利落！")
                        .font(.system(size: 11, weight: usedAssistProps ? .regular : .bold))
                }
                .foregroundColor(usedAssistProps ? MaillardTheme.muted : MaillardTheme.gold)

                HStack(spacing: 16) {
                    Button {
                        onReplay()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("再拼一次")
                        }
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(MaillardTheme.cream)
                        .frame(width: 150, height: 53)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(MaillardTheme.caramelGradient)
                                Image("sprite_btn_brown")
                                    .resizable()
                                    .scaledToFit()
                            }
                        )
                    }
                    .buttonStyle(MaillardTheme.pressStyle)

                    if let nextAction = onNext {
                        Button {
                            nextAction()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "forward.fill")
                                Text("下一幅图")
                            }
                            .font(.system(size: 13, weight: .bold, design: .serif))
                            .foregroundColor(MaillardTheme.deep)
                            .frame(width: 160, height: 56)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16).fill(MaillardTheme.goldGradient)
                                    Image("sprite_btn_gold")
                                        .resizable()
                                        .scaledToFit()
                                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                                }
                            )
                        }
                        .buttonStyle(MaillardTheme.pressStyle)
                    }

                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                            Text("返回关卡")
                        }
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundColor(onNext == nil ? MaillardTheme.deep : MaillardTheme.cream)
                        .frame(width: 150, height: 53)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(onNext == nil ? MaillardTheme.goldGradient : MaillardTheme.caramelGradient)
                                Image(onNext == nil ? "sprite_btn_gold" : "sprite_btn_brown")
                                    .resizable()
                                    .scaledToFit()
                            }
                        )
                    }
                    .buttonStyle(MaillardTheme.pressStyle)
                }
                .padding(.top, 10)
            }
            .padding(32)
            .background(
                ZStack {
                    MaillardTheme.espresso
                    Image("maillard_card")
                        .resizable()
                        .scaledToFill()
                        .clipped()
                }
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MaillardTheme.gold.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30)
            .scaleEffect(appearScale * fitScale)
            .opacity(appearOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    appearScale = 1.0
                    appearOpacity = 1.0
                }
            }
            }
        }
    }

    private func formatTime(_ sec: TimeInterval) -> String {
        let m = Int(sec) / 60
        let s = Int(sec) % 60
        return String(format: "%02d分%02d秒", m, s)
    }
}
