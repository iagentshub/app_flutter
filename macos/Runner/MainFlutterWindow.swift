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

      // En macOS `lookupKey` devuelve la ruta **desde la raíz de Bundle.main**
      // —«Contents/Frameworks/App.framework/Resources/flutter_assets/assets/…»—,
      // no una clave relativa a Resources. De ahí que fallara de las dos formas
      // en que se puede fallar aquí: `path(forResource:)` busca dentro de
      // Contents/Resources, donde los assets de Flutter no están, y componerla
      // sobre `resourceURL` duplicaba el tramo que la clave ya trae. Los nueve
      // iconos fallaban siempre y el error moría en un debugPrint: el icono no
      // cambiaba y la pantalla no decía nada.
      //
      // Detrás quedan las otras dos formas por si esa clave cambia de
      // convención, que es justo lo que no avisa.
      let assetKey = FlutterDartProject.lookupKey(forAsset: assetPath)
      let appFramework = Bundle.main.privateFrameworksURL?
        .appendingPathComponent("App.framework")
        .appendingPathComponent("Resources")
      let candidatos = [
        Bundle.main.bundleURL.appendingPathComponent(assetKey),
        appFramework?.appendingPathComponent(assetKey),
        Bundle.main.resourceURL?.appendingPathComponent(assetKey),
      ].compactMap { $0 }

      guard
        let url = candidatos.first(where: {
          FileManager.default.fileExists(atPath: $0.path)
        }),
        let image = NSImage(contentsOf: url)
      else {
        // El mensaje lleva las rutas probadas: sin ellas, «no se encontró» no
        // distingue entre el bundle equivocado, la clave equivocada y un PNG
        // que NSImage no sabe leer. Fue lo que identificó este fallo.
        result(
          FlutterError(
            code: "ICON_NOT_FOUND",
            message: "No se encontró el recurso \(assetPath). Probado: "
              + candidatos.map { $0.path }.joined(separator: ", "),
            details: nil
          )
        )
        return
      }

      // Asignar la imagen no repinta el Dock por su cuenta: el tile se queda
      // con el icono del bundle y el cambio pasa desapercibido, sin error, que
      // es exactamente el síntoma que se veía. `display()` lo fuerza.
      NSApplication.shared.applicationIconImage = image
      NSApplication.shared.dockTile.display()

      // Se devuelve si la asignación quedó puesta. En macOS esto solo afecta
      // al Dock de la instancia en ejecución —el icono del .app no se puede
      // cambiar sin reescribir el bundle y romper su firma—, así que cuando el
      // usuario dice «no cambia» hace falta poder distinguir «no se asignó» de
      // «se asignó y el Dock es lo que no lo enseña».
      result(NSApplication.shared.applicationIconImage != nil)
    }

    super.awakeFromNib()
  }
}
