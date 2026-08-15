import Flutter
import UIKit

private final class KnowledgeDirectoryPicker: NSObject, UIDocumentPickerDelegate {
  private var completion: ((Result<String?, Error>) -> Void)?

  func present(
    from viewController: UIViewController,
    completion: @escaping (Result<String?, Error>) -> Void
  ) {
    self.completion = completion
    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.folder"],
      in: .open
    )
    picker.delegate = self
    picker.allowsMultipleSelection = false
    viewController.present(picker, animated: true)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion?(.success(nil))
    completion = nil
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    guard let source = urls.first else {
      completion?(.success(nil))
      completion = nil
      return
    }
    let callback = completion
    completion = nil
    DispatchQueue.global(qos: .userInitiated).async {
      let hasAccess = source.startAccessingSecurityScopedResource()
      defer {
        if hasAccess { source.stopAccessingSecurityScopedResource() }
      }
      do {
        let root = FileManager.default.temporaryDirectory
          .appendingPathComponent("knowledge-directory-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
          at: root,
          withIntermediateDirectories: true
        )
        let destination = root.appendingPathComponent(
          source.lastPathComponent,
          isDirectory: true
        )
        try FileManager.default.copyItem(at: source, to: destination)
        DispatchQueue.main.async { callback?(.success(destination.path)) }
      } catch {
        DispatchQueue.main.async { callback?(.failure(error)) }
      }
    }
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let knowledgeDirectoryPicker = KnowledgeDirectoryPicker()

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
        "iaInterWhiteOnRed": "AppIconIaInterWhiteOnRed",
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

    let directoryChannel = FlutterMethodChannel(
      name: "com.iagentshub.app/knowledge_directory",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    directoryChannel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "pickDirectory" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let self, let viewController = self.activeViewController() else {
        result(
          FlutterError(
            code: "NO_VIEW_CONTROLLER",
            message: "No se pudo abrir el selector de directorios.",
            details: nil
          )
        )
        return
      }
      self.knowledgeDirectoryPicker.present(from: viewController) { response in
        switch response {
        case .success(let path):
          result(path)
        case .failure(let error):
          result(
            FlutterError(
              code: "DIRECTORY_READ_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }

  private func activeViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first(where: \.isKeyWindow)?
      .rootViewController
    var current = root
    while let presented = current?.presentedViewController {
      current = presented
    }
    return current
  }
}
