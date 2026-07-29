#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/cineva_mobile"
flutter pub get
flutter build apk --release
flutter build appbundle --release

echo "Build Android terminé : APK + AAB générés pour cineva_mobile."