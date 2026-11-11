import React, {useEffect, useRef, useState} from 'react';
import {
  Animated,
  ScrollView,
  StyleSheet,
  Text,
  View,
  useColorScheme,
  ColorSchemeName,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {PillButton, profilePalette} from '../profile/profileUi';
import {BlushIcon} from '../auth/authUi';
import {
  PermissionStep,
  requestBackgroundLocationPermission,
  requestLocationPermission,
  requestNotificationPermission,
} from '../../onboarding/permissionOnboarding';
import {proximityMonitor} from '../../services/proximityMonitor';

type IconName = React.ComponentProps<typeof Icon>['name'];

type Bullet = {icon: IconName; title: string; detail: string};

type PrimerContent = {
  icon: IconName;
  title: string;
  subtitle: string;
  bullets: Bullet[];
  footnote: string;
  buttonTitle: string;
  request: () => Promise<void>;
};

// The copy is the iOS primers', with the one line that names the system
// dialog's button reworded for Android's.
const PRIMERS: Record<PermissionStep, PrimerContent> = {
  location: {
    icon: 'location',
    title: 'Enable Location Services',
    subtitle:
      'Allim uses your location while you\'re using the app to spot the stores nearby. Choose "While using the app" when Android asks.',
    bullets: [
      {
        icon: 'notifications-outline',
        title: 'Reminders at the right moment',
        detail:
          "Get your list the moment you're near a store you saved — not hours after you've driven past it.",
      },
      {
        icon: 'storefront-outline',
        title: 'Stores around you',
        detail:
          'See the supermarkets and shops nearby on the map without typing in an address.',
      },
    ],
    footnote: 'You can change this any time in Settings.',
    buttonTitle: 'Enable Location',
    request: requestLocationPermission,
  },
  backgroundLocation: {
    icon: 'navigate',
    title: 'Allow Location All the Time',
    subtitle:
      'To remind you as you pass a store — even with Allim closed — Android needs location set to "Allow all the time". Choose it on the next screen.',
    bullets: [
      {
        icon: 'car-outline',
        title: 'Works while you drive',
        detail:
          "Allim only speaks up when you're near a store you saved and there's still something on its list.",
      },
      {
        icon: 'battery-half-outline',
        title: 'Easy on your battery',
        detail:
          "Uses Android's built-in geofencing around your stores instead of tracking you continuously.",
      },
    ],
    footnote:
      'Keep "Use precise location" on so Allim can tell which store you\'re at. You can change this any time in Settings.',
    buttonTitle: 'Allow All the Time',
    request: requestBackgroundLocationPermission,
  },
  notifications: {
    icon: 'notifications',
    title: 'Turn On Notifications',
    subtitle:
      "Notifications are how a reminder actually finds you — while you're still in the store, not after you've driven home.",
    bullets: [
      {
        icon: 'cart-outline',
        title: 'Nearby store alerts',
        detail:
          'A tap-to-open list of what you still need, right as you arrive at a store.',
      },
      {
        icon: 'chatbubble-outline',
        title: 'Messages and friend requests',
        detail: 'Know when a friend messages you or sends you a request.',
      },
      {
        icon: 'people-outline',
        title: 'Shared list updates',
        detail:
          'See when someone adds to — or checks off — a list you share with them.',
      },
    ],
    footnote: 'You can fine-tune or turn these off any time in Settings.',
    buttonTitle: 'Enable Notifications',
    request: requestNotificationPermission,
  },
};

/**
 * The permission primers a new account sees between profile setup and the
 * tutorial: one screen for location, one for notifications. Port of the iOS
 * PermissionOnboardingView. Each explains what the permission buys the user,
 * and the button at the bottom is what triggers the real Android prompt — the
 * system dialog never appears unprompted.
 *
 * Answering a prompt (either way) moves the walkthrough on, so a decline can't
 * trap the user here; Settings is where they change their mind.
 */
export default function PermissionOnboardingScreen({
  steps,
  onFinished,
}: {
  steps: PermissionStep[];
  onFinished: () => void;
}) {
  const scheme = useColorScheme();
  const [index, setIndex] = useState(0);
  const [isRequesting, setIsRequesting] = useState(false);

  // Each primer slides in from the trailing edge, as the iOS walkthrough's
  // insertion transition does.
  const enter = useRef(new Animated.Value(1)).current;
  useEffect(() => {
    enter.setValue(0);
    Animated.timing(enter, {
      toValue: 1,
      duration: 350,
      useNativeDriver: true,
    }).start();
  }, [index, enter]);

  const step = steps[index];
  const content = PRIMERS[step];

  async function handlePress() {
    if (isRequesting) {
      return;
    }
    setIsRequesting(true);
    try {
      await content.request();
    } catch (_) {
      // A prompt that fails to show is treated like a decline: move on.
    }
    // A location answer can turn store-proximity alerts on.
    proximityMonitor.refresh();
    setIsRequesting(false);
    if (index + 1 < steps.length) {
      setIndex(index + 1);
    } else {
      onFinished();
    }
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}}>
        <Animated.View
          style={{
            flex: 1,
            opacity: enter,
            transform: [
              {
                translateX: enter.interpolate({
                  inputRange: [0, 1],
                  outputRange: [60, 0],
                }),
              },
            ],
          }}>
          <PrimerScaffold
            key={step}
            scheme={scheme}
            content={content}
            stepCount={steps.length}
            position={index + 1}
            isRequesting={isRequesting}
            onPress={handlePress}
          />
        </Animated.View>
      </SafeAreaView>
    </View>
  );
}

