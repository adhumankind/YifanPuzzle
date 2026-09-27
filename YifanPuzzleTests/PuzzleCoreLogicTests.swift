import XCTest
@testable import YifanPuzzle

final class PuzzleCoreLogicTests: XCTestCase {

    func testPuzzleLevelsValidation() {
        let config = PuzzleConfig.default
        XCTAssertEqual(config.levels.count, 5, "必须包含 5 个等级")

        let expectedCounts = [35, 70, 160, 350, 700]
        for (i, lvl) in config.levels.enumerated() {
            XCTAssertEqual(lvl.pieceCount, expectedCounts[i], "等级 \(lvl.id) 碎片数必须符合要求")
            XCTAssertTrue(lvl.isValidGrid, "网格行列积必须严格等于碎片总数")
            XCTAssertFalse(lvl.imageIds.isEmpty, "关卡必须关联图片素材")
        }
    }

    func testPuzzleMeshGeneratorDeterminism() {
        // 验证相同 seed 生成的互锁结构 100% 确定且完全一致
        let pieces1 = PuzzleMeshGenerator.generateGrid(columns: 7, rows: 5, seed: 99999)
        let pieces2 = PuzzleMeshGenerator.generateGrid(columns: 7, rows: 5, seed: 99999)

        XCTAssertEqual(pieces1.count, 35)
        XCTAssertEqual(pieces2.count, 35)

        for i in 0 ..< pieces1.count {
            XCTAssertEqual(pieces1[i].edges, pieces2[i].edges, "同种子生成的切口必须绝对相同")
        }

        // 验证四周边框全部为 flat
        for p in pieces1 {
            if p.row == 0 {
                XCTAssertEqual(p.edges.top, .flat, "第一行顶边必须是平的")
            }
            if p.row == 4 {
                XCTAssertEqual(p.edges.bottom, .flat, "最后一行底边必须是平的")
            }
            if p.col == 0 {
                XCTAssertEqual(p.edges.left, .flat, "第一列左边必须是平的")
            }
            if p.col == 6 {
                XCTAssertEqual(p.edges.right, .flat, "最后一列右边必须是平的")
            }
        }
    }

    func testSnapEngineLogic() {
        let pieceSize = CGSize(width: 100, height: 100)
        let target = CGPoint(x: 200, y: 200)

        // 距离近、0旋转 -> 必须成功吸附
        let closePos = CGPoint(x: 210, y: 195)
        let snapSuccess = SnapEngine.checkSnap(
            currentPos: closePos,
            targetPos: target,
            pieceSize: pieceSize,
            currentRotation: 0.05,
            allowFreeRotation: true
        )
        XCTAssertTrue(snapSuccess, "微小偏差应成功磁吸")

        // 距离近、但角度偏了 45 度、且开启了自由旋转 -> 必须拒绝吸附
        let angleOffSnap = SnapEngine.checkSnap(
            currentPos: closePos,
            targetPos: target,
            pieceSize: pieceSize,
            currentRotation: .pi / 4,
            allowFreeRotation: true
        )
        XCTAssertFalse(angleOffSnap, "自由旋转模式下角度不正不能吸附")

        // 距离太远 -> 拒绝吸附
        let farPos = CGPoint(x: 400, y: 400)
        let farSnap = SnapEngine.checkSnap(
            currentPos: farPos,
            targetPos: target,
            pieceSize: pieceSize,
            currentRotation: 0,
            allowFreeRotation: false
        )
        XCTAssertFalse(farSnap, "距离超出阈值不可吸附")
    }

    func testProgressManagerWorkflow() {
        let pm = ProgressManager.shared
        pm.resetAllProgress()
        XCTAssertEqual(pm.completedCount(), 0)

        pm.markCompleted(imageId: "puzzle_01", levelId: 1, elapsedSeconds: 42)
        XCTAssertEqual(pm.completedCount(), 1)

        let record = pm.getRecord(imageId: "puzzle_01", levelId: 1)
        XCTAssertNotNil(record)
        XCTAssertTrue(record?.isCompleted ?? false)
        XCTAssertEqual(record?.bestTimeInSeconds, 42)

        // 再玩一次用时更短，更新最佳纪录
        pm.markCompleted(imageId: "puzzle_01", levelId: 1, elapsedSeconds: 35)
        let recordUpdated = pm.getRecord(imageId: "puzzle_01", levelId: 1)
        XCTAssertEqual(recordUpdated?.bestTimeInSeconds, 35)

        pm.resetAllProgress()
        XCTAssertEqual(pm.completedCount(), 0)
    }

    func testStableSeedConsistency() {
        // 回归保护：切割种子必须跨调用/跨启动稳定（String.hashValue 是随机化的，曾被误用）
        let a1 = PuzzleMeshGenerator.stableSeed(for: "puzzle_01")
        let a2 = PuzzleMeshGenerator.stableSeed(for: "puzzle_01")
        XCTAssertEqual(a1, a2, "同一图片 ID 的种子必须稳定")

        let b = PuzzleMeshGenerator.stableSeed(for: "puzzle_02")
        XCTAssertNotEqual(a1, b, "不同图片 ID 的种子应当不同")

        // 种子一致 ⇒ 切割互锁结构完全一致
        let m1 = PuzzleMeshGenerator.generateGrid(columns: 7, rows: 5, seed: a1)
        let m2 = PuzzleMeshGenerator.generateGrid(columns: 7, rows: 5, seed: PuzzleMeshGenerator.stableSeed(for: "puzzle_01"))
        XCTAssertEqual(m1.count, m2.count)
        for i in 0 ..< m1.count {
            XCTAssertEqual(m1[i].edges, m2[i].edges)
        }
    }

    func testPerformance700PieceGridGeneration() {
        // 性能基线：700 块（35×20）网格生成应保持在毫秒级
        measure {
            _ = PuzzleMeshGenerator.generateGrid(columns: 35, rows: 20, seed: 424242)
        }
    }
}
