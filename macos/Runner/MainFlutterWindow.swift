import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.contentMinSize = NSSize(width: 720, height: 600)
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let appIconChannel = FlutterMethodChannel(
      name: "com.iagentshub.app/app_icon",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    appIconChannel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let arguments = call.arguments as? [String: Any],
        let assetPath = arguments["assetPath"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ASSET",
            message: "Falta la ruta del icono.",
            details: nil
          )
        )
        return
      }

      let assetKey = FlutterDartProject.lookupKey(forAsset: assetPath)
      guard
        let bundledPath = Bundle.main.path(forResource: assetKey, ofType: nil),
        let image = NSImage(contentsOfFile: bundledPath)
      else {
        result(
          FlutterError(
            code: "ICON_NOT_FOUND",
            message: "No se encontró el recurso \(assetPath).",
            details: nil
          )
        )
        return
      }

      NSApplication.shared.applicationIconImage = image
      result(nil)
    }

    super.awakeFromNib()
  }
}
