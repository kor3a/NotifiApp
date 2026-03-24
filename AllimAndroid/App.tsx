import React, {useEffect} from 'react';
import {StatusBar} from 'react-native';
import {NavigationContainer} from '@react-navigation/native';
import {SafeAreaProvider} from 'react-native-safe-area-context';
import {GestureHandlerRootView} from 'react-native-gesture-handler';
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

function App(): React.JSX.Element {
  const isDarkMode = useColorScheme() === 'dark';

  useEffect(() => {
    requestNotificationPermission();

    // Handle FCM background messages
    const unsubscribe = messaging().onMessage(async remoteMessage => {
      if (remoteMessage.notification) {
        await notifee.displayNotification({
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

    return unsubscribe;
  }, []);

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
