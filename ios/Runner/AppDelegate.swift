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

    let updateChannel = FlutterMethodChannel(
      name: "com.hungphat.mcpfield/app_update",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    updateChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "currentVersion":
        let version = Bundle.main.object(
          forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String
        result(version ?? "")

      case "supportsDirectInstall":
        result(false)

      case "canInstallPackages":
        result(false)

      case "openInstallPermissionSettings", "downloadAndInstall":
        result(
          FlutterError(
            code: "UPDATE_NOT_SUPPORTED",
            message: "Bản iPhone/iPad được cập nhật qua kênh phát hành iOS của Công Ty.",
            details: nil
          )
        )

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
