#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APPS_DIR="$ROOT_DIR/apps"
ORG="com.cineva"

require_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "Erreur : Flutter SDK introuvable dans le PATH." >&2
    echo "Installez Flutter puis relancez ce script." >&2
    exit 1
  fi
}

copy_generated_targets() {
  local source_dir="$1"
  local target_dir="$2"

  for item in .metadata android ios macos windows web linux test; do
    if [ -e "$source_dir/$item" ]; then
      rm -rf "$target_dir/$item"
      cp -R "$source_dir/$item" "$target_dir/$item"
    fi
  done
}

bootstrap_app() {
  local app_name="$1"
  local platforms="$2"
  local target_dir="$APPS_DIR/$app_name"
  local temp_root
  local temp_app_dir

  temp_root="$(mktemp -d)"
  temp_app_dir="$temp_root/$app_name"

  echo "→ Génération des cibles natives pour $app_name [$platforms]"
  flutter create "$temp_app_dir" \
    --platforms="$platforms" \
    --project-name="$app_name" \
    --org "$ORG" \
    >/dev/null

  copy_generated_targets "$temp_app_dir" "$target_dir"
  rm -rf "$temp_root"

  echo "✓ $app_name prêt"
}

require_flutter

bootstrap_app cineva_mobile android,ios
bootstrap_app cineva_admin windows,macos,web
bootstrap_app cineva_windows windows
bootstrap_app cineva_macos macos
bootstrap_app cineva_android_tv android
bootstrap_app cineva_web web

echo

echo "Bootstrap des cibles natives terminé."
echo "Étapes recommandées ensuite :"
echo "  1) dart pub global activate melos"
echo "  2) melos bootstrap"
echo "  3) melos run pub:get"
echo "  4) melos run analyze"
