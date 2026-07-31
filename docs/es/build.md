<div align="center">
  <a href="index.md">← Índice</a> &nbsp;·&nbsp;
  <a href="../en/build.md">🇬🇧 Read in English</a>
</div>

<br>

# Compilación

---

## Requisitos

Flutter SDK estable, con Dart 3.10 o superior. Cada plataforma de destino añade lo suyo: Android Studio y un JDK para Android, Xcode para iOS y macOS, Visual Studio con carga de trabajo de C++ para Windows.

Para comprobar qué falta:

```bash
flutter doctor
```

---

## Puesta en marcha

```bash
flutter pub get
flutter run
```

`flutter run` usa el dispositivo o emulador conectado. Con varios disponibles, `flutter devices` los lista y `flutter run -d <id>` elige uno.

---

## Verificación

```bash
flutter analyze
flutter test
```

Ambos deben pasar antes de dar un cambio por terminado. `flutter analyze` arrastra hoy una lista conocida de avisos de estilo, ninguno de ellos error; lo que importa es que tu cambio no la alargue.

---

## Compilar para cada plataforma

```bash
flutter build apk            # Android, instalable directo
flutter build appbundle      # Android, para Google Play
flutter build ipa            # iOS
flutter build web            # web
flutter build windows        # Windows
flutter build macos          # macOS
flutter build linux          # Linux
```

Las compilaciones de iOS y macOS solo funcionan sobre macOS con Xcode; la de Windows, solo sobre Windows.

---

## Icono de la aplicación

El icono se genera para todas las plataformas a partir de una sola imagen:

```bash
flutter pub run flutter_launcher_icons
```

Basta con reemplazar la imagen de origen y volver a ejecutarlo; no hay que tocar los iconos plataforma por plataforma.

---

## Traducciones

Los textos viven en ficheros por idioma y por sección, empaquetados con la app. Añadir una sección nueva exige crearla **en los dos idiomas** y declararla en la configuración del proyecto; si falta una de las dos, esa parte de la interfaz aparecerá vacía en el idioma que falte.
