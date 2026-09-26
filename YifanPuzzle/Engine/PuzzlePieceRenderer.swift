import Foundation
import CoreGraphics
import UIKit
import SpriteKit

/// 拼图碎片 3D 质感纹理切片渲染器
public final class PuzzlePieceRenderer {

    /// 包含正面带厚度高光纹理、底部暗影挤压层纹理与独立投影纹理
    public struct RenderedPieceTexture {
        public let surfaceTexture: SKTexture
        public let bevelThicknessTexture: SKTexture
        public let shadowTexture: SKTexture
        public let contentBounds: CGRect
    }

    /// 高性能异步批量生成整幅拼图的所有碎片纹理
    public static func renderAllPieces(
        sourceImage: UIImage,
        pieces: [PuzzlePieceData],
        boardPixelSize: CGSize,
        completion: @escaping ([Int: RenderedPieceTexture]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var result: [Int: RenderedPieceTexture] = [:]
            let scale = UIScreen.main.scale

            for piece in pieces {
                let rendered = renderSinglePiece(sourceImage: sourceImage, piece: piece, boardPixelSize: boardPixelSize, scale: scale)
                result[piece.id] = rendered
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    /// 渲染单块碎片纹理
    public static func renderSinglePiece(
        sourceImage: UIImage,
        piece: PuzzlePieceData,
        boardPixelSize: CGSize,
        scale: CGFloat = 2.0
    ) -> RenderedPieceTexture {
        let baseW = piece.normalizedSize.width * boardPixelSize.width
        let baseH = piece.normalizedSize.height * boardPixelSize.height
        let baseSize = CGSize(width: baseW, height: baseH)

        // 留出卡榫溢出边距（按宽高的 35% 扩充画布，防止凸起被截断）
        let marginX = baseW * 0.35
        let marginY = baseH * 0.35
        let canvasSize = CGSize(width: baseW + marginX * 2, height: baseH + marginY * 2)

        // 1. 获取中心对齐的局部贝塞尔路径
        let path = PuzzlePiecePathBuilder.buildPath(for: piece.edges, size: baseSize)
        // 将原点从中心平移到画布中心
        path.apply(CGAffineTransform(translationX: canvasSize.width / 2.0, y: canvasSize.height / 2.0))

        // 2. 渲染正面表层纹理（原图贴图 + 顶部白色微高光斜角 + 边缘微弱暗角描边，产生 3D 浮雕压模感）
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false

        let surfaceRenderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        let surfaceImage = surfaceRenderer.image { ctx in
            let cg = ctx.cgContext

            cg.saveGState()
            cg.addPath(path.cgPath)
            cg.clip()

            // 计算原图对应区域并绘制
            let targetCenterX = piece.targetGridNormalized.x * boardPixelSize.width
            let targetCenterY = piece.targetGridNormalized.y * boardPixelSize.height
            let drawOriginX = (canvasSize.width / 2.0) - targetCenterX
            let drawOriginY = (canvasSize.height / 2.0) - targetCenterY
            let fullImageRect = CGRect(origin: CGPoint(x: drawOriginX, y: drawOriginY), size: boardPixelSize)

            sourceImage.draw(in: fullImageRect)

            // 绘制顶部向内的 3D 内阴影/高光微质感
            cg.setBlendMode(.overlay)
            UIColor(white: 1.0, alpha: 0.18).setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height))

            cg.restoreGState()

            // 绘制精细的边缘 3D 高光与边缘线条
            cg.saveGState()
            cg.setLineWidth(1.5)
            UIColor(white: 1.0, alpha: 0.35).setStroke()
            cg.addPath(path.cgPath)
            cg.strokePath()

            cg.setLineWidth(0.8)
            UIColor(white: 0.0, alpha: 0.28).setStroke()
            cg.addPath(path.cgPath)
            cg.strokePath()
            cg.restoreGState()
        }

        // 3. 渲染 3D 挤压厚度层纹理（下方微位移的实体深色底托，表现拼图木板/硬纸板的侧截面厚度感）
        let bevelThickness: CGFloat = 3.5
        let bevelRenderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize.width, height: canvasSize.height + bevelThickness), format: format)
        let bevelImage = bevelRenderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            // 沿 Y 轴向下逐层渲染挤压暗边
            for step in stride(from: bevelThickness, through: 0, by: -0.5) {
                let shiftedPath = UIBezierPath(cgPath: path.cgPath)
                shiftedPath.apply(CGAffineTransform(translationX: 0, y: step))
                // 深咖色/深炭色卡纸截面质感
                let shade = 0.12 + (step / bevelThickness) * 0.1
                UIColor(red: shade * 1.2, green: shade * 1.1, blue: shade, alpha: 0.85).setFill()
                shiftedPath.fill()
            }
            cg.restoreGState()
        }

        // 4. 渲染柔和投影纹理（用于拿起、悬浮及未拼好时的真实桌面阴影）
        let shadowRenderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize.width + 12, height: canvasSize.height + 14), format: format)
        let shadowImage = shadowRenderer.image { ctx in
            let cg = ctx.cgContext
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 2.0, height: 4.5), blur: 6.0, color: UIColor.black.withAlphaComponent(0.42).cgColor)
            let shadowShifted = UIBezierPath(cgPath: path.cgPath)
            shadowShifted.apply(CGAffineTransform(translationX: 6.0, y: 5.0))
            UIColor.black.setFill()
            shadowShifted.fill()
            cg.restoreGState()
        }

        return RenderedPieceTexture(
            surfaceTexture: SKTexture(image: surfaceImage),
            bevelThicknessTexture: SKTexture(image: bevelImage),
            shadowTexture: SKTexture(image: shadowImage),
            contentBounds: CGRect(origin: .zero, size: canvasSize)
        )
    }
}
