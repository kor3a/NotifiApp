# Allim Android — Setup Guide

React Native app for Android that mirrors the iOS Allim app — same Firebase
project (`georeminder-pilot`), same features, matching UI style.

Built with **Expo SDK 52** using the **prebuild / CNG** workflow and **EAS Build**.

---

## How this project is structured

`android/` is **generated**, not written. It is produced by `npx expo prebuild`
from `app.config.js` plus the config plugins, and it is **git-ignored** — any
edit you make there is wiped by the next prebuild.

To change something native, change one of these instead:

| What you want to change | Where |
|---|---|
| App name, icon, version, permissions, Maps key | `app.config.js` |
| SDK levels, Kotlin version, cleartext, ProGuard | `expo-build-properties` block in `app.config.js` |
| NDK pin, dependency forces, Notifee repo, CMake stubs, `allowBackup` | `plugins/withAllimNativeBuild.js` |
| Build profiles (dev / preview / production) | `eas.json` |

---

## Prerequisites

- **Node.js 18+**
- For **cloud builds (recommended)**: nothing else — no Android Studio, no JDK.
- For **local builds only**: Android Studio + SDK 35, JDK 17, and an emulator.
  See "Local builds" below.

---

## First-time setup

```sh
cd AllimAndroid
npm install
npm install -g eas-cli
eas login
eas init          # links the project and writes extra.eas.projectId
```

---

## Cloud builds with EAS (recommended)

Three profiles are defined in `eas.json`:

| Profile | Output | Use it for |
|---|---|---|
| `development` | debug APK + dev client | Day-to-day development with Fast Refresh |
| `preview` | release APK | Sharing a testable build internally |
| `production` | AAB | Play Store upload |

```sh
npm run build:dev       # eas build --profile development --platform android
npm run build:preview
npm run build:prod
```

Install the resulting APK on your device/emulator, then start the bundler:

```sh
npm start               # expo start --dev-client
```

The dev client connects to that bundler — you only need to rebuild the APK when
**native** code changes (a new native dependency, or a config/plugin change).
Pure JS/TS changes hot-reload.

### Maps API key

`MAPS_API_KEY` is set in `eas.json` under the `base` profile and read by
`app.config.js`. To override it locally:

```sh
MAPS_API_KEY=your_key npx expo prebuild --platform android --clean
```

A Google Maps **Android** key ships inside the APK by design — it is secured by
the package-name + signing-SHA1 restriction in Google Cloud, not by secrecy.
Make sure `com.allimandroid` and your EAS signing SHA-1 are on the key's
allow-list, and that **Maps SDK for Android** is enabled for it.

---

## Local builds

Only needed if you'd rather not build in the cloud.

1. **Android Studio** → SDK Manager → install **SDK 35**, **Emulator**,
   **Platform-Tools**, and **NDK 27.1.12297006**.
2. **JDK 17** (`brew install openjdk@17`), then:
   ```sh
   sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk \
     /Library/Java/JavaVirtualMachines/openjdk-17.jdk
   echo 'export JAVA_HOME=$(/usr/libexec/java_home -v17)' >> ~/.zshrc
   ```
3. **SDK path** in `~/.zshrc`:
   ```sh
   export ANDROID_HOME=$HOME/Library/Android/sdk
   export PATH=$PATH:$ANDROID_HOME/emulator:$PATH:$ANDROID_HOME/platform-tools
   ```
4. Start an emulator, then:
   ```sh
   npm run android      # expo run:android — prebuilds, then Gradle-builds
   ```

> On Apple Silicon, pick an **ARM64** system image.

---

## Firebase

`google-services.json` lives at the **project root** and is wired up by
`expo.android.googleServicesFile` in `app.config.js`; prebuild copies it into
`android/app/`. It is already registered for package `com.allimandroid`.

---

## Regenerating the native project

```sh
npm run prebuild:clean   # expo prebuild --platform android --clean
```

Run this after changing `app.config.js`, `plugins/`, or any native dependency.
`--clean` deletes `android/` first, which is the safe default here since nothing
in it is hand-written.

---

## Native workarounds carried over from the old bare project

All of these live in `plugins/withAllimNativeBuild.js`:

- **NDK pinned to 27.1.12297006** — emits 16 KB-aligned ELF segments for
  Android 15+ page sizes. Paired with `useLegacyPackaging: false`.
- **`androidx.core` forced to 1.15.0** — 1.17.0+ needs AGP 8.9.1 / compileSdk 36.
- **`play-services-location` forced to 21.0.1** — `react-native-geolocation-service@5.3.1`
  was compiled when `FusedLocationProviderClient` was a class; 21.1.0+ made it an
  interface, which throws *"Found interface … but class was expected"* at runtime.
- **Notifee local maven repo** — Notifee ships Android artifacts inside
  `node_modules` instead of publishing them remotely.
- **`-Xskip-metadata-version-check`** — RN 0.76's Gradle plugin requires Kotlin
  < 2.0 while some Firebase artifacts are built with Kotlin 2.x.
- **CMake stub libraries** — RN 0.76 merged several libs into
  `libreactnative.so`, but some callers still `SoLoader.loadLibrary()` the old
  names. The generated `MainApplication.kt` also installs
  `OpenSourceMergedSoMapping`, which addresses the same problem, so **these
  stubs may now be redundant.** If a build succeeds without them, delete
  `withCMakeStubs` and the `externalNativeBuild` blocks from the plugin.
- **`android:allowBackup="false"`** — Expo defaults it to `true`; the app holds a
  signed-in Firebase session that shouldn't be auto-backed-up off-device.

---

## Troubleshooting

**A native change isn't showing up** → rebuild the dev client
(`npm run build:dev`), not just the bundler. JS-only changes don't need this.

**Metro cache weirdness**
```sh
npx expo start --dev-client --clear
```

**Gradle can't find Notifee artifacts** → the local maven repo path is
`$rootDir/../node_modules/@notifee/react-native/android/libs`; make sure
`npm install` has run.

**Maps renders blank** → key restriction or **Maps SDK for Android** not enabled
for the key. See "Maps API key" above.

**`expo prebuild` fails on a plugin anchor** → `withAllimNativeBuild` throws a
descriptive error when Expo's Gradle template changes shape. Update the anchor
regex in that file.
