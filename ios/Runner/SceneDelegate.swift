import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {

  /// 冷启动深链：App 未运行时通过 URL 打开。
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let urlContext = connectionOptions.urlContexts.first {
      notifyDeepLink(urlContext.url)
    }
  }

  /// 运行中深链：clockandphotoframe://open / clockframe://open
  override func scene(
    _ scene: UIScene,
    openURLContexts URLContexts: Set<UIOpenURLContext>
  ) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      notifyDeepLink(context.url)
    }
  }

  private func notifyDeepLink(_ url: URL) {
    DispatchQueue.main.async {
      guard let controller = self.window?.rootViewController as? FlutterViewController else {
        return
      }
      let channel = FlutterMethodChannel(
        name: "kiosk/native",
        binaryMessenger: controller.binaryMessenger
      )
      channel.invokeMethod("deepLink", arguments: url.absoluteString)
    }
  }
}
