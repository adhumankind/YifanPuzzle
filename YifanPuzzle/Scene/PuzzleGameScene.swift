import SpriteKit
import UIKit

/// 拼图游戏核心主场景（纯横屏驱动，极致手感与物理反馈）
public final class PuzzleGameScene: SKScene, UIGestureRecognizerDelegate {

    // 核心数据模型
    public let imageItem: PuzzleImageItem
    public let level: PuzzleLevel
    public let sourceImage: UIImage

    // 场景节点
    public private(set) var boardBackgroundNode: SKShapeNode!
    public private(set) var boardOutlineNode: SKShapeNode!
    public private(set) var ghostImageNode: SKSpriteNode!
    public private(set) var dividerNode: SKSpriteNode!
    public private(set) var dividerHandleNode: SKShapeNode!
    public private(set) var trayNode: StorageTrayNode!

    // 拼图碎片节点集合
    public private(set) var pieceNodes: [Int: PuzzlePieceNode] = [:]
    public private(set) var pieceDatas: [PuzzlePieceData] = []

    // 布局度量
    public private(set) var currentSplitRatio: CGFloat = 0.75 // 默认左 75%，右 25%
    public private(set) var boardRect: CGRect = .zero
    public private(set) var pileRect: CGRect = .zero

    // 交互拖拽状态
    private var activeDraggedPieces: [PuzzlePieceNode] = []
    private var dragStartTouchPoint: CGPoint = .zero
    private var dragStartPiecePositions: [Int: CGPoint] = [:]
    private var isDraggingDivider: Bool = false
    private var highestZIndex: CGFloat = 100
    private var rotationGestureRecognizer: UIRotationGestureRecognizer?
    private var woodBackdropNode: SKSpriteNode?

    // 外部回调
    public var onProgressUpdate: ((Int, Int) -> Void)? // (已拼好数, 总数)
    public var onPiecesReady: (() -> Void)? // 碎片切片与贴图全部构建完成就绪
    public var onGameCompleted: ((TimeInterval) -> Void)?

    // 计时器与完成标记
    public private(set) var startTime: Date = Date()
    public private(set) var isCompleted: Bool = false

    public init(size: CGSize, imageItem: PuzzleImageItem, level: PuzzleLevel, sourceImage: UIImage) {
        self.imageItem = imageItem
        self.level = level
        self.sourceImage = sourceImage
        self.currentSplitRatio = CGFloat(GameSettings.shared.splitRatio)
        super.init(size: size)
        self.scaleMode = .resizeFill
        self.backgroundColor = MaillardTheme.ui.sceneBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        setupLayoutMetrics()
        setupBackgroundAndBoard()
        setupDivider()
        setupTray()
        setupParallax()
        buildAndDistributePieces()
        setupGestureRecognizers(on: view)
    }

    public func updateSplitRatio(_ newRatio: CGFloat) {
        currentSplitRatio = newRatio
        setupLayoutMetrics()
        boardBackgroundNode.path = UIBezierPath(roundedRect: boardRect, cornerRadius: 8).cgPath
        ghostImageNode.size = boardRect.size
        ghostImageNode.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        boardOutlineNode.path = UIBezierPath(roundedRect: boardRect, cornerRadius: 8).cgPath

        // 更新所有已拼好碎片与理论板位的锚定坐标
        for piece in pieceNodes.values {
            let correctX = boardRect.origin.x + piece.pieceData.targetGridNormalized.x * boardRect.width
            let correctY = boardRect.origin.y + (1.0 - piece.pieceData.targetGridNormalized.y) * boardRect.height
            piece.correctBoardPosition = CGPoint(x: correctX, y: correctY)
            if piece.isPlaced {
                piece.position = piece.correctBoardPosition
            }
        }
    }

    // MARK: - 布局与初始化

