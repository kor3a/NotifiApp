import React, {useCallback, useEffect, useState} from 'react';
import {ActivityIndicator, Image, View} from 'react-native';
import {NavigatorScreenParams} from '@react-navigation/native';
import {createNativeStackNavigator} from '@react-navigation/native-stack';
import {createBottomTabNavigator} from '@react-navigation/bottom-tabs';
import {useColorScheme} from 'react-native';
import Icon from '../components/AppIcon';
import LaunchScreen from '../components/LaunchScreen';

import {SessionProvider, useSession} from '../context/SessionContext';

// Auth screens
import LoginScreen from '../screens/auth/LoginScreen';
import SignupScreen from '../screens/auth/SignupScreen';
import ForgotPasswordScreen from '../screens/auth/ForgotPasswordScreen';
import ProfileSetupScreen from '../screens/auth/ProfileSetupScreen';
import PermissionOnboardingScreen from '../screens/onboarding/PermissionOnboardingScreen';
import {usePermissionOnboarding} from '../onboarding/permissionOnboarding';
import TutorialOverlay from '../tutorial/TutorialOverlay';
import {tutorial, useTutorialActive} from '../tutorial/tutorialManager';
import {tutorialConversations} from '../tutorial/tutorialMockData';
import {messageService} from '../services/messageService';
import {totalUnreadCount} from '../models';

// Main screens
import StoresScreen from '../screens/stores/StoresScreen';
import ReminderScreen from '../screens/stores/ReminderScreen';
import MessagesScreen from '../screens/messages/MessagesScreen';
import ConversationScreen from '../screens/messages/ConversationScreen';
import FriendsScreen from '../screens/friends/FriendsScreen';
import MapScreen from '../screens/map/MapScreen';
import SmartRecipeScreen from '../screens/recipe/SmartRecipeScreen';
import ProfileScreen from '../screens/profile/ProfileScreen';
import AccountSecurityScreen from '../screens/profile/AccountSecurityScreen';
import AboutScreen from '../screens/profile/AboutScreen';
import ReportFeedbackScreen from '../screens/profile/ReportFeedbackScreen';
import SubscriptionScreen from '../screens/profile/SubscriptionScreen';
import SubscriptionManagementScreen from '../screens/profile/SubscriptionManagementScreen';

import {Colors} from '../theme/AppTheme';

export type AuthStackParamList = {
  // Sign Up returns here with the address it registered, so Login can say
  // where the confirmation email went.
  Login: {signupEmail?: string} | undefined;
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
    // Who else is on the store, so edits here can notify them as iOS does.
    sourceUserStoreId?: string;
    sharedStoreGroupId?: string;
  };
  Profile: undefined;
  // Profile's own sub-screens, as on iOS.
  AccountSecurity: undefined;
  About: undefined;
  ReportFeedback: undefined;
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

export type MainTabParamList = {
  Stores: undefined;
  Messages: undefined;
  'AI Recipe': undefined;
  Search: undefined;
};

export type MainStackParamList = {
  Tabs: NavigatorScreenParams<MainTabParamList> | undefined;
  // The Premium paywall — a sheet over the whole app on iOS, so it sits above
  // the tabs here and rises from the bottom.
  Subscription: undefined;
  // What Premium subscribers see instead of the paywall: their features and
  // the way to change plan or cancel. Also a sheet on iOS.
  SubscriptionManagement: undefined;
};

const AuthStack = createNativeStackNavigator<AuthStackParamList>();
const Tab = createBottomTabNavigator<MainTabParamList>();
const StoresStack = createNativeStackNavigator<StoresStackParamList>();
const MessagesStack = createNativeStackNavigator<MessagesStackParamList>();
const MapStack = createNativeStackNavigator<MapStackParamList>();
const MainStack = createNativeStackNavigator<MainStackParamList>();

