#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../apps/cineva_windows"
flutter pub get
flutter build windows --release

echo "Build Windows terminé : exécutable généré pour cineva_windows."