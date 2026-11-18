import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.pluginRegistry.registrar(forPlugin: "TiqloClock")!.messenger()
    let channel = FlutterMethodChannel(name: "tiqlo/clock", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "elapsedRealtime" {
        result(Int(ProcessInfo.processInfo.systemUptime * 1000.0))
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // Clock & PhotoFrame：返回桌面（suspend）通道
    let kioskChannel = FlutterMethodChannel(name: "kiosk/native", binaryMessenger: messenger)
    kioskChannel.setMethodCallHandler { call, result in
      if call.method == "suspend" {
        // 私有 API：挂起 App 回到桌面（TrollStore 签名不受审核限制）。
        DispatchQueue.main.async {
          UIApplication.shared.perform(#selector(URLSessionTask.suspend))
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
