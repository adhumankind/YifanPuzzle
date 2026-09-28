import CoreImage
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
    private var trayPressRecognizer: UILongPressGestureRecognizer?
    private var woodBackdropNode: SKSpriteNode?
    /// 本局是否使用过辅助道具（用于"独立完成"成就判定）
    public private(set) var usedAssistProps: Bool = false
    /// 通关时新解锁的成就（供结算弹窗展示）
    public private(set) var newlyEarnedAchievements: [ProgressManager.Achievement] = []

    // 外部回调
    public var onProgressUpdate: ((Int, Int) -> Void)? // (已拼好数, 总数)
    public var onPiecesReady: (() -> Void)? // 碎片切片与贴图全部构建完成就绪
    public var onAchievementsUnlocked: (([ProgressManager.Achievement]) -> Void)? // 成就解锁即时提示
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
        print("SCENE-BREADCRUMB: init done")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func didMove(to view: SKView) {
        super.didMove(to: view)
        print("SCENE-BREADCRUMB: didMove begin")
        setupLayoutMetrics()
        print("SCENE-BREADCRUMB: layout ok")
        setupBackgroundAndBoard()
        print("SCENE-BREADCRUMB: background ok")
        setupDivider()
        print("SCENE-BREADCRUMB: divider ok")
        setupTray()
        print("SCENE-BREADCRUMB: tray ok")
        setupParallax()
        print("SCENE-BREADCRUMB: parallax ok")
        buildAndDistributePieces()
        print("SCENE-BREADCRUMB: build dispatched")
        setupGestureRecognizers(on: view)
        print("SCENE-BREADCRUMB: didMove done")
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

        // 幽灵参考底图：先占位，单色（去饱和）版本在后台线程生成后换装淡入
        ghostImageNode = SKSpriteNode(texture: nil, color: .clear, size: boardRect.size)
        ghostImageNode.position = CGPoint(x: boardRect.midX, y: boardRect.midY)
        ghostImageNode.zPosition = 2
        ghostImageNode.alpha = GameSettings.shared.showGhostOutline ? 0.14 : 0.0
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
        // 使用图片 ID 的稳定哈希作为一致性随机种子（跨启动一致，保证断点续玩碎片形状不变）
        let seed = PuzzleMeshGenerator.stableSeed(for: imageItem.id)
        self.pieceDatas = PuzzleMeshGenerator.generateGrid(columns: level.gridColumns, rows: level.gridRows, seed: seed)
        print("SCENE-BREADCRUMB: mesh generated \(pieceDatas.count)")

        // 单色幽灵底图在后台线程生成（CoreImage 滤重，避免主线程卡顿与真机渲染上下文风险）
        let source = sourceImage
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let mono = Self.makeMonoGhostImage(source)
            DispatchQueue.main.async {
                guard let self = self, let ghost = self.ghostImageNode else { return }
                ghost.texture = SKTexture(image: mono)
                let target: CGFloat = GameSettings.shared.showGhostOutline ? 0.14 : 0.0
                ghost.run(SKAction.fadeAlpha(to: target, duration: 0.25))
            }
        }

        // 异步渲染高质量碎片 3D 贴图
        print("SCENE-BREADCRUMB: render dispatched")
        PuzzlePieceRenderer.renderAllPieces(sourceImage: sourceImage, pieces: pieceDatas, boardPixelSize: boardRect.size) { [weak self] renderedDict in
            print("SCENE-BREADCRUMB: render completion on main")
            guard let self = self else { return }
            self.distributePiecesInPile(renderedDict: renderedDict)
            print("SCENE-BREADCRUMB: pieces distributed")
        }
    }

    private func distributePiecesInPile(renderedDict: [Int: PuzzlePieceRenderer.RenderedPieceTexture]) {
        let allowRotation = GameSettings.shared.allowFreeRotation
        var rng = SeededRandom(seed: 1234567)

        // 尝试加载中断续玩快照
        let savedSnapshot = SessionSaveManager.shared.load()
        let isResuming = (savedSnapshot != nil && savedSnapshot?.imageId == imageItem.id && savedSnapshot?.levelId == level.id)
        // 逐条填充并忽略重复 id（Dictionary(uniqueKeysWithValues:) 遇重复键会直接崩溃）
        var savedDict: [Int: SavedPieceState] = [:]
        if isResuming {
            for piece in savedSnapshot!.pieces where savedDict[piece.id] == nil {
                savedDict[piece.id] = piece
            }
        }
        if isResuming {
            // 恢复本局是否已使用过辅助道具（保证"独立完成"成就判定跨中断准确）
            usedAssistProps = savedSnapshot?.usedAssistProps ?? false
        }

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
        ghostImageNode?.run(SKAction.fadeAlpha(to: showGhost ? 0.14 : 0.0, duration: 0.2))
    }

    /// 拖拽期间临时增亮幽灵参考底图（0.14→0.24），松手恢复，方便对照归位
    private func setGhostBoost(_ boosted: Bool) {
        guard let ghost = ghostImageNode else { return }
        let target: CGFloat = GameSettings.shared.showGhostOutline ? (boosted ? 0.24 : 0.14) : 0.0
        ghost.run(SKAction.fadeAlpha(to: target, duration: 0.18))
    }

    /// 将原图转为单色（去饱和）版本，用作极淡的半透明参考底图
    private static func makeMonoGhostImage(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image),
              let filter = CIFilter(name: "CIPhotoEffectMono") else { return image }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        guard let output = filter.outputImage,
              let cgImage = CIContext(options: nil).createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cgImage)
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

        // 长按托盘：一键把散落区最近的碎片收进空格（无限次）
        let trayPress = UILongPressGestureRecognizer(target: self, action: #selector(handleTrayLongPress(_:)))
        trayPress.minimumPressDuration = 0.5
        trayPress.delegate = self
        view.addGestureRecognizer(trayPress)
        self.trayPressRecognizer = trayPress
    }

    @objc private func handleTrayLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, let skView = gesture.view else { return }
        // 手势坐标在 UIKit 视图坐标系，需转换为 SpriteKit 场景坐标系
        let scenePoint = convertPoint(fromView: gesture.location(in: skView))
        if trayNode.containsWorldPoint(scenePoint) {
            collectScatteredPieces()
        }
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
                setGhostBoost(true)
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
            setGhostBoost(true)
            beginDragging(pieces: groupPieces, at: touchLocation)
        }
    }

    private func beginDragging(pieces: [PuzzlePieceNode], at point: CGPoint) {
        activeDraggedPieces = pieces
        dragStartTouchPoint = point
        dragStartPiecePositions.removeAll()

        // 拿起放大（1.0→1.06）会让手指下的纹理点向外漂移，反向补偿位置使大碎片也严丝合缝跟手
        if let primary = pieces.first {
            let grabVector = CGPoint(x: point.x - primary.position.x, y: point.y - primary.position.y)
            let compensation = CGPoint(x: -grabVector.x * 0.06, y: -grabVector.y * 0.06)
            for p in pieces {
                p.position = CGPoint(x: p.position.x + compensation.x, y: p.position.y + compensation.y)
                dragStartPiecePositions[p.pieceData.id] = p.position
            }
            // 触摸基准点同步平移，保证后续移动差值依旧 1:1 跟手
            dragStartTouchPoint = CGPoint(x: point.x + compensation.x, y: point.y + compensation.y)
        } else {
            for p in pieces {
                dragStartPiecePositions[p.pieceData.id] = p.position
            }
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
            persistSplitRatio()
            return
        }

        guard !activeDraggedPieces.isEmpty else { return }
        setGhostBoost(false)
        let dragged = activeDraggedPieces
        activeDraggedPieces = []

        // A. 检查是否拖入了底部的 5 格临时存放托盘（仅单块碎片允许存入）
        if dragged.count == 1, let singlePiece = dragged.first {
            if let slotIndex = trayNode.hitSlotIndex(at: touchLocation) {
                if let fromSlot = singlePiece.traySlotIndex, fromSlot != slotIndex,
                   let occupant = trayNode.slotPieces[slotIndex], occupant !== singlePiece {
                    // 托盘内互拖：双方暂离槽位再对调，占用者入驻原槽
                    trayNode.removePiece(fromSlot: slotIndex)
                    trayNode.removePiece(fromSlot: fromSlot)
                    trayNode.placePiece(occupant, intoSlot: fromSlot)
                    trayNode.placePiece(singlePiece, intoSlot: slotIndex)
                } else {
                    trayNode.placePiece(singlePiece, intoSlot: slotIndex)
                }
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

            // 播放平滑弹簧入位、四角金尘与结算检测
            for piece in dragged {
                piece.animateSnap(to: piece.correctBoardPosition) { [weak self] in
                    guard let self = self else { return }
                    self.spawnCornerDust(for: piece)
                    self.checkGameCompletion()
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
            newlyEarnedAchievements = ProgressManager.shared.evaluateAchievements(
                imageId: imageItem.id,
                levelId: level.id,
                usedAssistProps: usedAssistProps
            )
            if !newlyEarnedAchievements.isEmpty {
                onAchievementsUnlocked?(newlyEarnedAchievements)
            }
            GameFeedbackEngine.shared.triggerVictory()
            celebrateCompletion()
            // 彩带先飘 0.9 秒让玩家看清满屏庆祝，再淡入结算弹窗（弱引用防止场景销毁后回调）
            run(SKAction.sequence([
                SKAction.wait(forDuration: 0.9),
                SKAction.run { [weak self] in
                    self?.onGameCompleted?(elapsed)
                }
            ]))
        } else {
            saveCurrentSession()
        }
    }

    // MARK: - 无限辅助道具（让玩家专注体验拼图乐趣，不设阻碍）

    /// 为辅助道具挑选一块候选碎片（优先散落区，其次托盘；排除正在拖拽与正在施法的）
    private func selectAssistCandidate() -> PuzzlePieceNode? {
        let candidates = pieceNodes.values.filter {
            !$0.isPlaced && !activeDraggedPieces.contains($0) && $0.action(forKey: "magic_place") == nil
        }
        guard !candidates.isEmpty else { return nil }
        let pilePieces = candidates.filter { $0.traySlotIndex == nil }
        let pool = pilePieces.isEmpty ? candidates : pilePieces
        return pool.randomElement()
    }

    /// 「找一找」道具：为一块未归位碎片给出提示（本体金色光环 + 正确板位高亮闪烁）
    public func giveHint() {
        guard let piece = selectAssistCandidate() else { return }
        usedAssistProps = true
        GameFeedbackEngine.shared.triggerHint()

        // 本体金色光环脉冲（扩散两轮）
        let radius = max(piece.surfaceSprite.size.width, piece.surfaceSprite.size.height) * 0.62
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.strokeColor = MaillardTheme.ui.slotPulse
        ring.fillColor = .clear
        ring.lineWidth = 3
        ring.glowWidth = 4
        ring.position = piece.position
        ring.zPosition = 90
        ring.alpha = 0.9
        addChild(ring)

        let ringWave: SKAction = {
            let expand = SKAction.group([
                SKAction.scale(to: 1.4, duration: 0.5),
                SKAction.fadeAlpha(to: 0.0, duration: 0.5)
            ])
            expand.timingMode = .easeOut
            let reset = SKAction.run { ring.setScale(1.0); ring.alpha = 0.9 }
            return SKAction.sequence([expand, reset, SKAction.wait(forDuration: 0.1), expand, SKAction.removeFromParent()])
        }()
        ring.run(ringWave)

        // 正确板位闪烁高亮（虚线描边 + 抬高层级，密集碎片间依旧醒目；双闪后优雅消散）
        let w = boardRect.width * piece.pieceData.normalizedSize.width
        let h = boardRect.height * piece.pieceData.normalizedSize.height
        let solidPath = UIBezierPath(roundedRect: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), cornerRadius: 6).cgPath
        let dashedPath = solidPath.copy(dashingWithPhase: 0, lengths: [9, 6])
        let target = SKShapeNode(path: dashedPath)
        target.strokeColor = MaillardTheme.ui.ghostOutline
        target.fillColor = SKColor(red: 1.0, green: 0.78, blue: 0.40, alpha: 0.10)
        target.lineWidth = 2.5
        target.glowWidth = 3
        target.position = piece.correctBoardPosition
        target.zPosition = 35
        addChild(target)

        let flash = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.25, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.fadeAlpha(to: 0.25, duration: 0.3),
            SKAction.fadeAlpha(to: 1.0, duration: 0.3),
            SKAction.wait(forDuration: 0.5),
            SKAction.fadeOut(withDuration: 0.45),
            SKAction.removeFromParent()
        ])
        target.run(flash)
        spawnSparkles(at: piece.correctBoardPosition, count: 6)
    }

    /// 「拼一块」道具：将一块未归位碎片魔法般地自动送回正确板位（无限次）
    public func autoPlaceOnePiece() {
        guard let piece = selectAssistCandidate() else { return }
        usedAssistProps = true

        // 若碎片正在托盘中，先释放格子
        if let slot = piece.traySlotIndex {
            trayNode.removePiece(fromSlot: slot)
        }
        piece.traySlotIndex = nil
        highestZIndex += 10
        piece.zPosition = highestZIndex

        // 与磁吸流程一致：先预置状态保证计数与存档竞态安全
        piece.isPlaced = true
        let placedCount = pieceNodes.values.filter { $0.isPlaced }.count
        onProgressUpdate?(placedCount, pieceDatas.count)
        GameFeedbackEngine.shared.triggerMagic()
        saveCurrentSession()

        spawnSparkles(at: piece.position, count: 12)

        // 魔法蓄力 → 平滑飞行归位 → 星光绽放
        let lift = SKAction.scale(to: 1.16, duration: 0.16)
        lift.timingMode = .easeOut
        let cast = SKAction.run { [weak self, weak piece] in
            guard let self = self, let piece = piece else { return }
            piece.animateSnap(to: piece.correctBoardPosition) { [weak self] in
                guard let self = self else { return }
                self.spawnSparkles(at: piece.correctBoardPosition, count: 8)
                self.spawnCornerDust(for: piece)
                GameFeedbackEngine.shared.triggerSnap()
                self.checkGameCompletion()
            }
        }
        piece.run(SKAction.sequence([lift, SKAction.wait(forDuration: 0.05), cast]), withKey: "magic_place")
    }

    /// 碎片归位瞬间四角扬起的金尘微粒（先扬起后飘落，模拟落座震尘）
    private func spawnCornerDust(for piece: PuzzlePieceNode) {
        let w = piece.surfaceSprite.size.width
        let h = piece.surfaceSprite.size.height
        let corners = [
            CGPoint(x: -w / 2, y: h / 2),
            CGPoint(x: w / 2, y: h / 2),
            CGPoint(x: -w / 2, y: -h / 2),
            CGPoint(x: w / 2, y: -h / 2)
        ]
        for corner in corners {
            for _ in 0..<2 {
                let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 1.5...3))
                dot.fillColor = SKColor(red: 1.0, green: 0.82, blue: 0.45, alpha: 0.9)
                dot.strokeColor = .clear
                dot.position = CGPoint(x: piece.position.x + corner.x, y: piece.position.y + corner.y)
                dot.zPosition = 95
                addChild(dot)

                let up = SKAction.move(
                    by: CGVector(dx: CGFloat.random(in: -8...8), dy: CGFloat.random(in: 10...22)),
                    duration: 0.35
                )
                up.timingMode = .easeOut
                let down = SKAction.group([
                    SKAction.move(by: CGVector(dx: CGFloat.random(in: -12...12), dy: CGFloat.random(in: -30 ... -16)), duration: 0.5),
                    SKAction.fadeOut(withDuration: 0.5)
                ])
                down.timingMode = .easeIn
                dot.run(SKAction.sequence([up, down, SKAction.removeFromParent()]))
            }
        }
    }

    /// 托盘一键收拢：把散落区离托盘最近的碎片自动收进空格（无限次，辅助不设阻碍）
    public func collectScatteredPieces() {
        let emptySlots = trayNode.emptySlotIndices()
        guard !emptySlots.isEmpty else { return }

        let candidates = pieceNodes.values.filter {
            !$0.isPlaced && $0.traySlotIndex == nil
                && !activeDraggedPieces.contains($0)
                && $0.action(forKey: "magic_place") == nil
                && $0.action(forKey: "collect") == nil
        }
        guard !candidates.isEmpty else { return }

        usedAssistProps = true
        GameFeedbackEngine.shared.triggerMagic()

        let trayCenter = trayNode.position
        // 排序策略：优先收"未咬合成组"的散落单块（成组块保持完整队列），同级再按离托盘就近
        let sorted = candidates.sorted { a, b in
            let aSingle = a.groupId == a.pieceData.id
            let bSingle = b.groupId == b.pieceData.id
            if aSingle != bSingle { return aSingle }
            let da = abs(a.position.x - trayCenter.x) + abs(a.position.y - trayCenter.y)
            let db = abs(b.position.x - trayCenter.x) + abs(b.position.y - trayCenter.y)
            return da < db
        }

        for (slotIndex, piece) in zip(emptySlots, sorted.prefix(emptySlots.count)) {
            highestZIndex += 10
            piece.zPosition = highestZIndex
            trayNode.placePiece(piece, intoSlot: slotIndex)
            piece.run(SKAction.sequence([
                SKAction.rotate(byAngle: .random(in: -0.8...0.8), duration: 0.3),
                SKAction.rotate(toAngle: 0, duration: 0.2, shortestUnitArc: true)
            ]), withKey: "collect")
        }
        saveCurrentSession()
    }

    /// 星光粒子绽放（辅助道具与归位时刻的通用点缀）
    private func spawnSparkles(at point: CGPoint, count: Int) {        for i in 0..<count {
            let dotSize = CGFloat.random(in: 4...8)
            let dot = SKShapeNode(circleOfRadius: dotSize / 2)
            dot.fillColor = SKColor(
                red: 1.0,
                green: CGFloat.random(in: 0.70...0.92),
                blue: CGFloat.random(in: 0.28...0.45),
                alpha: 1.0
            )
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = 95
            addChild(dot)

            let angle = (CGFloat(i) / CGFloat(count)) * 2 * .pi + .random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 26...64)
            let drift = SKAction.move(
                by: CGVector(dx: cos(angle) * distance, dy: sin(angle) * distance),
                duration: 0.55
            )
            drift.timingMode = .easeOut
            dot.run(SKAction.sequence([
                SKAction.group([drift, SKAction.fadeOut(withDuration: 0.55), SKAction.scale(to: 0.3, duration: 0.55)]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// 通关庆祝：全屏飘落的美拉德金色彩带
    public func celebrateCompletion() {
        guard size.width > 0 && size.height > 0 else { return }

        // 风铃音层稍晚于胜利主音效响起，与彩带飘落同步
        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.4),
            SKAction.run { GameFeedbackEngine.shared.triggerCelebration() }
        ]))
        let palette: [SKColor] = [
            SKColor(red: 0.906, green: 0.698, blue: 0.400, alpha: 1.0),
            SKColor(red: 0.776, green: 0.545, blue: 0.349, alpha: 1.0),
            SKColor(red: 0.961, green: 0.914, blue: 0.851, alpha: 1.0),
            SKColor(red: 0.878, green: 0.643, blue: 0.345, alpha: 1.0)
        ]

        for i in 0..<56 {
            let w = CGFloat.random(in: 6...11)
            let h = w * CGFloat.random(in: 1.4...2.2)
            let ribbon = SKShapeNode(rectOf: CGSize(width: w, height: h), cornerRadius: 2)
            ribbon.fillColor = palette[i % palette.count]
            ribbon.strokeColor = .clear
            ribbon.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + 30)
            ribbon.zPosition = 120
            ribbon.setScale(CGFloat.random(in: 0.7...1.4))
            addChild(ribbon)

            let fall = SKAction.moveTo(y: -40, duration: TimeInterval.random(in: 2.2...4.0))
            fall.timingMode = .easeIn
            let swayX = CGFloat.random(in: 26...80) * (Bool.random() ? 1 : -1)
            let sway = SKAction.repeat(
                SKAction.sequence([
                    SKAction.moveBy(x: swayX, y: 0, duration: 0.5),
                    SKAction.moveBy(x: -swayX, y: 0, duration: 0.5)
                ]),
                count: 6
            )
            let spin = SKAction.repeat(
                SKAction.rotate(byAngle: .random(in: 2...6) * (Bool.random() ? 1 : -1), duration: 0.6),
                count: 6
            )
            ribbon.run(sway)
            ribbon.run(spin)
            ribbon.run(SKAction.sequence([fall, SKAction.removeFromParent()]))
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
            timestamp: Date(),
            usedAssistProps: usedAssistProps
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
        if let trayPress = trayPressRecognizer {
            view.removeGestureRecognizer(trayPress)
            self.trayPressRecognizer = nil
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
        // 分隔条拖动被中断（如来电）时也必须复位，否则后续所有触摸都会被误判为拖动滑块
        if isDraggingDivider {
            isDraggingDivider = false
            persistSplitRatio()
        }

        guard !activeDraggedPieces.isEmpty else { return }
        let dragged = activeDraggedPieces
        activeDraggedPieces = []

        for piece in dragged {
            piece.animateDrop()
        }
        saveCurrentSession()
    }

    /// 分隔条拖动结束后一次性持久化比例（拖动期间每帧写 UserDefaults 会触发无谓的界面重渲染）
    private func persistSplitRatio() {
        GameSettings.shared.splitRatio = Double(currentSplitRatio)
        saveCurrentSession()
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        cancelActiveDragging()
    }
}