    private func setupLayoutMetrics() {
        let topBarInset: CGFloat = 60
        let bottomTrayInset: CGFloat = 90
        let safeHeight = size.height - topBarInset - bottomTrayInset

        let leftWidth = size.width * currentSplitRatio
        let rightWidth = size.width - leftWidth

        // 计算 16:9 的拼图板在左侧区域的最大居中 Rect
        let padding: CGFloat = 20
        let availBoardW = leftWidth - padding * 2
        let availBoardH = safeHeight - padding * 2

        var boardW = availBoardW
        var boardH = boardW / (16.0 / 9.0)
        if boardH > availBoardH {
            boardH = availBoardH
            boardW = boardH * (16.0 / 9.0)
        }

        let boardOriginX = padding + (availBoardW - boardW) / 2
        let boardOriginY = bottomTrayInset + padding + (availBoardH - boardH) / 2
        self.boardRect = CGRect(x: boardOriginX, y: boardOriginY, width: boardW, height: boardH)

        // 右侧碎片堆放区
        self.pileRect = CGRect(x: leftWidth + 10, y: bottomTrayInset + 10, width: rightWidth - 20, height: safeHeight)
    }

    private func setupBackgroundAndBoard() {
        // 木纹/绒布桌面底色
        let matNode = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        matNode.fillColor = MaillardTheme.ui.mat
        matNode.strokeColor = .clear
        matNode.zPosition = -10
        addChild(matNode)

        // 胡桃木纹桌面材质（GPT 生成，按 cover 等比铺满避免拉伸变形）
        let woodTexture = SKTexture(imageNamed: "maillard_board")
        let woodTexSize = woodTexture.size()
        if woodTexSize.width > 0 && woodTexSize.height > 0 {
            let coverScale = max(size.width / woodTexSize.width, size.height / woodTexSize.height)
            let woodNode = SKSpriteNode(
                texture: woodTexture,
                size: CGSize(width: woodTexSize.width * coverScale, height: woodTexSize.height * coverScale)
            )
            woodNode.position = CGPoint(x: size.width / 2, y: size.height / 2)
            woodNode.zPosition = -9
            woodNode.alpha = 0.92
            self.woodBackdropNode = woodNode
            addChild(woodNode)
        }

        // 拼图底板底座
        boardBackgroundNode = SKShapeNode(rect: boardRect, cornerRadius: 8)
        boardBackgroundNode.fillColor = MaillardTheme.ui.boardFill
        boardBackgroundNode.strokeColor = MaillardTheme.ui.boardStroke
        boardBackgroundNode.lineWidth = 2.0
        boardBackgroundNode.zPosition = 1
        addChild(boardBackgroundNode)

        // 幽灵原图（按设置可开启作为微弱半透明底图参考）
        ghostImageNode = SKSpriteNode(texture: SKTexture(image: sourceImage), size: boardRect.size)
        ghostImageNode.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        ghostImageNode.zPosition = 2
        ghostImageNode.alpha = GameSettings.shared.showGhostOutline ? 0.20 : 0.0
        addChild(ghostImageNode)

        // 拼图边缘外框线
        boardOutlineNode = SKShapeNode(rect: boardRect, cornerRadius: 8)
        boardOutlineNode.fillColor = .clear
        boardOutlineNode.strokeColor = MaillardTheme.ui.ghostOutline
        boardOutlineNode.lineWidth = 1.5
        boardOutlineNode.zPosition = 3
        addChild(boardOutlineNode)
    }

