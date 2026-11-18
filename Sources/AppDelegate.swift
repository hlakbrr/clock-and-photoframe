import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    static weak var mainVC: MainViewController?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Settings.ensureDefaults()
        UIApplication.shared.isIdleTimerDisabled = true  // 桌面钟/相框：前台期间屏幕常亮

        let window = UIWindow(frame: UIScreen.main.bounds)
        let main = MainViewController()
        window.rootViewController = main
        window.backgroundColor = .black
        window.makeKeyAndVisible()
        self.window = window
        Self.mainVC = main
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Self.handleDeepLink(url)
        return true
    }

    /// uiopen immichframe://open 或 clockframe://open —— 保留原看门狗兼容
    static func handleDeepLink(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "immichframe" || scheme == "clockframe" else { return }
        mainVC?.handleDeepLink()
    }
}
