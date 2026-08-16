<div align="center">
  <a href="index.md">← Index</a> &nbsp;·&nbsp;
  <a href="../es/build.md">🇪🇸 Ver en Español</a>
</div>

<br>

# Building

---

## Requirements

Flutter SDK, stable channel, with Dart 3.10 or newer. Each target platform adds its own: Android Studio and a JDK for Android, Xcode for iOS and macOS, Visual Studio with the C++ workload for Windows.

To see what is missing:

```bash
flutter doctor
```

---

## Getting started

```bash
flutter pub get
flutter run
```

`flutter run` uses the connected device or emulator. With several available, `flutter devices` lists them and `flutter run -d <id>` picks one.

---

## Verification

```bash
flutter analyze
flutter test
```

Both must pass before calling a change done. `flutter analyze` currently carries a known list of style notices, none of them errors; what matters is that your change does not make it longer.

---

## Building for each platform

```bash
flutter build apk            # Android, directly installable
flutter build appbundle      # Android, for Google Play
flutter build ipa            # iOS
flutter build web            # web
flutter build windows        # Windows
flutter build macos          # macOS
flutter build linux          # Linux
```

The iOS and macOS builds only work on macOS with Xcode; the Windows one, only on Windows.

---

## Web size budget

On the web the bundle size is waiting time before the first screen, so there is a limit checked on every change:

```bash
flutter build web --release
tool/check_web_bundle_size.sh
```

The script prints the size of the main bundle and of the parts downloaded separately, and fails if the main one goes over budget or if the build produced no parts at all. It also runs in continuous integration, right after the web build.

A large new module is added **deferred**, as administration, orchestrations and the checkout already are; raising the limit instead of deferring is a deliberate decision that has to be written into the script itself.

---

## Application icon

The icon is generated for every platform from a single image:

```bash
flutter pub run flutter_launcher_icons
```

Replacing the source image and running it again is enough; there is no need to touch the icons platform by platform.

---

## Translations

Texts live in files per language and per section, bundled with the app. Adding a new section requires creating it **in both languages** and declaring it in the project configuration; if one of the two is missing, that part of the interface will show up empty in the missing language.
