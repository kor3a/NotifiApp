import React, {useEffect, useRef} from 'react';
import {AppState, AppStateStatus, StatusBar} from 'react-native';
import {NavigationContainer} from '@react-navigation/native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
import {useFonts} from 'expo-font';
import AppNavigator from './src/navigation/AppNavigator';
import {useColorScheme} from 'react-native';
import messaging from '@react-native-firebase/messaging';
import notifee, {AndroidImportance} from '@notifee/react-native';

async function requestNotificationPermission() {
  await messaging().requestPermission();
  await notifee.requestPermission();

  // Create notification channel for Android
  await notifee.createChannel({
    id: 'allim-default',
    name: 'Allim Notifications',
    importance: AndroidImportance.HIGH,
    sound: 'default',
  });

  await notifee.createChannel({
    id: 'allim-reminders',
    name: 'Shopping Reminders',
    importance: AndroidImportance.HIGH,
    sound: 'default',
  });
}

// Claim background message handling so FCM does not re-deliver the message to
// the foreground handler when the user opens the app by tapping the icon.
messaging().setBackgroundMessageHandler(async () => {});

function App(): React.JSX.Element | null {
  const isDarkMode = useColorScheme() === 'dark';
  const appState = useRef<AppStateStatus>(AppState.currentState);

  // react-native-vector-icons renders every glyph as <Text fontFamily="Ionicons">,
  // so an unregistered family silently draws nothing — which is what turns the
  // tab bar and the + button into blank space. The expo-font config plugin does
  // embed Ionicons.ttf in the APK, but that only takes effect on a fresh
  // prebuild + native build; registering the same file at runtime makes the
  // icons appear on any binary, including an older dev client.
  const [fontsLoaded, fontError] = useFonts({
    Ionicons: require('react-native-vector-icons/Fonts/Ionicons.ttf'),
  });

  useEffect(() => {
    requestNotificationPermission();

    const unsubscribe = messaging().onMessage(async remoteMessage => {
      if (remoteMessage.notification) {
        await notifee.displayNotification({
          // Using messageId collapses duplicate deliveries of the same FCM
          // message into a single visible notification.
          id: remoteMessage.messageId,
          title: remoteMessage.notification.title,
          body: remoteMessage.notification.body,
          android: {
            channelId: 'allim-default',
            smallIcon: 'ic_notification',
            pressAction: {id: 'default'},
          },
        });
      }
    });

    // When the user opens the app by tapping the icon (not the notification),
    // clear any notifications the system tray is still holding so they don't
    // reappear alongside a fresh delivery.
    const subscription = AppState.addEventListener('change', nextState => {
      if (
        appState.current.match(/inactive|background/) &&
        nextState === 'active'
      ) {
        notifee.cancelDisplayedNotifications();
      }
      appState.current = nextState;
    });

    return () => {
      unsubscribe();
      subscription.remove();
    };
  }, []);

  // Hold the first frame until the icon font is registered, so no screen paints
  // with holes where its icons go. A load failure falls through rather than
  // hanging the app — the icons stay blank, everything else still works.
  if (!fontsLoaded && !fontError) {
    return null;
  }

  return (
    <GestureHandlerRootView style={{flex: 1}}>
      <SafeAreaProvider>
        <StatusBar
          barStyle={isDarkMode ? 'light-content' : 'dark-content'}
          translucent
          backgroundColor="transparent"
        />
        <NavigationContainer>
          <AppNavigator />
        </NavigationContainer>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

export default App;
