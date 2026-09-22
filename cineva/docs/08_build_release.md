# 08 — Compiler et publier les binaires Cineva

Cible : **Flutter 3.24.5 / Dart 3.5.4**, JDK 17, Android SDK (compileSdk 34+),
Visual Studio 2022 « Desktop development with C++ » pour Windows.

Trois binaires sont produits :

| Binaire | App source | Plateforme | Identifiant |
| --- | --- | --- | --- |
| `Cineva-User.apk` | `apps/cineva_mobile` (`CinevaUserApp`, `AppTarget.mobile`) | Android 7.0+ (minSdk 24) | `com.cineva.cineva_mobile` |
| `Cineva-Admin.apk` | `apps/cineva_admin` (`CinevaAdminEntry`) | Android 7.0+ (minSdk 24) | `com.cineva.cineva_admin` |
| `Cineva-User-Windows.zip` → `Cineva.exe` | `apps/cineva_windows` (`CinevaUserApp`, `AppTarget.windows`) | Windows x64 | — |

> Les châssis natifs (`android/`, `windows/`) ne sont **pas versionnés** : ils sont
> générés à la volée par `flutter create` (CI) ou par
> `scripts/bootstrap_flutter_targets.sh` (local). Seul le code Dart est suivi par Git.

---

## A. Voie recommandée — GitHub Actions (aucun outil local requis)

Le workflow `.github/workflows/build-artifacts.yml` enchaîne :

1. **`analyze`** — `flutter pub get` sur les 15 paquets, `flutter analyze`, puis les tests.
   Ce job échoue vite et publie `analyze-log` en artefact : c'est le premier réflexe en cas
   d'échec, bien avant les logs de compilation.
2. **`apk`** — génère les châssis Android, applique libellés (`Cineva`, `Cineva Admin`),
   minSdk 24, AGP 8.1.0 + Kotlin 1.8.22, Java 17, icônes via
   `scripts/apply_android_icon.py`, puis `flutter build apk --release` pour les deux apps.
3. **`windows`** — sur runner `windows-latest` : châssis Windows, `flutter build windows
   --release`, renommage en `Cineva.exe`, zip du dossier `Release`.
4. **`release`** — publie une GitHub Release `binaries-<n>` contenant les binaires
   disponibles + `SHA256SUMS.txt`.

### Lancer un build

```bash
# déclenchement automatique : tout push sur une branche arena/**
git push origin arena/01a0a0f7-cineva

# ou manuel, sur n'importe quelle branche
gh workflow run build-artifacts.yml --ref arena/01a0a0f7-cineva
gh workflow run build-artifacts.yml --ref main -f skip_tests=false

# suivre
gh run list --workflow build-artifacts.yml --limit 5
gh run watch <run-id>
gh run view <run-id> --log-failed
```

### Récupérer les binaires

```bash
# via la Release (lien affiché en fin de job « release »)
gh release download binaries-<n> --dir ./binaires

# ou via les artefacts du run (rétention 14 jours)
gh run download <run-id> --name android-apks --dir ./binaires
gh run download <run-id> --name windows-exe  --dir ./binaires

# logs de diagnostic
gh run download <run-id> --name analyze-log      --dir ./logs
gh run download <run-id> --name apk-build-logs   --dir ./logs
gh run download <run-id> --name windows-build-log --dir ./logs
```

Le workflow historique `build-android.yml` (push sur `main`, release `apk-<n>`) reste
actif et ne produit que les deux APK.

### Limite connue de la cible Windows

Le lecteur s'appuie sur `video_player`, qui ne fournit aucune implémentation Windows
(la résolution ne remonte que `video_player_android`, `video_player_avfoundation` et
`video_player_web`). Le `.exe` exécute donc toute l'interface — navigation, catalogue,
recherche, fiches, bibliothèque, réglages, profil — mais la lecture vidéo échoue.
Une cible desktop complète suppose un lecteur compatible Windows (`media_kit`, par
exemple) branché derrière la même interface de contrôleur. Les APK Android ne sont pas
concernés.

### Installation

- **Android** : copier l'APK sur l'appareil, autoriser « Sources inconnues », ouvrir le
  fichier. Ou `adb install -r Cineva-User.apk`. Les deux APK coexistent (identifiants
  distincts).
- **Windows** : dézipper `Cineva-User-Windows.zip` dans un dossier, lancer `Cineva.exe`.
  Le dossier doit rester intact (`data/`, `flutter_windows.dll` sont chargés relativement).
  SmartScreen peut avertir : l'exécutable n'est pas signé par un certificat de code.

---

## B. Voie locale

### 1. Bootstrap des châssis natifs (une fois)

```bash
cd cineva
./scripts/bootstrap_flutter_targets.sh   # nécessite flutter dans le PATH
dart pub global activate melos
melos bootstrap
```

### 2. Binaires Android (Linux, macOS ou Windows)

```bash
cd cineva/apps/cineva_mobile
flutter build apk --release \
  --dart-define=SUPABASE_URL="https://<projet>.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<clé anon>" \
  --dart-define=FIREBASE_ENABLED=false
# → build/app/outputs/flutter-apk/app-release.apk

cd ../cineva_admin
flutter build apk --release --dart-define=... # mêmes defines
```

