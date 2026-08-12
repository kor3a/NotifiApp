/**
 * Expo app config (CNG / prebuild).
 *
 * android/ is generated from this file by `npx expo prebuild` and is no longer
 * checked in — edit this config, never the generated Gradle/manifest files.
 *
 * The Maps key is read from the environment so it can live in an EAS secret;
 * the fallback keeps local builds working. A Google Maps *Android* key ships
 * inside the APK by design and is secured by the package-name + signing-SHA1
 * restriction in Google Cloud, not by being kept private.
 */
const MAPS_API_KEY =
  process.env.MAPS_API_KEY || 'AIzaSyDfqvH3s2BwiwmAy46AT4NLYAjboTF4gkY';

module.exports = {
  expo: {
    name: 'Allim',
    slug: 'allim',
    version: '1.0.0',
    orientation: 'portrait',
    icon: './assets/icon.png',
    userInterfaceStyle: 'automatic',
    // The RN 0.76 old architecture — notifee, react-native-geolocation-service
    // and react-native-background-fetch are not all Fabric-ready yet.
    newArchEnabled: false,
    jsEngine: 'hermes',
    assetBundlePatterns: ['**/*'],

    android: {
      package: 'com.allimandroid',
      versionCode: 1,
      googleServicesFile: './google-services.json',
      adaptiveIcon: {
        foregroundImage: './assets/icon.png',
        backgroundColor: '#F2F3F8',
      },
      permissions: [
        'android.permission.INTERNET',
        // Geofencing around saved stores.
        'android.permission.ACCESS_FINE_LOCATION',
        'android.permission.ACCESS_COARSE_LOCATION',
        'android.permission.ACCESS_BACKGROUND_LOCATION',
        // Reminder + FCM notifications.
        'android.permission.POST_NOTIFICATIONS',
        'android.permission.VIBRATE',
        'android.permission.RECEIVE_BOOT_COMPLETED',
        // Reminder photo attachments and profile pictures.
        'android.permission.CAMERA',
        'android.permission.READ_MEDIA_IMAGES',
      ],
      config: {
        googleMaps: {apiKey: MAPS_API_KEY},
      },
    },

    plugins: [
      '@react-native-firebase/app',
      '@react-native-firebase/auth',
      '@react-native-firebase/messaging',
      [
        'expo-build-properties',
        {
          android: {
            minSdkVersion: 24,
            compileSdkVersion: 35,
            targetSdkVersion: 35,
            buildToolsVersion: '35.0.0',
            // RN 0.76's Gradle plugin requires Kotlin < 2.0.
            kotlinVersion: '1.9.25',
            // Store .so files uncompressed and page-aligned so the loader can
            // mmap them on 16 KB page-size devices (Android 15+).
            useLegacyPackaging: false,
            usesCleartextTraffic: true,
            // Notifee's local maven repo is added by ./plugins/withAllimNativeBuild
            // instead of extraMavenRepos: that option injects the URL verbatim
            // into every project, so a relative path resolves against each
            // subproject's own dir (wrong for :app) and "$rootDir" is not
            // expanded. The plugin emits real Groovy, which handles both.
            extraProguardRules: '-keep class com.allimandroid.** { *; }',
          },
        },
      ],
      [
        'expo-font',
        {
          // Only Ionicons is used, so embed that one family instead of
          // pulling in all 19 via react-native-vector-icons' fonts.gradle.
          fonts: ['./node_modules/react-native-vector-icons/Fonts/Ionicons.ttf'],
        },
      ],
      // Must come after expo-build-properties so its Gradle edits land on top.
      './plugins/withAllimNativeBuild',
      'expo-dev-client',
    ],

    extra: {
      eas: {
        // The EAS project this app builds under. `eas init` cannot write this
        // itself because app.config.js is a dynamic config, so it is set here.
        // Not a secret — it only identifies the project, and access is
        // controlled by your Expo account.
        projectId:
          process.env.EAS_PROJECT_ID || 'c0718b2f-967f-4cdf-9915-dda86b1ead0e',
      },
    },
  },
};
