import Foundation
import UIKit

/// 单张拼图图案的数据元信息
public struct PuzzleImageItem: Identifiable, Codable, Hashable {
    public let id: String              // 如 puzzle_01
    public let title: String           // 如 "春山樱花"
    public let theme: String           // 如 "自然四季"
    public let description: String     // 画面简介
    public let localFileName: String   // 文件名如 puzzle_01.jpg
    public let tags: [String]          // 标签：天空渐变、树木等
    public let author: String          // AI 生成标注

    public init(id: String, title: String, theme: String, description: String, localFileName: String, tags: [String] = ["天空渐变", "树木"], author: String = "AI 艺术工坊") {
        self.id = id
        self.title = title
        self.theme = theme
        self.description = description
        self.localFileName = localFileName
        self.tags = tags
        self.author = author
    }
}

/// 图库管理器：支持 Bundle 内置图扫描 + Documents 动态下载扩展（面向 500+ 张设计）
public final class PuzzleImageRepository {
    public static let shared = PuzzleImageRepository()

    private var itemsCache: [PuzzleImageItem] = []
    private let queue = DispatchQueue(label: "com.yifan.imagerepository", attributes: .concurrent)

    private init() {
        reloadItems()
    }

    /// 重新载入所有图库元数据
    public func reloadItems() {
        var list: [PuzzleImageItem] = []

        // 1. 尝试从 Bundle 中的 PuzzleImages.json 读取
        if let url = Bundle.main.url(forResource: "PuzzleImages", withExtension: "json", subdirectory: "PuzzleImages"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([PuzzleImageItem].self, from: data) {
            list.append(contentsOf: decoded)
        } else if let urlRoot = Bundle.main.url(forResource: "PuzzleImages", withExtension: "json"),
                  let data = try? Data(contentsOf: urlRoot),
                  let decoded = try? JSONDecoder().decode([PuzzleImageItem].self, from: data) {
            list.append(contentsOf: decoded)
        } else {
            // 兜底：内置 10 张图默认清单
            list = Self.defaultTenItems
        }

        // 2. 扫描 Documents/CustomPuzzleImages 目录（支持后续外部导入/下载）
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customDir = docsDir.appendingPathComponent("CustomPuzzleImages")
            if let files = try? FileManager.default.contentsOfDirectory(at: customDir, includingPropertiesForKeys: nil) {
                for file in files where ["jpg", "jpeg", "png"].contains(file.pathExtension.lowercased()) {
                    let baseName = file.deletingPathExtension().lastPathComponent
                    if !list.contains(where: { $0.id == baseName }) {
                        list.append(PuzzleImageItem(
                            id: baseName,
                            title: baseName,
                            theme: "自选图库",
                            description: "导入的拼图素材",
                            localFileName: file.lastPathComponent,
                            tags: ["用户图库"]
                        ))
                    }
                }
            }
        }

        queue.async(flags: .barrier) {
            self.itemsCache = list
        }
    }

    /// 获取全部拼图项目
    public func allItems() -> [PuzzleImageItem] {
        queue.sync { itemsCache }
    }

    /// 根据 ID 查找某张图
    public func item(withId id: String) -> PuzzleImageItem? {
        queue.sync { itemsCache.first { $0.id == id } }
    }

    /// 加载 UIImage
    public func loadImage(for item: PuzzleImageItem) -> UIImage? {
        // 先检查 Documents 动态目录
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let customFile = docsDir.appendingPathComponent("CustomPuzzleImages").appendingPathComponent(item.localFileName)
            if FileManager.default.fileExists(atPath: customFile.path),
               let image = UIImage(contentsOfFile: customFile.path) {
                return image
            }
        }

        // 再检查 Bundle 的 Resources/PuzzleImages
        let nameWithoutExt = (item.localFileName as NSString).deletingPathExtension
        let ext = (item.localFileName as NSString).pathExtension

        if let path = Bundle.main.path(forResource: nameWithoutExt, ofType: ext, inDirectory: "PuzzleImages") {
            return UIImage(contentsOfFile: path)
        }
        if let path = Bundle.main.path(forResource: nameWithoutExt, ofType: ext) {
            return UIImage(contentsOfFile: path)
        }
        if let namedImage = UIImage(named: nameWithoutExt) {
            return namedImage
        }

