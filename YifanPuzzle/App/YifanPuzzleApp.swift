import SwiftUI

@main
struct YifanPuzzleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .preferredColorScheme(.dark)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        // 严格锁定横屏游玩体验
        return [.landscapeLeft, .landscapeRight]
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // 进入后台时 UserDefaults 由系统自动落盘（synchronize 已废弃）；
        // 对局进度的持久化由场景在每次吸附/收纳事件时即时完成。
    }
}
