import Foundation
import CoreGraphics
import UIKit

/// 拼图碎片贝塞尔矢量路径构建器
public final class PuzzlePiecePathBuilder {

    /// 为指定碎片构建局部的封闭 UIBezierPath
    /// 坐标系以中心点 (0, 0) 为原点，基础尺寸为 (baseWidth, baseHeight)
    /// 凸起卡榫将超出基础尺寸边界约 20%
    public static func buildPath(for edges: PieceEdges, size: CGSize) -> UIBezierPath {
        let w = size.width
        let h = size.height
        let halfW = w / 2.0
        let halfH = h / 2.0

        let path = UIBezierPath()

        // 顶点定义（逆时针或顺时针围绕矩形）：
        // 左上角: (-halfW, -halfH)
        // 右上角: (halfW, -halfH)
        // 右下角: (halfW, halfH)
        // 左下角: (-halfW, halfH)

        path.move(to: CGPoint(x: -halfW, y: -halfH))

        // 1. 顶边（左上 -> 右上）
        drawHorizontalEdge(to: path, from: CGPoint(x: -halfW, y: -halfH), to: CGPoint(x: halfW, y: -halfH), type: edges.top, outwardSign: -1.0, length: w)

        // 2. 右边（右上 -> 右下）
        drawVerticalEdge(to: path, from: CGPoint(x: halfW, y: -halfH), to: CGPoint(x: halfW, y: halfH), type: edges.right, outwardSign: 1.0, length: h)

        // 3. 底边（右下 -> 左下）
        drawHorizontalEdge(to: path, from: CGPoint(x: halfW, y: halfH), to: CGPoint(x: -halfW, y: halfH), type: edges.bottom, outwardSign: 1.0, length: w)

        // 4. 左边（左下 -> 左上）
        drawVerticalEdge(to: path, from: CGPoint(x: -halfW, y: halfH), to: CGPoint(x: -halfW, y: -halfH), type: edges.left, outwardSign: -1.0, length: h)

        path.close()
        return path
    }

    /// 绘制水平边榫卯（三次贝塞尔曲线光滑蘑菇榫）
    private static func drawHorizontalEdge(to path: UIBezierPath, from p1: CGPoint, to p2: CGPoint, type: EdgeTabType, outwardSign: CGFloat, length: CGFloat) {
        if type == .flat {
            path.addLine(to: p2)
            return
        }

        let direction: CGFloat = (p2.x > p1.x) ? 1.0 : -1.0
        let tabDirection: CGFloat = (type == .tabOut) ? outwardSign : -outwardSign

        let tabWidth = length * 0.32
        let tabHeight = length * 0.22 * tabDirection

        let startTabX = p1.x + direction * ((length - tabWidth) / 2.0)
        let midTabX = p1.x + direction * (length / 2.0)
        let endTabX = p1.x + direction * ((length + tabWidth) / 2.0)
        let baseY = p1.y

        // 前半平直段
        path.addLine(to: CGPoint(x: startTabX, y: baseY))

        // 蘑菇榫榫根向内略微收缩、榫头膨胀的三次贝塞尔光滑曲线
        let cp1 = CGPoint(x: startTabX + direction * (tabWidth * 0.1), y: baseY + tabHeight * 0.2)
        let cp2 = CGPoint(x: midTabX - direction * (tabWidth * 0.4), y: baseY + tabHeight * 1.05)
        let midTop = CGPoint(x: midTabX, y: baseY + tabHeight)

        let cp3 = CGPoint(x: midTabX + direction * (tabWidth * 0.4), y: baseY + tabHeight * 1.05)
        let cp4 = CGPoint(x: endTabX - direction * (tabWidth * 0.1), y: baseY + tabHeight * 0.2)

        path.addCurve(to: midTop, controlPoint1: cp1, controlPoint2: cp2)
        path.addCurve(to: CGPoint(x: endTabX, y: baseY), controlPoint1: cp3, controlPoint2: cp4)

        // 后半平直段
        path.addLine(to: p2)
    }

    /// 绘制垂直边榫卯
    private static func drawVerticalEdge(to path: UIBezierPath, from p1: CGPoint, to p2: CGPoint, type: EdgeTabType, outwardSign: CGFloat, length: CGFloat) {
        if type == .flat {
            path.addLine(to: p2)
            return
        }

        let direction: CGFloat = (p2.y > p1.y) ? 1.0 : -1.0
        let tabDirection: CGFloat = (type == .tabOut) ? outwardSign : -outwardSign

        let tabWidth = length * 0.32
        let tabHeight = length * 0.22 * tabDirection

        let startTabY = p1.y + direction * ((length - tabWidth) / 2.0)
        let midTabY = p1.y + direction * (length / 2.0)
        let endTabY = p1.y + direction * ((length + tabWidth) / 2.0)
        let baseX = p1.x

        // 前半平直段
        path.addLine(to: CGPoint(x: baseX, y: startTabY))

        // 蘑菇榫三次贝塞尔
        let cp1 = CGPoint(x: baseX + tabHeight * 0.2, y: startTabY + direction * (tabWidth * 0.1))
        let cp2 = CGPoint(x: baseX + tabHeight * 1.05, y: midTabY - direction * (tabWidth * 0.4))
        let midTop = CGPoint(x: baseX + tabHeight, y: midTabY)

        let cp3 = CGPoint(x: baseX + tabHeight * 1.05, y: midTabY + direction * (tabWidth * 0.4))
        let cp4 = CGPoint(x: baseX + tabHeight * 0.2, y: endTabY - direction * (tabWidth * 0.1))

        path.addCurve(to: midTop, controlPoint1: cp1, controlPoint2: cp2)
        path.addCurve(to: CGPoint(x: baseX, y: endTabY), controlPoint1: cp3, controlPoint2: cp4)

        // 后半平直段
        path.addLine(to: p2)
    }
}
