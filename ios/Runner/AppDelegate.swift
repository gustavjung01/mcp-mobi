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

    let navigationChannel = FlutterMethodChannel(
      name: "com.hungphat.mcpfield/navigation",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    navigationChannel.setMethodCallHandler { call, result in
      guard call.method == "openMap" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let rawUrl = arguments["url"] as? String,
        let url = URL(string: rawUrl),
        url.scheme?.lowercased() == "https"
      else {
        result(
          FlutterError(
            code: "MAP_URL_INVALID",
            message: "Vị trí bản đồ chưa hợp lệ.",
            details: nil
          )
        )
        return
      }

      UIApplication.shared.open(url, options: [:]) { opened in
        if opened {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "MAP_OPEN_FAILED",
              message: "Không mở được bản đồ trên thiết bị này.",
              details: nil
            )
          )
        }
      }
    }

    let storageChannel = FlutterMethodChannel(
      name: "com.hungphat.mcpfield/storage",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "pendingMediaDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }

      do {
        let base = try FileManager.default.url(
          for: .applicationSupportDirectory,
          in: .userDomainMask,
          appropriateFor: nil,
          create: true
        )
        let directory = base.appendingPathComponent(
          "mcp-pending-media",
          isDirectory: true
        )
        try FileManager.default.createDirectory(
          at: directory,
          withIntermediateDirectories: true
        )
        result(directory.path)
      } catch {
        result(
          FlutterError(
            code: "MEDIA_STORAGE_UNAVAILABLE",
            message: "Không chuẩn bị được nơi lưu ảnh chờ gửi.",
            details: nil
          )
        )
      }
    }
  }
}