        // 最终返回占位图（保证不崩溃）
        return Self.generateFallbackImage(title: item.title)
    }

    /// 默认 10 张图列表元数据
    public static let defaultTenItems: [PuzzleImageItem] = [
        PuzzleImageItem(id: "puzzle_01", title: "春山樱花", theme: "四季物语", description: "暖风拂过樱花树漫山遍野，粉蓝渐变的天空与翠绿山坡相映成趣。", localFileName: "puzzle_01.png"),
        PuzzleImageItem(id: "puzzle_02", title: "夏日湖泊", theme: "四季物语", description: "静谧澄澈的高山湖泊，松林郁郁葱葱，白帆在深蓝渐变天空下驶过。", localFileName: "puzzle_02.png"),
        PuzzleImageItem(id: "puzzle_03", title: "秋叶溪谷", theme: "四季物语", description: "火红与橙黄的枫叶层林尽染，古石桥倒映在金黄渐变的溪水与暮色中。", localFileName: "puzzle_03.png"),
        PuzzleImageItem(id: "puzzle_04", title: "冬雪松林", theme: "四季物语", description: "银装素裹的宁静松林，小木屋窗前亮起暖光，紫黛色夜空星光微烁。", localFileName: "puzzle_04.png"),
        PuzzleImageItem(id: "puzzle_05", title: "落日沙滩", theme: "热带漫步", description: "椰影婆娑的大海之滨，橘粉晚霞铺满天空，海风带来温暖的气息。", localFileName: "puzzle_05.png"),
        PuzzleImageItem(id: "puzzle_06", title: "朝雾梯田", theme: "绿野仙境", description: "晨曦微露的层层梯田，薄雾缭绕在山腰，古老神树在朝阳下舒展枝桠。", localFileName: "puzzle_06.png"),
        PuzzleImageItem(id: "puzzle_07", title: "星夜露营", theme: "奇幻森林", description: "深蓝渐变穹顶挂着弯弯金月，微光萤火虫飞舞，帐篷中透出脉脉温情。", localFileName: "puzzle_07.png"),
        PuzzleImageItem(id: "puzzle_08", title: "彩虹花田", theme: "绿野仙境", description: "万紫千红的野花盛开在阳光山谷，巨大神木守护着横跨天际的七彩弧线。", localFileName: "puzzle_08.png"),
        PuzzleImageItem(id: "puzzle_09", title: "雨林飞瀑", theme: "秘境探险", description: "热带雨林中的清凉瀑布注入碧潭，大嘴鸟在古藤树冠上静静伫立。", localFileName: "puzzle_09.png"),
        PuzzleImageItem(id: "puzzle_10", title: "金色田园", theme: "大地之歌", description: "丰收的金色麦浪随风起伏，红色谷仓立在大树旁，晚霞泛着暖金光辉。", localFileName: "puzzle_10.png")
    ]

    /// 优雅的占位图生成器（测试与素材缺失时自适应）
    public static func generateFallbackImage(title: String, size: CGSize = CGSize(width: 1280, height: 720)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // 渐变天空背景
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [
                UIColor(red: 0.25, green: 0.55, blue: 0.95, alpha: 1.0).cgColor,
                UIColor(red: 0.95, green: 0.75, blue: 0.65, alpha: 1.0).cgColor
            ] as CFArray
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
                ctx.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height * 0.7), options: [])
            }

            // 绿色山坡大地
            let groundPath = UIBezierPath()
            groundPath.move(to: CGPoint(x: 0, y: size.height * 0.6))
            groundPath.addQuadCurve(to: CGPoint(x: size.width, y: size.height * 0.65), controlPoint: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
            groundPath.addLine(to: CGPoint(x: size.width, y: size.height))
            groundPath.addLine(to: CGPoint(x: 0, y: size.height))
            groundPath.close()
            UIColor(red: 0.35, green: 0.75, blue: 0.42, alpha: 1.0).setFill()
            groundPath.fill()

            // 树木绘制
            let trunkRect = CGRect(x: size.width * 0.48, y: size.height * 0.45, width: size.width * 0.04, height: size.height * 0.25)
            UIColor(red: 0.55, green: 0.35, blue: 0.2, alpha: 1.0).setFill()
            UIBezierPath(rect: trunkRect).fill()

            let foliage = UIBezierPath(ovalIn: CGRect(x: size.width * 0.4, y: size.height * 0.25, width: size.width * 0.2, height: size.height * 0.28))
            UIColor(red: 0.2, green: 0.65, blue: 0.35, alpha: 1.0).setFill()
            foliage.fill()

            // 绘制文字
            let text = "一凡拼图 · \(title)"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 44, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (text as NSString).size(withAttributes: attrs)
            let textPoint = CGPoint(x: (size.width - textSize.width) / 2, y: size.height * 0.1)
            (text as NSString).draw(at: textPoint, withAttributes: attrs)
        }
    }
}
