#!/usr/bin/env bash
# Generates the Android project and applies CK Enterprises settings.
# Run from the project root. Needs Flutter installed.
set -e
flutter create --platforms=android --org com.ckenterprises --project-name machinery_running_app .
MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i 's/android:label="[^"]*"/android:label="CK Machinery"/' "$MANIFEST"
# Release builds need INTERNET permission (flutter create only adds it for debug)
grep -q 'android.permission.INTERNET' "$MANIFEST" || \
  sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' "$MANIFEST"
flutter pub get
dart run flutter_launcher_icons