APK allégés par ABI (plus petits, un par architecture) :

```bash
flutter build apk --release --split-per-abi
# → app-arm64-v8a-release.apk, app-armeabi-v7a-release.apk, app-x86_64-release.apk
```

### 3. Binaire Windows — **uniquement sur une machine Windows**

La compilation desktop Windows exige le toolchain MSVC : elle ne peut pas être
croisée depuis Linux ou macOS.

```powershell
cd cineva\apps\cineva_windows
flutter create --no-pub --platforms=windows --org com.cineva --project-name cineva_windows .
flutter build windows --release `
  --dart-define=SUPABASE_URL="https://<projet>.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="<clé anon>" `
  --dart-define=FIREBASE_ENABLED=false
# → build\windows\x64\runner\Release\  (cineva_windows.exe + data\ + DLL)
```

`scripts/build_windows.sh` existe pour macOS/Linux mais ne sert qu'à la documentation :
sur ces systèmes il échouera faute de MSVC.

### 4. Vérifications avant build

```bash
melos run analyze   # 0 erreur attendue
melos run test      # 36 fichiers de test
melos run format
```

---

## C. Configuration backend injectée à la compilation

| `--dart-define` | Lu par | Rôle |
| --- | --- | --- |
| `SUPABASE_URL` | `AppEnv` (`packages/shared/lib/src/app_env.dart`) | URL du projet Supabase |
| `SUPABASE_ANON_KEY` | `AppEnv` | clé publique anon / publishable (jamais `service_role`) |
| `FIREBASE_ENABLED` | `AppEnv` | notifications push FCM (`false` tant que FCM n'est pas configuré) |
| `TMDB_API_KEY` | `TmdbClient` (`packages/repositories`) | import par lien dans la console admin |
| `ENABLE_DEBUG_LOGS` | `AppEnv` | logs détaillés (à laisser à `false` en release) |

Sans ces defines, `AppEnv.supabaseUrl` est vide et l'application bascule en **mode démo**
(données fictives) : c'est explicitement refusé par les workflows CI.

Dans la CI, les valeurs proviennent des secrets `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`TMDB_API_KEY` ; à défaut, des valeurs projet codées dans le workflow (clé anon publique
par design Supabase).

---

## D. Signature release (Play Store)

Les APK produits par la CI sont signés avec la **clé de debug** : installables en direct,
refusés par le Play Store. Pour signer en release :

1. Créer un keystore (à conserver hors du dépôt) :

   ```bash
   keytool -genkey -v -keystore cineva-release.jks -keyalg RSA -keysize 2048 \
     -validity 10000 -alias cineva
   ```

2. Dans chaque app, créer `android/key.properties` (**non versionné**) :

   ```properties
   storePassword=<...>
   keyPassword=<...>
   keyAlias=cineva
   storeFile=/chemin/absolu/cineva-release.jks
   ```

3. Brancher la signature dans `android/app/build.gradle` :

   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release { signingConfig signingConfigs.release }
       }
   }
   ```

4. En CI, stocker le keystore en secret base64 (`ANDROID_KEYSTORE_BASE64`) et le
   matérialiser avant le build, plutôt que de le committer.

Pour le Play Store, préférer l'AAB : `flutter build appbundle --release`.

---

## E. Dépannage

| Symptôme | Cause / correction |
| --- | --- |
| `No Android project found` / `flutter build apk` refuse | châssis natif absent → `flutter create --platforms=android .` dans l'app, ou `scripts/bootstrap_flutter_targets.sh` |
| `Could not get unknown property 'flutter' for extension 'android'` | `app_links` ≥ 6.4 incompatible AGP Flutter 3.24.5 → le pin `app_links: 6.3.3` est déjà dans les `pubspec.yaml`, ne pas le lever |
| `Unsupported class file major version` / erreurs Kotlin | JDK ≠ 17 ou AGP/Kotlin non alignés → la CI force AGP 8.1.0 + Kotlin 1.8.22 + Java 17 |
| Build Windows sur Linux/macOS | impossible : MSVC requis → runner Windows ou machine Windows |
| `CMake Error … Generator "Visual Studio 16 2019" could not find any instance of Visual Studio` | Flutter 3.24.5 ne mappe que VS **17** sur le générateur `Visual Studio 17 2022` et retombe sinon sur VS 2019 (`packages/flutter_tools/lib/src/windows/visual_studio.dart`). Or `windows-latest` / `windows-2025` embarquent **Visual Studio 2026** depuis juin 2026. Corrigé dans la CI par `runs-on: windows-2022` ; en local, installer VS 2022 avec la charge « Desktop development with C++ » |
| L'app démarre mais affiche le catalogue de démonstration | defines Supabase absents à la compilation (voir §C) |
| `flutter analyze` plante silencieusement (sandbox sans SDK) | utiliser `$FLUTTER_ROOT/bin/cache/dart-sdk/bin/dart analyze` |
| Échec CI | artefact `analyze-log` d'abord, puis `apk-build-logs` / `windows-build-log` ; une issue `build-artifacts failure report` est ouverte automatiquement |
