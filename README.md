# Altra Pharmacy · Flutter

A fresh Flutter/Dart implementation based on [DetechX](https://github.com/theglorifiedkeys-hub/DetechX) at `a886c06`. It carries over that project's `ThemeData`, glass surfaces, spring/tap and entrance animations, plus the bundled Inter and Lucide fonts. The home-service flows have been replaced by Tanzania-focused medicine inventory, returning clients, suppliers and reminders in a mint/forest palette.

## Download the APK

Every green build republishes a public, installable build — no GitHub sign-in needed:

- **Release APK:** https://github.com/theglorifiedkeys-hub/Pharmarcy-Altra/releases/download/flutter-latest/app-release.apk
- **Debug APK:** https://github.com/theglorifiedkeys-hub/Pharmarcy-Altra/releases/download/flutter-latest/app-debug.apk

Open the link on the phone, download, then allow "Install unknown apps" for the browser or Files app. The demo build is signed with a local debug key; Play Store distribution needs a proper keystore.

## Android demo

Install Flutter 3.32.8, JDK 17 and the Android SDK, then run:

```sh
flutter pub get
bash tool/prepare_android.sh
flutter run
# Or create an installable demo:
flutter build apk --debug
```

The runner script generates the standard Flutter Android host and configures device authentication and Android local notifications. The APK is `build/app/outputs/flutter-apk/app-debug.apk`. GitHub Actions also builds and uploads this APK after analysis and tests pass. The previous Java package has a different application ID and can remain installed; old records are not migrated.

- **Device unlock:** Android system PIN/pattern/password or supported biometric. No online account or separate staff identities. The app locks after more than two minutes away or on restart.
- **Storage:** Records and bounded photo thumbnails stay with the app; no cloud sync, backup, or standalone encrypted database. Use fictional records only.
- **Pictures:** Pick a photo or hand off to the system camera from the medicine editor. No broad storage permission is requested.
- **CSV:** Import the [sample CSV](samples/medicines.csv). Imports validate the full file before confirmation and append records. Use headers `name,form,supplier,stock,expiry` and dates `YYYY-MM-DD`.
- **Reminders:** Enable Android alerts in Reminders. Future alerts are scheduled inexactly around 9 a.m. Dar es Salaam time, without client or medicine names on the lock screen.

## Browser demo and checks

```sh
flutter run -d chrome
flutter analyze
flutter test
```

The browser demo uses browser-local storage and skips Android's device unlock, camera handoff and local notifications.
