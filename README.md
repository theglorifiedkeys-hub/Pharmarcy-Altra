# Altra Pharmacy

A Tanzania-focused pharmacy management prototype. Inspired by [DetechX](https://github.com/theglorifiedkeys-hub/DetechX)'s rounded surfaces, Inter typography and animated transitions, adapted to a forest-green and mint desktop/mobile workspace.

```sh
npm ci
npm run dev
npm run build
```

The demo supports medicine inventory and expiry dates, client visit notes, supplier contacts, and reminders that can be marked complete. Dates use the Dar es Salaam timezone. Sample records are fictional. Changes are saved in this browser only; there is no authentication, backup, shared database, or outbound messaging. Do not use this prototype for real patient or pharmacy records.

## Native Android demo APK

With a JDK, `zip`, Android SDK Platform 34 and Build Tools 34.0.0 installed, set `ANDROID_HOME` and run `bash android/build.sh`. The signed demo is written to `artifacts/Altra-Pharmacy-native.apk`. It uses native Android views and does not package the web app or require Internet permission.

- Requires a device screen lock; use Android's PIN, pattern or password, or a supported strong biometric on Android 11 and later. This is a single-device workspace, not separate staff accounts. The app locks on restart or after more than two minutes in the background. Records and photos use Android app-private storage, not a separate encrypted database.
- Four fictional medicine records are preloaded. Import UTF-8 medicine CSV using [the sample template](android/medicines-sample.csv). The header is `name,form,supplier,stock,expiry`; dates use `YYYY-MM-DD`. Imports append up to 500 validated records after confirmation. Existing records are not overwritten.
- To attach a picture, open an existing medicine and choose a photo using Android's system picker. The app keeps a resized private copy. It does not request broad storage access or open the camera directly.
- Enable notifications in Reminders. Future reminders are scheduled inexactly for 9 a.m. Dar es Salaam time; Android may delay delivery. Notifications do not show record details.
- Use sample data only. The native app does not migrate browser records, sync, or back up data. Installing the APK requires Android 6+; the demo signature is not for Play Store distribution.
