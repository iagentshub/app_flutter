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

  // Ciclo de vida UIScene: el registro de plugins y el canal de icono ya no
  // pueden montarse en application(_:didFinishLaunchingWithOptions:) porque
  // window?.rootViewController todavía no existe ahí — este delegado se
  // llama justo cuando el motor Flutter implícito queda listo.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "com.iagentshub.app/app_icon",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard UIApplication.shared.supportsAlternateIcons else {
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
      UIApplication.shared.setAlternateIconName(iconName) { error in
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
}
