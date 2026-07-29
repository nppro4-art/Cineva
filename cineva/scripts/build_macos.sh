#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/cineva_macos"
flutter pub get
flutter build macos --release

echo "Build macOS terminé : app générée pour cineva_macos."