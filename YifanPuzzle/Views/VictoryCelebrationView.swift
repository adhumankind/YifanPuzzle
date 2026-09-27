import SwiftUI

/// 胜利庆祝与结算视图（美拉德香槟金成就主题）
public struct VictoryCelebrationView: View {
    public let imageItem: PuzzleImageItem
    public let level: PuzzleLevel
    public let elapsedTime: TimeInterval
    public let onNext: (() -> Void)?
    public let onReplay: () -> Void
    public let onBack: () -> Void

    @State private var appearScale: CGFloat = 0.8
    @State private var appearOpacity: Double = 0.0

    public init(
        imageItem: PuzzleImageItem,
        level: PuzzleLevel,
        elapsedTime: TimeInterval,
        onNext: (() -> Void)? = nil,
        onReplay: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.imageItem = imageItem
        self.level = level
        self.elapsedTime = elapsedTime
        self.onNext = onNext
        self.onReplay = onReplay
        self.onBack = onBack
    }

    public var body: some View {
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
                            Image("sprite_btn_brown")
                                .resizable()
                                .scaledToFit()
                        )
                    }

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
                                Image("sprite_btn_gold")
                                    .resizable()
                                    .scaledToFit()
                                    .shadow(color: Color.black.opacity(0.35), radius: 8, y: 4)
                            )
                        }
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
                            Image(onNext == nil ? "sprite_btn_gold" : "sprite_btn_brown")
                                .resizable()
                                .scaledToFit()
                        )
                    }
                }
                .padding(.top, 10)
            }
            .padding(32)
            .background(
                Image("maillard_card")
                    .resizable()
                    .scaledToFill()
                    .clipped()
            )
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(MaillardTheme.gold.opacity(0.35), lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.55), radius: 30)
            .scaleEffect(appearScale)
            .opacity(appearOpacity)
            .onAppear {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                    appearScale = 1.0
                    appearOpacity = 1.0
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
