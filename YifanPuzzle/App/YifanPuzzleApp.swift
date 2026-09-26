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
        // 当用户接听电话或切至桌面后台时，确保触发存档持久化同步
        UserDefaults.standard.synchronize()
    }
}
