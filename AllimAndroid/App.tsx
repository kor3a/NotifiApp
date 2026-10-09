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

// The notification permission itself is asked for by the onboarding primer
// after sign-up, with an explanation in front of it, rather than fired at
// launch before the user knows what the app does with it. The channels can
// exist either way.
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

function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';
  const appState = useRef<AppStateStatus>(AppState.currentState);

  useEffect(() => {
    createNotificationChannels();

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