    /// 场景尺寸变化（首次布局校准）时保持木纹背景 cover 铺满
    public func refreshWoodBackdropCover() {
        guard let wood = woodBackdropNode, size.width > 0, size.height > 0,
              let texSize = wood.texture?.size(), texSize.width > 0, texSize.height > 0 else { return }
        let coverScale = max(size.width / texSize.width, size.height / texSize.height)
        wood.size = CGSize(width: texSize.width * coverScale, height: texSize.height * coverScale)
        wood.position = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    private func setupDivider() {
        let dividerX = size.width * currentSplitRatio
        dividerNode = SKSpriteNode(color: MaillardTheme.ui.divider, size: CGSize(width: 4, height: size.height))
        dividerNode.position = CGPoint(x: dividerX, y: size.height / 2)
        dividerNode.zPosition = 40
        addChild(dividerNode)

        // 分隔条中间手柄（可触摸抓取区）
        dividerHandleNode = SKShapeNode(circleOfRadius: 18)
        dividerHandleNode.position = CGPoint(x: dividerX, y: size.height / 2)
        dividerHandleNode.fillColor = MaillardTheme.ui.dividerHandle
        dividerHandleNode.strokeColor = MaillardTheme.ui.dividerHandleStroke
        dividerHandleNode.lineWidth = 2.0
        dividerHandleNode.zPosition = 41
        addChild(dividerHandleNode)
    }

    private func setupTray() {
        let trayWidth = min(size.width * 0.58, 480)
        trayNode = StorageTrayNode(trayWidth: trayWidth, trayHeight: 76)
        trayNode.position = CGPoint(x: size.width * 0.42, y: 45)
        addChild(trayNode)
    }

    private func setupParallax() {
        if GameSettings.shared.parallax3DEnabled {
            ParallaxMotionManager.shared.start()
            ParallaxMotionManager.shared.onMotionUpdate = { [weak self] roll, pitch in
                guard let self = self else { return }
                // 微弱微移提升空间层级 3D 感
                let maxOffset: CGFloat = 8.0
                let offsetX = min(max(roll * 10, -maxOffset), maxOffset)
                let offsetY = min(max(pitch * 10, -maxOffset), maxOffset)
                self.boardOutlineNode.position = CGPoint(x: offsetX * 0.4, y: offsetY * 0.4)
                self.trayNode.position.x = (self.size.width * 0.42) + offsetX * 0.6
            }
        }
    }

    // MARK: - 切割与碎片构建

    private func buildAndDistributePieces() {
        // 使用图片ID的哈希作为一致性随机种子
        let seed = UInt64(abs(imageItem.id.hashValue))
        self.pieceDatas = PuzzleMeshGenerator.generateGrid(columns: level.gridColumns, rows: level.gridRows, seed: seed)

        // 异步渲染高质量碎片 3D 贴图
        PuzzlePieceRenderer.renderAllPieces(sourceImage: sourceImage, pieces: pieceDatas, boardPixelSize: boardRect.size) { [weak self] renderedDict in
            guard let self = self else { return }
            self.distributePiecesInPile(renderedDict: renderedDict)
        }
    }

    private func distributePiecesInPile(renderedDict: [Int: PuzzlePieceRenderer.RenderedPieceTexture]) {
        let allowRotation = GameSettings.shared.allowFreeRotation
        var rng = SeededRandom(seed: 1234567)

        // 尝试加载中断续玩快照
        let savedSnapshot = SessionSaveManager.shared.load()
        let isResuming = (savedSnapshot != nil && savedSnapshot?.imageId == imageItem.id && savedSnapshot?.levelId == level.id)
        let savedDict = isResuming ? Dictionary(uniqueKeysWithValues: (savedSnapshot!.pieces.map { ($0.id, $0) })) : [:]

        for pieceData in pieceDatas {
            guard let tex = renderedDict[pieceData.id] else { continue }
            let node = PuzzlePieceNode(pieceData: pieceData, textures: tex)

            // 计算理论板上坐标（原点左下角）
            let correctX = boardRect.origin.x + pieceData.targetGridNormalized.x * boardRect.width
            let correctY = boardRect.origin.y + (1.0 - pieceData.targetGridNormalized.y) * boardRect.height
            node.correctBoardPosition = CGPoint(x: correctX, y: correctY)

            if let saved = savedDict[pieceData.id] {
                // 恢复先前保存的位置与状态
                node.isPlaced = saved.isPlaced
                node.groupId = saved.groupId
                node.zRotation = saved.rotation
                if saved.isPlaced {
                    node.position = node.correctBoardPosition
                    node.zPosition = 10
                    node.shadowSprite.alpha = 0
                } else if let slotIdx = saved.traySlotIndex {
                    node.position = CGPoint(x: saved.currentX, y: saved.currentY)
                    node.zPosition = 20
                    trayNode.placePiece(node, intoSlot: slotIdx)
                } else {
                    node.position = CGPoint(x: saved.currentX, y: saved.currentY)
                    node.zPosition = 20
                }
            } else {
                // 初始散落在右侧堆放区：内缩安全边界，避免碎片边缘溢出屏幕或被拖动滑块遮挡
                let pW = boardRect.width * pieceData.normalizedSize.width
                let pH = boardRect.height * pieceData.normalizedSize.height
                let insetX = max(10, pW * 0.4)
                let insetY = max(10, pH * 0.4)

                let availW = max(20, pileRect.width - insetX * 2)
                let availH = max(20, pileRect.height - insetY * 2)

                let randomX = pileRect.origin.x + insetX + CGFloat(rng.next() % 1000) / 1000.0 * availW
                let randomY = pileRect.origin.y + insetY + CGFloat(rng.next() % 1000) / 1000.0 * availH
                node.position = CGPoint(x: randomX, y: randomY)

                // 自由旋转开关逻辑
                if allowRotation {
                    let randomAngle = (CGFloat(rng.next() % 360) - 180.0) * (.pi / 180.0)
                    node.zRotation = randomAngle
                } else {
                    node.zRotation = 0
                }
                node.zPosition = 20
            }

            addChild(node)
            pieceNodes[pieceData.id] = node
        }

        let placedCount = pieceNodes.values.filter { $0.isPlaced }.count
        onProgressUpdate?(placedCount, pieceDatas.count)
        onPiecesReady?()
    }

    public func applyRotationSettingChanged(allowFree: Bool) {
        if !allowFree {
            // 关闭自由旋转时，将所有未拼好的碎片以平滑动画恢复正向角度 0
            for piece in pieceNodes.values where !piece.isPlaced {
                piece.run(SKAction.rotate(toAngle: 0, duration: 0.25, shortestUnitArc: true))
            }
        }
    }

    public func applyGhostOutlineSettingChanged(showGhost: Bool) {
        ghostImageNode?.run(SKAction.fadeAlpha(to: showGhost ? 0.20 : 0.0, duration: 0.2))
    }

    public func applyParallaxSettingChanged(enabled: Bool) {
        if enabled {
            ParallaxMotionManager.shared.start()
        } else {
            ParallaxMotionManager.shared.stop()
            self.boardOutlineNode?.position = .zero
            self.trayNode?.position.x = self.size.width * 0.42
        }
    }

    // MARK: - 触摸手势交互

    private func setupGestureRecognizers(on view: SKView) {
        // 双指旋转手势（仅当允许自由旋转开启时触发）
        let rotationGesture = UIRotationGestureRecognizer(target: self, action: #selector(handleRotationGesture(_:)))
        rotationGesture.delegate = self
        view.addGestureRecognizer(rotationGesture)
        self.rotationGestureRecognizer = rotationGesture
    }

    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc private func handleRotationGesture(_ gesture: UIRotationGestureRecognizer) {
        guard GameSettings.shared.allowFreeRotation else { return }
        guard !activeDraggedPieces.isEmpty else { return }

        if gesture.state == .changed {
            let rotationDelta = gesture.rotation
            for piece in activeDraggedPieces {
                piece.zRotation += rotationDelta
            }
            gesture.rotation = 0
        }
    }

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)

        // 1. 判断是否触摸到区域滑块
        if abs(touchLocation.x - dividerNode.position.x) < 25 {
            isDraggingDivider = true
            return
        }

        // 2. 判断是否点击托盘中的碎片
        for piece in pieceNodes.values where piece.traySlotIndex != nil {
            if piece.contains(touchLocation) {
                trayNode.removePiece(fromSlot: piece.traySlotIndex!)
                highestZIndex += 10
                piece.zPosition = highestZIndex
                piece.animatePickup()
                GameFeedbackEngine.shared.triggerPickup()
                beginDragging(pieces: [piece], at: touchLocation)
                return
            }
        }

        // 3. 拾取桌面上的拼图碎片（选取顶层未拼好的碎片，带同组联动）
        let touchedNodes = nodes(at: touchLocation)
        var hitPiece: PuzzlePieceNode? = nil

        for n in touchedNodes {
            if let p = n as? PuzzlePieceNode, !p.isPlaced {
                hitPiece = p
                break
            } else if let p = n.parent as? PuzzlePieceNode, !p.isPlaced {
                hitPiece = p
                break
            }
        }

        if let piece = hitPiece {
            // 找出属于同一 groupId 的所有已咬合联动的碎片一起拖动
            let groupPieces = pieceNodes.values.filter { $0.groupId == piece.groupId && !$0.isPlaced }
            highestZIndex += 10
            for p in groupPieces {
                p.zPosition = highestZIndex
                p.animatePickup()
            }
            GameFeedbackEngine.shared.triggerPickup()
            beginDragging(pieces: groupPieces, at: touchLocation)
        }
    }

