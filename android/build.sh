#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
TOOLS=${ANDROID_BUILD_TOOLS:-$SDK/build-tools/34.0.0}
JAR=${ANDROID_JAR:-$SDK/platforms/android-34/android.jar}
AAPT2=${AAPT2:-$TOOLS/aapt2}
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/classes" "$WORK/dex" artifacts
"$AAPT2" link -I "$JAR" --manifest android/AndroidManifest.xml -o "$WORK/unsigned.apk"
if [[ -n ${ECJ_JAR:-} ]]; then
  java -jar "$ECJ_JAR" -8 -proc:none -classpath "$JAR" -d "$WORK/classes" android/*.java
else
  javac -source 8 -target 8 -classpath "$JAR" -d "$WORK/classes" android/*.java
fi
if [[ -n ${D8_JAR:-} ]]; then D8=(java -cp "$D8_JAR" com.android.tools.r8.D8); else D8=("$TOOLS/d8"); fi
mapfile -t CLASSES < <(find "$WORK/classes" -name '*.class')
"${D8[@]}" --lib "$JAR" --min-api 23 --output "$WORK/dex" "${CLASSES[@]}"
(cd "$WORK/dex" && zip -q "$WORK/unsigned.apk" classes.dex)
if [[ -x "$TOOLS/zipalign" ]]; then
  "$TOOLS/zipalign" -f 4 "$WORK/unsigned.apk" "$WORK/aligned.apk"
else
  cp "$WORK/unsigned.apk" "$WORK/aligned.apk"
fi
KEY=${ALTRA_DEBUG_KEYSTORE:-$HOME/.android/altra-debug.keystore}
mkdir -p "$(dirname "$KEY")"
if [[ ! -f "$KEY" ]]; then
  keytool -genkeypair -keystore "$KEY" -storepass android -keypass android -alias altra-debug -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=Altra Demo'
fi
if [[ -n ${APKSIGNER_JAR:-} ]]; then SIGN=(java -jar "$APKSIGNER_JAR"); else SIGN=("$TOOLS/apksigner"); fi
"${SIGN[@]}" sign --ks "$KEY" --ks-pass pass:android --out artifacts/Altra-Pharmacy-native.apk "$WORK/aligned.apk"
"${SIGN[@]}" verify --verbose artifacts/Altra-Pharmacy-native.apk
