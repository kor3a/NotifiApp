import React from 'react';
import {ActivityIndicator, View} from 'react-native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {useColorScheme} from 'react-native';
import Icon from '../components/AppIcon';

import {SessionProvider, useSession} from '../context/SessionContext';

// Auth screens
import LoginScreen from '../screens/auth/LoginScreen';
import SignupScreen from '../screens/auth/SignupScreen';
import ForgotPasswordScreen from '../screens/auth/ForgotPasswordScreen';
import ProfileSetupScreen from '../screens/auth/ProfileSetupScreen';

// Main screens
import StoresScreen from '../screens/stores/StoresScreen';
import ReminderScreen from '../screens/stores/ReminderScreen';
import MessagesScreen from '../screens/messages/MessagesScreen';
import ConversationScreen from '../screens/messages/ConversationScreen';
import FriendsScreen from '../screens/friends/FriendsScreen';
import MapScreen from '../screens/map/MapScreen';
import SmartRecipeScreen from '../screens/recipe/SmartRecipeScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';

import {Colors} from '../theme/AppTheme';

export type AuthStackParamList = {
  Login: undefined;
  Signup: undefined;
  ForgotPassword: undefined;
};

export type StoresStackParamList = {
  StoresList: undefined;
  Reminders: {
    userStoreId: string; // this user's user_store doc (per-user settings)
    reminderStoreId: string; // where the reminders actually live (shared-aware)
    storeName: string;
    storeId: string;
    permission: string;
    isSharedStore?: boolean;
    sharedWith?: string[];
    sharedFromName?: string;
  };
  Profile: undefined;
  // Friends has no tab of its own — it lives under Profile, as on iOS.
  Friends: undefined;
};

export type MessagesStackParamList = {
  MessagesList: undefined;
  Conversation: {
    conversationId: string;
    otherUserId: string; // empty for a group — there is no single other person
    otherUserName: string; // the group's name for a group conversation
    isGroup?: boolean;
  };
};

export type MapStackParamList = {
  MapView: undefined;
};

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const Tab = createBottomTabNavigator();
const StoresStack = createNativeStackNavigator<StoresStackParamList>();
const MessagesStack = createNativeStackNavigator<MessagesStackParamList>();
const MapStack = createNativeStackNavigator<MapStackParamList>();

function StoresNavigator() {
  return (
    <StoresStack.Navigator screenOptions={{headerShown: false}}>
      <StoresStack.Screen name="StoresList" component={StoresScreen} />
      <StoresStack.Screen name="Reminders" component={ReminderScreen} />
      <StoresStack.Screen name="Profile" component={ProfileScreen} />
      <StoresStack.Screen name="Friends" component={FriendsScreen} />
    </StoresStack.Navigator>
  );
}

function MessagesNavigator() {
  return (
    <MessagesStack.Navigator screenOptions={{headerShown: false}}>
      <MessagesStack.Screen name="MessagesList" component={MessagesScreen} />
      <MessagesStack.Screen name="Conversation" component={ConversationScreen} />
    </MessagesStack.Navigator>
  );
}

function MapNavigator() {
  return (
    <MapStack.Navigator screenOptions={{headerShown: false}}>
      <MapStack.Screen name="MapView" component={MapScreen} />
    </MapStack.Navigator>
  );
}

function MainTabs() {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';

  return (
    <Tab.Navigator
      screenOptions={({route}) => ({
        headerShown: false,
        tabBarActiveTintColor: Colors.blue,
        tabBarInactiveTintColor: isDark ? '#8E8E93' : '#6C6C70',
        tabBarStyle: {
          backgroundColor: isDark ? '#1C1C1E' : '#F9F9F9',
          borderTopColor: isDark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.1)',
          paddingBottom: 4,
        },
        // The iOS tab bar's four tabs, in its order. Ionicons chosen to match
        // its SF Symbols: storefront -> storefront, message -> chatbubble,
        // fork.knife.circle -> restaurant, map -> map (Search keeps the map
        // glyph on iOS too). Ionicons has a filled and an -outline cut of
        // each, which stands in for SF Symbols' selected/unselected weights.
        tabBarIcon: ({focused, color, size}) => {
          // Icon's `name` is a union of the 1338 real glyph names, so a typo
          // here is a compile error rather than a silently blank tab.
          let iconName: React.ComponentProps<typeof Icon>['name'] =
            'ellipse-outline';
          if (route.name === 'Stores') {
            iconName = focused ? 'storefront' : 'storefront-outline';
          } else if (route.name === 'Messages') {
            iconName = focused ? 'chatbubble' : 'chatbubble-outline';
          } else if (route.name === 'AI Recipe') {
            iconName = focused ? 'restaurant' : 'restaurant-outline';
          } else if (route.name === 'Search') {
            iconName = focused ? 'map' : 'map-outline';
          }
          return <Icon name={iconName} size={size} color={color} />;
        },
      })}>
      <Tab.Screen name="Stores" component={StoresNavigator} />
      <Tab.Screen name="Messages" component={MessagesNavigator} />
      <Tab.Screen name="AI Recipe" component={SmartRecipeScreen} />
      <Tab.Screen name="Search" component={MapNavigator} />
    </Tab.Navigator>
  );
}

function AuthNavigator() {
  return (
    <AuthStack.Navigator screenOptions={{headerShown: false}}>
      <AuthStack.Screen name="Login" component={LoginScreen} />
      <AuthStack.Screen name="Signup" component={SignupScreen} />
      <AuthStack.Screen name="ForgotPassword" component={ForgotPasswordScreen} />
    </AuthStack.Navigator>
  );
}

function RootNavigator() {
  const {isAuthenticated, isLoading, profileStatus} = useSession();

  if (isLoading) {
    return (
      <View style={{flex: 1, justifyContent: 'center', alignItems: 'center'}}>
        <ActivityIndicator size="large" color={Colors.blue} />
      </View>
    );
  }

  if (!isAuthenticated) {
    return <AuthNavigator />;
  }

  // A first Google sign-in creates the Firebase account but no Firestore
  // profile, and the rest of the app is keyed by the username that profile
  // carries. Only 'needsSetup' routes here — a profile lookup that merely
  // failed (offline) stays 'unknown' and falls through to the app, which is how
  // it behaved before social sign-in existed.
  if (profileStatus === 'needsSetup') {
    return <ProfileSetupScreen />;
  }

  return <MainTabs />;
}

export default function AppNavigator() {
  return (
    <SessionProvider>
      <RootNavigator />
    </SessionProvider>
  );
}
