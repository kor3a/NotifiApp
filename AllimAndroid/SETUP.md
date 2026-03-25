# Allim Android - Setup Guide

React Native app for Android that mirrors the iOS Allim app — same Firebase project (`georeminder-pilot`), same features, matching UI style.

---

## Prerequisites (one-time setup on your Mac)

### 1. Install Android Studio
Download from: https://developer.android.com/studio

After install, open Android Studio → SDK Manager → install:
- **Android SDK 35** (Android 15)
- **Android Emulator**
- **Android SDK Platform-Tools**

### 2. Set up your Android Emulator (AVD)
1. Open Android Studio → **Device Manager** (right sidebar or Tools menu)
2. Click **"+"** → **Create Virtual Device**
3. Pick **Pixel 8** (or any Pixel phone) → Next
4. Select system image: **API 35 (Android 15)** — download if needed → Next → Finish
5. Click ▶ to start the emulator

> **M1/M2 Mac tip**: Choose an **ARM64** system image — it runs natively fast on Apple Silicon.

### 3. Install Java 17
```sh
brew install openjdk@17
```

After install, Homebrew requires a symlink so macOS can find the JDK:
```sh
sudo ln -sfn /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk-17.jdk
```

Then add `JAVA_HOME` to your shell:
```sh
echo 'export JAVA_HOME=$(/usr/libexec/java_home -v17)' >> ~/.zshrc
source ~/.zshrc
```

Verify with `java -version` — you should see `openjdk version "17.x.x"`.

### 4. Set Android SDK path
Add to your `~/.zshrc`:
```sh
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools
```
Then run `source ~/.zshrc`.

### 5. Install Node.js (if not done)
```sh
brew install node
```

---

## Firebase Setup (REQUIRED)

You need to register the Android app in your existing Firebase project:

1. Go to [Firebase Console](https://console.firebase.google.com) → Project `georeminder-pilot`
2. Click **"Add app"** → **Android**
3. Set **Android package name**: `com.allimandroid`
4. Register the app
5. **Download `google-services.json`**
6. Replace `android/app/google-services.json` with the downloaded file

> The placeholder file already has the correct project info — you just need the real `mobilesdk_app_id` which Firebase generates when you register.

---

## Install & Run

```sh
# 1. Navigate to the project
cd AllimAndroid

# 2. Install dependencies
npm install

# 3. Make sure your Android emulator is running, then:
npx react-native run-android
```

The app will build and install on the emulator (~2-3 minutes first time, much faster after).

---

## Project Structure

```
AllimAndroid/
├── src/
│   ├── context/         # SessionContext (auth state)
│   ├── models/          # TypeScript interfaces matching Firestore
│   ├── navigation/      # React Navigation setup
│   ├── screens/
│   │   ├── auth/        # Login, Signup, ForgotPassword
│   │   ├── stores/      # StoresScreen, ReminderScreen
│   │   ├── messages/    # MessagesScreen, ConversationScreen
│   │   ├── friends/     # FriendsScreen
│   │   ├── map/         # MapScreen
│   │   └── profile/     # ProfileScreen
│   ├── services/        # Firebase CRUD (auth, stores, reminders, messages, friends)
│   ├── theme/           # AppTheme.ts — colors, spacing, card styles
│   └── components/      # Shared UI (GradientBackground, Card, PrimaryButton, etc.)
├── android/             # Android native project
└── App.tsx              # Root component
```

---

## Features Implemented

| Feature | Status |
|---------|--------|
| Email/password auth + verification | ✅ |
| Sign up / forgot password | ✅ |
| Stores list (real-time Firestore) | ✅ |
| Add / delete stores | ✅ |
| Reminders with categories | ✅ |
| Toggle done / edit / delete reminders | ✅ |
| Photo attachments on reminders | ✅ |
| Real-time messages + conversations | ✅ |
| Friend requests (send / accept / decline) | ✅ |
| Map view with store markers | ✅ |
| Profile editing + photo upload | ✅ |
| Delete account | ✅ |
| Push notifications (FCM) | ✅ |
| Dark mode support | ✅ |

---

## Push Notifications

To receive push notifications, you also need to add an FCM Server Key in Firebase:
1. Firebase Console → Project Settings → Cloud Messaging
2. The FCM token is automatically saved to Firestore when the user logs in

---

## Troubleshooting

**Build fails with "SDK location not found"**
→ Create `android/local.properties` with:
```
sdk.dir=/Users/YOUR_USERNAME/Library/Android/sdk
```

**Metro bundler issues / `Cannot read properties of undefined (reading 'handle')`**

This error means Metro received `undefined` instead of a valid middleware — usually from a corrupted `node_modules`. Fix with a clean reinstall:
```sh
rm -rf node_modules
npm install
npx react-native start --reset-cache
```

If it still fails, also clear Watchman's file-watch cache:
```sh
watchman watch-del-all
npx react-native start --reset-cache
```

**Firebase not connecting**
→ Make sure you replaced `android/app/google-services.json` with the real one.

**Maps not showing**
→ Get a Google Maps API key from Google Cloud Console, enable Maps SDK for Android, then add to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY"/>
```
