#!/usr/bin/env bash
# Récupère le toolchain Flutter (SDK 3.24.5 + pub-cache complet + pubspec.lock)
# depuis la branche `toolchain-artifacts` du repo — pont GitHub Actions mis en
# place car le sandbox n'a accès qu'à GitHub (storage.googleapis.com et pub.dev
# sont bloqués).
#
# Pré-requis : token GitHub valide (GH_TOKEN).
# Usage : bash cineva/scripts/fetch_toolchain.sh
set -e

REPO=$(cd "$(dirname "$0")/../.." && pwd)
DEST=/tmp

cd "$REPO"
echo "==> fetch de la branche toolchain-artifacts..."
git fetch origin toolchain-artifacts

echo "==> extraction du manifeste + locks..."
rm -rf "$DEST/tcstage"; mkdir -p "$DEST/tcstage"
git archive FETCH_HEAD | tar -x -C "$DEST/tcstage"

cd "$DEST/tcstage"
echo "==> vérification sha256 des parts..."
sed 's|  parts/|  |' SHA256SUMS | sha256sum -c - | tail -2

echo "==> extraction du SDK Flutter (opt/flutter, ~4 min)..."
mkdir -p "$DEST/opt"
cat part-* | tar -xJ -C "$DEST" opt/flutter

echo "==> extraction du pub-cache (~1 min)..."
mkdir -p "$DEST/pubcache"
cat part-* | tar -xJ -C "$DEST/pubcache" .pub-cache

echo "==> restauration des pubspec.lock figés par le runner..."
( cd "$DEST/tcstage/locks" && find . -name pubspec.lock | while read -r l; do
    cp "$l" "$REPO/${l#./}"
  done )

echo "==> sanitarisation du cache (bug advisories pub 3.5.4)..."
find "$DEST/pubcache/.pub-cache/hosted" -path '*/.cache/*-advisories.json' -delete 2>/dev/null || true
python3 -c "
import glob, json, os
n = 0
for f in glob.glob('$DEST/pubcache/.pub-cache/hosted/*/.cache/*-versions.json'):
    try:
        d = json.load(open(f))
        if 'advisoriesUpdated' in d:
            d.pop('advisoriesUpdated', None)
            json.dump(d, open(f, 'w'))
            n += 1
    except Exception:
        pass
print('stripped advisoriesUpdated from %d listings' % n)
"

echo "==> pub get --offline sur les 14 packages..."
export FLUTTER_ROOT="$DEST/opt/flutter"
export PUB_CACHE="$DEST/pubcache/.pub-cache"
export PATH="$FLUTTER_ROOT/bin:$PATH"
git config --global --add safe.directory "$FLUTTER_ROOT" || true
flutter config --no-analytics >/dev/null 2>&1 || true
fail=0
for f in "$REPO"/cineva/apps/*/pubspec.yaml "$REPO"/cineva/packages/*/pubspec.yaml; do
  d=$(dirname "$f")
  echo "--- $d"
  (cd "$d" && flutter pub get --offline >/dev/null 2>/tmp/pg.err) || {
    echo "PUBGET FAIL: $d"; head -5 /tmp/pg.err; fail=1;
  }
done
[ $fail -eq 0 ] && echo "pub get 14/14 OK"

flutter --version

cat <<EOF

Toolchain prêt. Environnement :
  export FLUTTER_ROOT=$FLUTTER_ROOT
  export PUB_CACHE=$PUB_CACHE
  export PATH=\$FLUTTER_ROOT/bin:\$PATH

Analyse (flutter analyze crashe silencieusement dans ce sandbox, utiliser):
  \$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart analyze
Tests du package audio_engine (VM Dart):
  cd cineva/packages/audio_engine && dart test
EOF