/**
 * The shared shape of both primers: an icon and a promise up top, the reasons
 * in the middle, and the one button that opens the system prompt pinned to the
 * bottom where the user's thumb already is.
 */
function PrimerScaffold({
  scheme,
  content,
  stepCount,
  position,
  isRequesting,
  onPress,
}: {
  scheme: ColorSchemeName;
  content: PrimerContent;
  stepCount: number;
  position: number;
  isRequesting: boolean;
  onPress: () => void;
}) {
  const p = profilePalette(scheme);
  return (
    <View style={{flex: 1}}>
      <ScrollView contentContainerStyle={styles.scroll} bounces={false}>
        <BlushIcon scheme={scheme} name={content.icon} />

        <View style={styles.heading}>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>{content.title}</Text>
          <Text style={[styles.subtitle, {color: textSecondary(scheme)}]}>
            {content.subtitle}
          </Text>
        </View>

        <View style={[cardStyle(scheme), styles.bulletCard]}>
          {content.bullets.map(bullet => (
            <View key={bullet.title} style={styles.bulletRow}>
              <View style={[styles.bulletIcon, {backgroundColor: p.blush}]}>
                <Icon name={bullet.icon} size={17} color={p.accent} />
              </View>
              <View style={styles.bulletText}>
                <Text style={[styles.bulletTitle, {color: textPrimary(scheme)}]}>
                  {bullet.title}
                </Text>
                <Text style={[styles.bulletDetail, {color: textSecondary(scheme)}]}>
                  {bullet.detail}
                </Text>
              </View>
            </View>
          ))}
        </View>
      </ScrollView>

      <View style={styles.footer}>
        {stepCount > 1 && (
          <StepIndicator
            scheme={scheme}
            count={stepCount}
            position={position}
          />
        )}
        <PillButton
          title={content.buttonTitle}
          onPress={onPress}
          loading={isRequesting}
          color={p.accent}
          style={styles.button}
        />
        <Text style={[styles.footnote, {color: textSecondary(scheme)}]}>
          {content.footnote}
        </Text>
      </View>
    </View>
  );
}

function StepIndicator({
  scheme,
  count,
  position,
}: {
  scheme: ColorSchemeName;
  count: number;
  position: number;
}) {
  const p = profilePalette(scheme);
  return (
    <View
      style={styles.dots}
      accessible
      accessibilityLabel={`Step ${position} of ${count}`}>
      {Array.from({length: count}, (_, i) => {
        const current = i + 1 === position;
        return (
          <View
            key={i}
            style={[
              styles.dot,
              {
                width: current ? 20 : 7,
                backgroundColor: current ? p.accent : p.outline,
              },
            ]}
          />
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  scroll: {
    alignItems: 'center',
    gap: 28,
    paddingHorizontal: 24,
    paddingTop: 44,
    paddingBottom: 28,
  },
  heading: {
    alignItems: 'center',
    gap: 12,
  },
  title: {
    fontSize: 30,
    fontWeight: '800',
    textAlign: 'center',
  },
  subtitle: {
    fontSize: 16,
    lineHeight: 22,
    textAlign: 'center',
  },
  bulletCard: {
    alignSelf: 'stretch',
    gap: 20,
    padding: 22,
    borderRadius: 24,
    marginVertical: 0,
  },
  bulletRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
  },
  bulletIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  bulletText: {
    flex: 1,
    gap: 4,
  },
  bulletTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  bulletDetail: {
    fontSize: 14,
    lineHeight: 19,
  },
  footer: {
    alignItems: 'center',
    gap: 14,
    paddingHorizontal: 24,
    paddingBottom: 20,
  },
  button: {
    alignSelf: 'stretch',
  },
  footnote: {
    fontSize: 12,
    textAlign: 'center',
    opacity: 0.85,
  },
  dots: {
    flexDirection: 'row',
    gap: 7,
  },
  dot: {
    height: 7,
    borderRadius: 3.5,
  },
});
