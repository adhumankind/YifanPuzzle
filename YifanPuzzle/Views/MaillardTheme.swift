import SwiftUI

/// 美拉德暖棕高级感主题：全局统一色板、渐变与通用材质样式
public enum MaillardTheme {
    /// 深浓缩咖啡（页面最深底色）
    public static let deep = Color(red: 0.110, green: 0.071, blue: 0.047)
    /// 意式深棕（浮层/卡片深色底）
    public static let espresso = Color(red: 0.165, green: 0.106, blue: 0.067)
    /// 可可棕（次级表面）
    public static let surface = Color(red: 0.227, green: 0.153, blue: 0.098)
    /// 焦糖棕（主强调色）
    public static let caramel = Color(red: 0.776, green: 0.545, blue: 0.349)
    /// 香槟金（高亮/成就）
    public static let gold = Color(red: 0.878, green: 0.643, blue: 0.345)
    /// 奶油白（主文字）
    public static let cream = Color(red: 0.961, green: 0.914, blue: 0.851)
    /// 燕麦棕（次级文字）
    public static let muted = Color(red: 0.788, green: 0.702, blue: 0.604)

    /// 香槟金主按钮渐变
    public static let goldGradient = LinearGradient(
        colors: [
            Color(red: 0.906, green: 0.698, blue: 0.400),
            Color(red: 0.749, green: 0.506, blue: 0.278)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 焦糖次级按钮渐变
    public static let caramelGradient = LinearGradient(
        colors: [
            Color(red: 0.812, green: 0.588, blue: 0.388),
            Color(red: 0.667, green: 0.443, blue: 0.263)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// 暖棕玻璃拟态胶囊底（HUD/次要按钮）
    public static let warmGlass = Color(red: 0.941, green: 0.878, blue: 0.784, opacity: 0.14)

    /// 暖棕描边
    public static let warmStroke = Color(red: 0.878, green: 0.643, blue: 0.345, opacity: 0.28)

    /// 全局统一按压回弹样式
    public static let pressStyle = MaillardPressStyle()
}

/// 美拉德统一按压回弹反馈（按下轻微缩小变暗，松手弹性回位）
public struct MaillardPressStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// SpriteKit 场景用的 UIColor 版本色板
public extension MaillardTheme {
    enum ui {
        public static let sceneBackground = UIColor(red: 0.086, green: 0.059, blue: 0.039, alpha: 1.0)
        public static let mat = UIColor(red: 0.165, green: 0.114, blue: 0.075, alpha: 1.0)
        public static let boardFill = UIColor(red: 0.122, green: 0.082, blue: 0.055, alpha: 0.95)
        public static let boardStroke = UIColor(red: 0.961, green: 0.914, blue: 0.851, alpha: 0.10)
        public static let ghostOutline = UIColor(red: 0.878, green: 0.643, blue: 0.345, alpha: 0.45)
        public static let divider = UIColor(red: 0.961, green: 0.914, blue: 0.851, alpha: 0.15)
        public static let dividerHandle = UIColor(red: 0.776, green: 0.545, blue: 0.349, alpha: 0.95)
        public static let dividerHandleStroke = UIColor(red: 0.961, green: 0.914, blue: 0.851, alpha: 0.85)
        public static let trayBackground = UIColor(red: 0.153, green: 0.106, blue: 0.071, alpha: 0.90)
        public static let trayStroke = UIColor(red: 0.878, green: 0.643, blue: 0.345, alpha: 0.25)
        public static let slot = UIColor(red: 0.060, green: 0.041, blue: 0.027, alpha: 0.65)
        public static let slotStroke = UIColor(red: 0.878, green: 0.643, blue: 0.345, alpha: 0.15)
        public static let slotLabel = UIColor(red: 0.788, green: 0.702, blue: 0.604, alpha: 0.35)
        public static let slotPulse = UIColor(red: 1.000, green: 0.780, blue: 0.400, alpha: 0.40)
    }
}