    private func beginDragging(pieces: [PuzzlePieceNode], at point: CGPoint) {
        activeDraggedPieces = pieces
        dragStartTouchPoint = point
        dragStartPiecePositions.removeAll()
        for p in pieces {
            dragStartPiecePositions[p.pieceData.id] = p.position
        }
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)

        // 拖动区域滑块
        if isDraggingDivider {
            let minX = size.width * 0.55
            let maxX = size.width * 0.85
            let clampedX = min(max(touchLocation.x, minX), maxX)
            let newRatio = clampedX / size.width
            GameSettings.shared.splitRatio = Double(newRatio)
            dividerNode.position.x = clampedX
            dividerHandleNode.position.x = clampedX
            updateSplitRatio(newRatio)
            return
        }

        // 拖动选中的拼图或成组拼图
        guard !activeDraggedPieces.isEmpty else { return }
        let deltaX = touchLocation.x - dragStartTouchPoint.x
        let deltaY = touchLocation.y - dragStartTouchPoint.y

        for piece in activeDraggedPieces {
            if let startPos = dragStartPiecePositions[piece.pieceData.id] {
                let targetX = startPos.x + deltaX
                let targetY = startPos.y + deltaY
                // 防滑出屏幕可视边界约束（保留至少 15pt 在可视区域内）
                let clampedX = min(max(targetX, 15), size.width - 15)
                let clampedY = min(max(targetY, 15), size.height - 15)
                piece.position = CGPoint(x: clampedX, y: clampedY)
            }
        }
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let touchLocation = touch.location(in: self)

