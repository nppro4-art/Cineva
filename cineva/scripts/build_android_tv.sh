#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/cineva_android_tv"
flutter pub get
flutter build apk --release

echo "Build Android TV terminé : APK généré pour cineva_android_tv."