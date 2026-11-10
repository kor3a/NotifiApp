import React, {useEffect, useRef} from 'react';
import {AppState, AppStateStatus, StatusBar} from 'react-native';
import {NavigationContainer} from '@react-navigation/native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
import AppNavigator from './src/navigation/AppNavigator';
import {navigationRef} from './src/navigation/navigationRef';
import {useColorScheme} from 'react-native';
import messaging from '@react-native-firebase/messaging';
import notifee, {AndroidImportance} from '@notifee/react-native';
import mobileAds from 'react-native-google-mobile-ads';

// The notification permission itself is asked for by the onboarding primer
// after sign-up, with an explanation in front of it, rather than fired at
// launch before the user knows what the app does with it. The channels can
// exist either way.
//
// firebase.json names 'allim-default' as FCM's default channel, for pushes that
// arrive while the app is in the background. Android keeps the importance a
// channel was first created with, so changing it here needs a new channel id.
async function createNotificationChannels() {
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

// Start the Google Mobile Ads SDK at launch, as the iOS app does, so the first
// banner a non-subscriber sees doesn't wait on initialization.
mobileAds()
  .initialize()
  .catch(error => console.warn('Could not start Google Mobile Ads', error));

function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const appState = useRef<AppStateStatus>(AppState.currentState);

  useEffect(() => {
    createNotificationChannels().catch(error => {
      console.warn('Could not create notification channels', error);
    });

    const unsubscribe = messaging().onMessage(async remoteMessage => {
      if (remoteMessage.notification) {
        try {
          await notifee.displayNotification({
            // Using messageId collapses duplicate deliveries of the same FCM
            // message into a single visible notification.
            id: remoteMessage.messageId,
            title: remoteMessage.notification.title,
            body: remoteMessage.notification.body,
            android: {
              channelId: 'allim-default',
              // Generated from expo.notification.icon in app.config.js.
              smallIcon: 'notification_icon',
              color: '#0B7285',
              pressAction: {id: 'default'},
            },
          });
        } catch (error) {
          console.warn('Could not display notification', error);
        }
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

  return (
    <GestureHandlerRootView style={{flex: 1}}>
      <SafeAreaProvider>
        <StatusBar
          barStyle={isDarkMode ? 'light-content' : 'dark-content'}
          translucent
          backgroundColor="transparent"
        />
        <NavigationContainer ref={navigationRef}>
          <AppNavigator />
        </NavigationContainer>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}

export default App;
