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


    let documentsChannel = FlutterMethodChannel(
      name: "com.hungphat.mcpfield/documents",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )

    documentsChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "shareTextDocument" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let rawName = arguments["fileName"] as? String,
        let mimeType = arguments["mimeType"] as? String,
        let content = arguments["content"] as? String
      else {
        result(
          FlutterError(
            code: "DOCUMENT_INVALID",
            message: "Thông tin file cần chia sẻ chưa hợp lệ.",
            details: nil
          )
        )
        return
      }
      let renderPdf = arguments["renderPdf"] as? Bool ?? false
      self?.shareTextDocument(
        rawName: rawName,
        mimeType: mimeType,
        content: content,
        renderPdf: renderPdf,
        result: result
      )
    }

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


  private func shareTextDocument(
    rawName: String,
    mimeType: String,
    content: String,
    renderPdf: Bool,
    result: @escaping FlutterResult
  ) {
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._-")
    let fileName = rawName.unicodeScalars
      .map { allowed.contains($0) ? String($0) : "-" }
      .joined()
      .prefix(160)
    guard !fileName.isEmpty, !mimeType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      result(
        FlutterError(
          code: "DOCUMENT_INVALID",
          message: "Thông tin file cần chia sẻ chưa hợp lệ.",
          details: nil
        )
      )
      return
    }

    do {
      let directory = FileManager.default.temporaryDirectory.appendingPathComponent(
        "mcp-exports",
        isDirectory: true
      )
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let target = directory.appendingPathComponent(String(fileName))
      if renderPdf {
        try writeTextPdf(content, to: target)
      } else {
        try content.write(to: target, atomically: true, encoding: .utf8)
      }

      guard let presenter = window?.rootViewController else {
        throw NSError(domain: "MCPDocuments", code: 1)
      }
      let controller = UIActivityViewController(
        activityItems: [target],
        applicationActivities: nil
      )
      if let popover = controller.popoverPresentationController {
        popover.sourceView = presenter.view
        popover.sourceRect = CGRect(
          x: presenter.view.bounds.midX,
          y: presenter.view.bounds.midY,
          width: 1,
          height: 1
        )
      }
      presenter.present(controller, animated: true) {
        result(nil)
      }
    } catch {
      result(
        FlutterError(
          code: "DOCUMENT_SHARE_FAILED",
          message: "Không mở được chức năng chia sẻ file.",
          details: nil
        )
      )
    }
  }

  private func writeTextPdf(_ content: String, to target: URL) throws {
    let format = UIGraphicsPDFRendererFormat()
    let pageBounds = CGRect(x: 0, y: 0, width: 595, height: 842)
    let renderer = UIGraphicsPDFRenderer(bounds: pageBounds, format: format)
    try renderer.writePDF(to: target) { context in
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineBreakMode = .byWordWrapping
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.systemFont(ofSize: 11),
        .paragraphStyle: paragraph
      ]
      let lines = content
        .replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: "\n")
      var y: CGFloat = 42
      context.beginPage()
      for raw in lines {
        let chunks = raw.isEmpty ? [""] : stride(from: 0, to: raw.count, by: 88).map { start in
          let startIndex = raw.index(raw.startIndex, offsetBy: start)
          let endOffset = min(start + 88, raw.count)
          let endIndex = raw.index(raw.startIndex, offsetBy: endOffset)
          return String(raw[startIndex..<endIndex])
        }
        for line in chunks {
          if y > 792 {
            context.beginPage()
            y = 42
          }
          NSString(string: line).draw(
            in: CGRect(x: 36, y: y, width: 523, height: 18),
            withAttributes: attributes
          )
          y += 16
        }
      }
    }
  }
}