function StoresNavigator() {
  return (
    <StoresStack.Navigator screenOptions={{headerShown: false}}>
      <StoresStack.Screen name="StoresList" component={StoresScreen} />
      <StoresStack.Screen name="Reminders" component={ReminderScreen} />
      <StoresStack.Screen name="Profile" component={ProfileScreen} />
      <StoresStack.Screen name="AccountSecurity" component={AccountSecurityScreen} />
      <StoresStack.Screen name="About" component={AboutScreen} />
      <StoresStack.Screen name="ReportFeedback" component={ReportFeedbackScreen} />
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

// The Messages tab's badge: unread messages across every conversation, kept
// live like iOS's MessagesViewModel.totalUnreadCount. While the tutorial runs
// it counts the stand-in conversations instead, which carry one unread, as iOS
// shows.
function useUnreadMessageCount(): number {
  const {currentUser} = useSession();
  // Conversations are keyed by username, not the Firebase Auth uid.
  const userId = currentUser?.userId;
  const tutorialActive = useTutorialActive();
  const [liveCount, setLiveCount] = useState(0);

  useEffect(() => {
    if (!userId) {
      setLiveCount(0);
      return;
    }
    return messageService.subscribeToTotalUnreadCount(userId, setLiveCount);
  }, [userId]);

  return tutorialActive
    ? totalUnreadCount(tutorialConversations(userId ?? ''), userId ?? '')
    : liveCount;
}

function MainTabs() {
  const scheme = useColorScheme();
  const isDark = scheme === 'dark';
  const unreadMessages = useUnreadMessageCount();

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
      <Tab.Screen
        name="Messages"
        component={MessagesNavigator}
        options={{
          // No badge at all when everything is read, as on iOS.
          tabBarBadge: unreadMessages > 0 ? unreadMessages : undefined,
          tabBarBadgeStyle: {backgroundColor: '#FF3B30', color: '#FFFFFF'},
        }}
      />
      <Tab.Screen name="AI Recipe" component={SmartRecipeScreen} />
      <Tab.Screen name="Search" component={MapNavigator} />
    </Tab.Navigator>
  );
}

function MainNavigator({uid}: {uid: string}) {
  // The tour starts the first time this account reaches the app on this
  // device — after the permission primers, as on iOS.
  useEffect(() => {
    tutorial.startIfNeeded(uid);
    return () => tutorial.reset();
  }, [uid]);

  return (
    <View style={{flex: 1}}>
      <MainStack.Navigator screenOptions={{headerShown: false}}>
        <MainStack.Screen name="Tabs" component={MainTabs} />
        <MainStack.Screen
          name="Subscription"
          component={SubscriptionScreen}
          options={{presentation: 'modal', animation: 'slide_from_bottom'}}
        />
        <MainStack.Screen
          name="SubscriptionManagement"
          component={SubscriptionManagementScreen}
          options={{presentation: 'modal', animation: 'slide_from_bottom'}}
        />
      </MainStack.Navigator>
      {/* Above the tabs, tab bar included. */}
      <TutorialOverlay />
    </View>
  );
}

// The logo as LaunchScreen leaves it, for waits after the launch itself: the
// same teal and the same 200dp icon in the same spot, with a spinner while the
// account's permission state is worked out after signing in.
function LoadingScreen() {
  return (
    <View
      style={{
        flex: 1,
        justifyContent: 'center',
        alignItems: 'center',
        backgroundColor: '#0B7285',
      }}>
      <Image
        source={require('../../assets/icon.png')}
        style={{width: 200, height: 200}}
        accessibilityLabel="Allim"
      />
      <ActivityIndicator
        size="small"
        color="#E0F1F4"
        style={{position: 'absolute', bottom: 96}}
      />
    </View>
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
  const {firebaseUser, isAuthenticated, isLoading, profileStatus} = useSession();

  // Evaluated only once the account has a profile to land in; a brand-new
  // account is walked through location and notifications first, so the system
  // prompts arrive with an explanation attached.
  const hasProfile = isAuthenticated && !isLoading && profileStatus !== 'needsSetup';
  const uid: string | null = hasProfile ? firebaseUser?.uid ?? null : null;
  const permissionOnboarding = usePermissionOnboarding(uid);

  // Stays up until the screen this launch ends on exists, so it reveals that
  // screen rather than a LoadingScreen standing in for it.
  const [launchFinished, setLaunchFinished] = useState(false);
  const onLaunchFinished = useCallback(() => setLaunchFinished(true), []);
  const launchSettled =
    !isLoading && (!hasProfile || permissionOnboarding.state.kind !== 'evaluating');

  return (
    <View style={{flex: 1}}>
      <RootScreen
        isAuthenticated={isAuthenticated}
        isLoading={isLoading}
        profileStatus={profileStatus}
        permissionOnboarding={permissionOnboarding}
        uid={uid}
      />
      {launchFinished ? null : (
        <LaunchScreen ready={launchSettled} onFinished={onLaunchFinished} />
      )}
    </View>
  );
}

function RootScreen({
  isAuthenticated,
  isLoading,
  profileStatus,
  permissionOnboarding,
  uid,
}: Pick<
  ReturnType<typeof useSession>,
  'isAuthenticated' | 'isLoading' | 'profileStatus'
> & {
  permissionOnboarding: ReturnType<typeof usePermissionOnboarding>;
  uid: string | null;
}) {
  if (isLoading) {
    return <LoadingScreen />;
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

  switch (permissionOnboarding.state.kind) {
    case 'active':
      return (
        <PermissionOnboardingScreen
          steps={permissionOnboarding.state.steps}
          onFinished={permissionOnboarding.finish}
        />
      );
    case 'evaluating':
      // Still working out whether there is anything to ask — hold rather than
      // flash the app before a primer appears.
      return <LoadingScreen />;
    case 'finished':
      return <MainNavigator uid={uid ?? ''} />;
  }
}

export default function AppNavigator() {
  return (
    <SessionProvider>
      <RootNavigator />
    </SessionProvider>
  );
}