        if isDraggingDivider {
            isDraggingDivider = false
            return
        }

        guard !activeDraggedPieces.isEmpty else { return }
        let dragged = activeDraggedPieces
        activeDraggedPieces = []

        // A. 检查是否拖入了底部的 5 格临时存放托盘（仅单块碎片允许存入）
        if dragged.count == 1, let singlePiece = dragged.first {
            if let slotIndex = trayNode.hitSlotIndex(at: touchLocation) {
                trayNode.placePiece(singlePiece, intoSlot: slotIndex)
                GameFeedbackEngine.shared.triggerDrop()
                saveCurrentSession()
                return
            }
        }

        // B. 检查是否与正确板位磁吸
        var anySnapped = false
        for piece in dragged {
            let isSnap = SnapEngine.checkSnap(
                currentPos: piece.position,
                targetPos: piece.correctBoardPosition,
                pieceSize: CGSize(width: boardRect.width * piece.pieceData.normalizedSize.width, height: boardRect.height * piece.pieceData.normalizedSize.height),
                currentRotation: piece.zRotation,
                allowFreeRotation: GameSettings.shared.allowFreeRotation
            )

            if isSnap {
                anySnapped = true
                break
            }
        }

        if anySnapped {
            // 整组先统一设置 isPlaced = true 确保计数准确，再播放吸附入位动画
            for piece in dragged {
                piece.isPlaced = true
                piece.traySlotIndex = nil
            }
            let placedCount = pieceNodes.values.filter { $0.isPlaced }.count
            onProgressUpdate?(placedCount, pieceDatas.count)
            GameFeedbackEngine.shared.triggerSnap()
            saveCurrentSession()

            // 播放平滑弹簧入位与结算检测
            for piece in dragged {
                piece.animateSnap(to: piece.correctBoardPosition) { [weak self] in
                    self?.checkGameCompletion()
                }
            }
        } else {
            // C. 检查未归位碎片之间是否有相邻咬合成组
            checkPieceToPieceMerge(draggedPieces: dragged)
            for piece in dragged {
                piece.animateDrop()
            }
            GameFeedbackEngine.shared.triggerDrop()
            saveCurrentSession()
        }
    }

    private func checkPieceToPieceMerge(draggedPieces: [PuzzlePieceNode]) {
        let pieceSize = CGSize(
            width: boardRect.width * (1.0 / CGFloat(level.gridColumns)),
            height: boardRect.height * (1.0 / CGFloat(level.gridRows))
        )
        let allowRotation = GameSettings.shared.allowFreeRotation

        for dragged in draggedPieces {
            for other in pieceNodes.values where !other.isPlaced && other.groupId != dragged.groupId && other.traySlotIndex == nil {
                let snap = SnapEngine.checkAdjacentPiecesSnap(
                    pieceA: dragged.pieceData, posA: dragged.position, rotA: dragged.zRotation,
                    pieceB: other.pieceData, posB: other.position, rotB: other.zRotation,
                    pieceSize: pieceSize, allowFreeRotation: allowRotation
                )

                if snap {
                    // 合并成同一组，计算理论相对网格偏移以矫正位置对齐
                    let colDiff = other.pieceData.col - dragged.pieceData.col
                    let rowDiff = other.pieceData.row - dragged.pieceData.row
                    let targetX = dragged.position.x + CGFloat(colDiff) * pieceSize.width
                    let targetY = dragged.position.y - CGFloat(rowDiff) * pieceSize.height
                    let oldGroupId = other.groupId
                    let targetGroupId = dragged.groupId
                    let offsetX = targetX - other.position.x
                    let offsetY = targetY - other.position.y

                    // 对被咬合的整个碎片子群执行对齐微移和平滑归正角度
                    for p in pieceNodes.values where p.groupId == oldGroupId {
                        p.groupId = targetGroupId
                        let targetPos = CGPoint(x: p.position.x + offsetX, y: p.position.y + offsetY)
                        p.run(SKAction.move(to: targetPos, duration: 0.12))
                        if allowRotation {
                            p.run(SKAction.rotate(toAngle: dragged.zRotation, duration: 0.12, shortestUnitArc: true))
                        }
                    }

                    GameFeedbackEngine.shared.triggerSnap()
                    saveCurrentSession()
                    break
                }
            }
        }
    }

    private func checkGameCompletion() {
        let placedCount = pieceNodes.values.filter { $0.isPlaced }.count
        onProgressUpdate?(placedCount, pieceDatas.count)

        if placedCount == pieceDatas.count && !isCompleted {
            isCompleted = true
            SessionSaveManager.shared.clear()
            let elapsed = Date().timeIntervalSince(startTime)
            ProgressManager.shared.markCompleted(imageId: imageItem.id, levelId: level.id, elapsedSeconds: elapsed)
            GameFeedbackEngine.shared.triggerVictory()
            onGameCompleted?(elapsed)
        } else {
            saveCurrentSession()
        }
    }

    public func saveCurrentSession() {
        guard !isCompleted else { return }
        let savedPieces: [SavedPieceState] = pieceNodes.values.map { node in
            SavedPieceState(
                id: node.pieceData.id,
                currentX: node.position.x,
                currentY: node.position.y,
                rotation: node.zRotation,
                isPlaced: node.isPlaced,
                traySlotIndex: node.traySlotIndex,
                groupId: node.groupId
            )
        }
        let snapshot = GameSessionSnapshot(
            imageId: imageItem.id,
            levelId: level.id,
            elapsedTime: Date().timeIntervalSince(startTime),
            pieces: savedPieces,
            splitRatio: Double(currentSplitRatio),
            timestamp: Date()
        )
        SessionSaveManager.shared.save(snapshot: snapshot)
    }

    public override func willMove(from view: SKView) {
        super.willMove(from: view)
        saveCurrentSession()
        ParallaxMotionManager.shared.stop()
        if let gesture = rotationGestureRecognizer {
            view.removeGestureRecognizer(gesture)
            self.rotationGestureRecognizer = nil
        }

        // 主动解除节点树与纹理引用，防止大碎片关卡残留占用 GPU 显存
        removeAllActions()
        removeAllChildren()
        pieceNodes.removeAll()
        activeDraggedPieces.removeAll()
        dragStartPiecePositions.removeAll()
    }

    /// 系统中断保护（电话呼入/下拉通知中心/控制中心触发 touchesCancelled 时安全复位）
    public func cancelActiveDragging() {
        guard !activeDraggedPieces.isEmpty else { return }
        let dragged = activeDraggedPieces
        activeDraggedPieces = []
        isDraggingDivider = false

        for piece in dragged {
            piece.animateDrop()
        }
        saveCurrentSession()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        cancelActiveDragging()
    }
}
