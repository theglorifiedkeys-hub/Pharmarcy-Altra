#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ -e android ]]; then
  echo 'Android runner already exists. Remove it only if you want to regenerate it.' >&2
  exit 1
fi
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
flutter create --no-pub --platforms=android --org tz.altra --project-name altra_pharmacy "$workspace/runner"
python3 - "$workspace/runner/android" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
manifest = root / 'app/src/main/AndroidManifest.xml'
s = manifest.read_text().replace('<application', '''<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.USE_BIOMETRIC" />
    <application android:allowBackup="false"''', 1).replace('android:label="altra_pharmacy"', 'android:label="Altra Pharmacy"')
s = s.replace('</application>', '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED" />
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
            </intent-filter>
        </receiver>
    </application>''')
manifest.write_text(s)
activity, = root.glob('app/src/main/kotlin/**/MainActivity.kt')
activity.write_text('''package tz.altra.altra_pharmacy

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }
}
''')
for style in root.glob('app/src/main/res/values*/styles.xml'):
    style.write_text(style.read_text().replace('@android:style/Theme.Light.NoTitleBar', 'Theme.AppCompat.Light.NoActionBar').replace('@android:style/Theme.Black.NoTitleBar', 'Theme.AppCompat.DayNight.NoActionBar'))
icon = root / 'app/src/main/res/drawable/altra_notification.xml'
icon.write_text('''<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="24dp" android:height="24dp" android:viewportWidth="24" android:viewportHeight="24">
    <path android:fillColor="#FFFFFFFF" android:pathData="M9,2h6v7h7v6h-7v7h-6v-7h-7v-6h7z" />
</vector>
''')
gradle = root / 'app/build.gradle.kts'
s = gradle.read_text().replace('compileSdk = flutter.compileSdkVersion', 'compileSdk = maxOf(35, flutter.compileSdkVersion)').replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion)').replace('compileOptions {', 'compileOptions {\n        isCoreLibraryDesugaringEnabled = true')
gradle.write_text(s + '''

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.appcompat:appcompat:1.7.0")
}
''')
PY
cp -R "$workspace/runner/android" android
