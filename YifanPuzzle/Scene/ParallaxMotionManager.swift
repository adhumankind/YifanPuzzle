import Foundation
import CoreMotion
import UIKit

/// 陀螺仪与加速度计轻量视差 3D 控制器
public final class ParallaxMotionManager {
    public static let shared = ParallaxMotionManager()

    private let motionManager = CMMotionManager()
    public var onMotionUpdate: ((CGFloat, CGFloat) -> Void)?

    private init() {}

    public func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // 横屏模式下，pitch 与 roll 的重映射
            let roll = CGFloat(motion.attitude.roll)
            let pitch = CGFloat(motion.attitude.pitch)
            self?.onMotionUpdate?(roll, pitch)
        }
    }

    public func stop() {
        motionManager.stopDeviceMotionUpdates()
    }
}
