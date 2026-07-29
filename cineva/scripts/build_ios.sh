#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/cineva_mobile"
flutter pub get
flutter build ios --release

echo "Build iOS terminé : projet Xcode prêt à compiler/signature finale requise."