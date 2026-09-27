import SwiftUI

/// 胜利庆祝与结算视图
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
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack(spacing: 16) {
                // 奖杯与成就勋章
                Image(systemName: "trophy.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.yellow)
                    .shadow(color: .yellow.opacity(0.6), radius: 12)

                Text("挑战成功！完美拼合")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("你已完成《\(imageItem.title)》· 第\(level.id)级 (\(level.pieceCount)块)")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.8))

                HStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Text("本次用时")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Text(formatTime(elapsedTime))
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }

                    if let best = ProgressManager.shared.getRecord(imageId: imageItem.id, levelId: level.id)?.bestTimeInSeconds {
                        VStack(spacing: 4) {
                            Text("最佳纪录")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            Text(formatTime(best))
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(14)

                HStack(spacing: 16) {
                    Button {
                        onReplay()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("再拼一次")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.18))
                        .cornerRadius(12)
                    }

                    if let nextAction = onNext {
                        Button {
                            nextAction()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "forward.fill")
                                Text("下一幅图")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.yellow)
                            .cornerRadius(12)
                        }
                    }

                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "square.grid.2x2")
                            Text("返回关卡")
                        }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(onNext == nil ? .black : .white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(onNext == nil ? Color.cyan : Color.white.opacity(0.18))
                        .cornerRadius(12)
                    }
                }
                .padding(.top, 10)
            }
            .padding(32)
            .background(Color(red: 0.14, green: 0.17, blue: 0.23))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
            )
            .shadow(radius: 30)
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
