# Altra Pharmacy

A Tanzania-focused pharmacy management prototype. Inspired by [DetechX](https://github.com/theglorifiedkeys-hub/DetechX)'s rounded surfaces, Inter typography and animated transitions, adapted to a forest-green and mint desktop/mobile workspace.

```sh
npm ci
npm run dev
npm run build
```

The demo supports medicine inventory and expiry dates, client visit notes, supplier contacts, and reminders that can be marked complete. Dates use the Dar es Salaam timezone. Sample records are fictional. Changes are saved in this browser only; there is no authentication, backup, shared database, or outbound messaging. Do not use this prototype for real patient or pharmacy records.

## Android demo APK

With a JDK, `zip`, Android SDK Platform 34 and Build Tools 34.0.0 installed, set `ANDROID_HOME`, run `npm ci`, then run `bash android/build.sh`. The signed demo is written to `artifacts/Altra-Pharmacy-demo.apk`. It bundles the web app for offline use and stores data on that device only. The demo signature is not for Play Store distribution.
