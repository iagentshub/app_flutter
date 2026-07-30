import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.iagentshub.app/app_icon",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "setIcon" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard application.supportsAlternateIcons else {
          result(
            FlutterError(
              code: "UNSUPPORTED",
              message: "Este dispositivo no admite iconos alternativos.",
              details: nil
            )
          )
          return
        }

        let arguments = call.arguments as? [String: Any]
        let requestedName = arguments?["name"] as? String
        let alternateIconNames = [
          "agentCoordinator": "AppIconAgentCoordinator",
          "coordinatorWhiteOnRed": "AppIconCoordinatorWhiteOnRed",
          "coordinatorRedOnBlack": "AppIconCoordinatorRedOnBlack",
          "coordinatorBlackOnRed": "AppIconCoordinatorBlackOnRed",
          "coordinatorRedOnWhite": "AppIconCoordinatorRedOnWhite",
          "iaInterRedOnBlack": "AppIconIaInterRedOnBlack",
          "iaInterBlackOnRed": "AppIconIaInterBlackOnRed",
          "iaInterRedOnWhite": "AppIconIaInterRedOnWhite",
        ]
        let iconName = requestedName.flatMap { alternateIconNames[$0] }
        if requestedName != nil && iconName == nil {
          result(
            FlutterError(
              code: "UNKNOWN_ICON",
              message: "Icono desconocido: \(requestedName!)",
              details: nil
            )
          )
          return
        }
        application.setAlternateIconName(iconName) { error in
          if let error {
            result(
              FlutterError(
                code: "ICON_CHANGE_FAILED",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            result(nil)
          }
        }
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
