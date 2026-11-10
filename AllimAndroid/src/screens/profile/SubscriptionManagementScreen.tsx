import React from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Linking,
  useColorScheme,
  ColorSchemeName,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import Constants from 'expo-constants';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {useSession} from '../../context/SessionContext';
import {PRIVACY_POLICY_URL} from './AboutScreen';
import {PillButton, SectionLabel, profilePalette} from './profileUi';
import {
  GOOGLE_PLAY_TERMS_URL,
  PLANS,
  PREMIUM_FEATURES,
  formatPrice,
  savingsPercent,
} from './premium';

const PACKAGE_NAME = Constants.expoConfig?.android?.package ?? 'com.allimandroid';

// Google Play's own subscriptions page, filtered to this app. Without a `sku`
// it lists the app's subscriptions, where the user can change plan or cancel.
const PLAY_SUBSCRIPTIONS_URL = `https://play.google.com/store/account/subscriptions?package=${PACKAGE_NAME}`;

// Apple's guide to cancelling or changing an App Store subscription. An
// Android phone can't open App Store settings, so this is the closest thing.
const APPLE_SUBSCRIPTIONS_HELP_URL = 'https://support.apple.com/en-us/118428';

// Port of iOS SubscriptionManagementView: what Premium gives you, the plans,
// and the way out to the store that bills you to change plan or cancel.
//
// iOS opens App Store subscription settings directly. Android can't know which
// store holds the subscription — Firestore only records that the account is
// subscribed, and Google Play Billing isn't integrated yet, so today it will
// have been bought on an iPhone or iPad — so Manage and Cancel ask which store.
export default function SubscriptionManagementScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const navigation = useNavigation();
  const {currentUser} = useSession();

  // Premium granted by Allim rather than bought has no store subscription
  // behind it — nothing to change and nothing to cancel.
  // Strict `true` checks, as hasPremiumAccess uses.
  const isGranted =
    currentUser?.adminSubscribed === true && currentUser?.isSubscribed !== true;

  const savings = savingsPercent();

  function open(url: string) {
    Linking.openURL(url).catch(() =>
      Alert.alert(
        'Unable to Open Settings',
        'Could not open subscription settings. Open the Google Play Store, tap your profile picture, then Payments & subscriptions > Subscriptions.',
      ),
    );
  }

  function openSubscriptionSettings() {
    Alert.alert(
      'Manage Subscription',
      'Allim Premium is billed by the store you subscribed through. Where did you subscribe?',
      [
        {text: 'Cancel', style: 'cancel'},
        {text: 'iPhone or iPad', onPress: () => open(APPLE_SUBSCRIPTIONS_HELP_URL)},
        {text: 'Google Play', onPress: () => open(PLAY_SUBSCRIPTIONS_URL)},
      ],
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right', 'bottom']}>
        <View style={styles.header}>
          <View style={styles.headerSide}>
            <TouchableOpacity
              onPress={() => navigation.goBack()}
              hitSlop={{top: 10, bottom: 10, left: 10, right: 10}}>
              <Text style={[styles.closeText, {color: p.accent}]}>Close</Text>
            </TouchableOpacity>
          </View>
          <Text style={[styles.headerTitle, {color: textPrimary(scheme)}]}>Subscription</Text>
          <View style={styles.headerSide} />
        </View>

        <ScrollView contentContainerStyle={styles.scroll}>
          {/* Hero */}
          <View style={styles.hero}>
            <View style={[styles.heroIcon, {backgroundColor: p.blush}]}>
              <Icon name="diamond" size={42} color={p.accent} />
            </View>
            <Text style={[styles.heroTitle, {color: textPrimary(scheme)}]}>
              Allim Premium
            </Text>
            <View style={[styles.activeBadge, {backgroundColor: p.sage}]}>
              <Text style={[styles.activeText, {color: p.sageInk}]}>
                {isGranted ? 'PREMIUM INCLUDED' : 'ACTIVE SUBSCRIPTION'}
              </Text>
            </View>
          </View>

          {/* Features — the paywall's list, once you own it. Sage rather than
              blush here, as on iOS. */}
          <View style={[cardStyle(scheme), styles.featureCard]}>
            <Text style={[styles.featureHeading, {color: textPrimary(scheme)}]}>
              Your Premium features
            </Text>
            {PREMIUM_FEATURES.map(feature => (
              <View key={feature.title} style={styles.featureRow}>
                <View style={[styles.featureIcon, {backgroundColor: p.sage}]}>
                  <Icon name={feature.icon} size={16} color={p.sageInk} />
                </View>
                <View style={styles.featureText}>
                  <Text style={[styles.featureTitle, {color: textPrimary(scheme)}]}>
                    {feature.title}
                  </Text>
                  <Text style={[styles.featureDescription, {color: textSecondary(scheme)}]}>
                    {feature.description}
                  </Text>
                </View>
              </View>
            ))}
          </View>

          {isGranted ? (
            <Text style={[styles.grantedNote, {color: textSecondary(scheme)}]}>
              Premium was added to your account by Allim, so there's no subscription to
              change or cancel and you won't be charged for it.
            </Text>
          ) : (
            <>
              {/* Plans — Android can't tell which one is active yet, so neither
                  is marked as current; the store's settings switch between them. */}
              <View style={styles.planSection}>
                <SectionLabel scheme={scheme} title="Plans" />
                <View style={styles.plans}>
                  <PlanCard
                    scheme={scheme}
                    title={PLANS.monthly.title}
                    price={formatPrice(PLANS.monthly.price)}
                    period={PLANS.monthly.period}
                  />
                  <PlanCard
                    scheme={scheme}
                    title={PLANS.annual.title}
                    price={formatPrice(PLANS.annual.price)}
                    period={PLANS.annual.period}
                    badge={savings !== null ? `Save ${savings}%` : undefined}
                  />
                </View>
                <Text style={[styles.planHint, {color: textSecondary(scheme)}]}>
                  Switch between monthly and annual from your subscription settings.
                </Text>
              </View>

              <PillButton
                title="Manage Subscription"
                onPress={openSubscriptionSettings}
                style={styles.manage}
              />

              {/* Cancel */}
              <View style={styles.cancel}>
                <TouchableOpacity onPress={openSubscriptionSettings} hitSlop={8}>
                  <Text style={[styles.cancelText, {color: p.rust}]}>
                    Cancel Subscription
                  </Text>
                </TouchableOpacity>
                <Text style={[styles.cancelHint, {color: textSecondary(scheme)}]}>
                  To cancel, tap above and turn off auto-renewal for Allim Premium — in
                  Google Play, or if you subscribed on an iPhone or iPad, in Settings
                  {' > '}Apple ID{' > '}Subscriptions on that device.
                </Text>
              </View>
            </>
          )}

          {/* Legal */}
          <View style={styles.legal}>
            {!isGranted && (
              <>
                <Text style={[styles.legalTitle, {color: textSecondary(scheme)}]}>
                  Allim Premium · Subscription
                </Text>
                <Text style={[styles.legalText, {color: textSecondary(scheme)}]}>
                  Subscription auto-renews unless cancelled at least 24 hours before the
                  end of the current period. Manage or cancel anytime in the subscription
                  settings of the store you subscribed through.
                </Text>
              </>
            )}
            <View style={styles.legalLinks}>
              <Text
                style={[styles.legalLink, {color: p.accent}]}
                onPress={() => Linking.openURL(GOOGLE_PLAY_TERMS_URL)}>
                Terms of Use
              </Text>
              <Text style={[styles.legalText, {color: textSecondary(scheme)}]}>
                {'·'}
              </Text>
              <Text
                style={[styles.legalLink, {color: p.accent}]}
                onPress={() => Linking.openURL(PRIVACY_POLICY_URL)}>
                Privacy Policy
              </Text>
            </View>
          </View>
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

// iOS planComparisonCard, in its not-current state.
function PlanCard({
  scheme,
  title,
  price,
  period,
  badge,
}: {
  scheme: ColorSchemeName;
  title: string;
  price: string;
  period: string;
  badge?: string;
}) {
  const p = profilePalette(scheme);
  return (
    <View style={styles.planWrapper}>
      <View
        style={[
          cardStyle(scheme),
          styles.planCard,
          badge ? {paddingTop: 28} : null,
        ]}>
        <Text style={[styles.planTitle, {color: textSecondary(scheme)}]}>{title}</Text>
        <Text style={[styles.planPrice, {color: textPrimary(scheme)}]}>{price}</Text>
        <Text style={[styles.planPeriod, {color: textSecondary(scheme)}]}>{period}</Text>
      </View>
      {badge ? (
        <View style={[styles.badge, {backgroundColor: p.sage}]}>
          <Text style={[styles.badgeText, {color: p.sageInk}]}>{badge}</Text>
        </View>
      ) : null}
    </View>
  );
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    height: 52,
  },
  headerSide: {
    width: 64,
  },
  headerTitle: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '700',
  },
  closeText: {
    fontSize: 17,
    fontWeight: '600',
  },
  scroll: {
    paddingTop: 16,
    paddingBottom: 16,
    gap: 26,
  },
  hero: {
    alignItems: 'center',
    gap: 12,
  },
  heroIcon: {
    width: 104,
    height: 104,
    borderRadius: 52,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroTitle: {
    fontSize: 32,
    fontWeight: '800',
  },
  activeBadge: {
    borderRadius: 999,
    paddingHorizontal: 12,
    paddingVertical: 5,
  },
  activeText: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 0.6,
  },
  featureCard: {
    marginHorizontal: 20,
    marginVertical: 0,
    padding: 20,
    borderRadius: 28,
    gap: 18,
  },
  featureHeading: {
    fontSize: 20,
    fontWeight: '800',
  },
  featureRow: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 14,
  },
  featureIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  featureText: {
    flex: 1,
    gap: 3,
  },
  featureTitle: {
    fontSize: 16,
    fontWeight: '600',
  },
  featureDescription: {
    fontSize: 13,
    lineHeight: 17,
  },
  grantedNote: {
    fontSize: 14,
    lineHeight: 19,
    textAlign: 'center',
    paddingHorizontal: 28,
  },
  planSection: {
    paddingHorizontal: 20,
    gap: 10,
  },
  plans: {
    flexDirection: 'row',
    gap: 12,
    alignItems: 'center',
    // Room for the badge that straddles the annual card's top edge.
    paddingTop: 10,
  },
  planWrapper: {
    flex: 1,
  },
  planCard: {
    alignItems: 'center',
    gap: 6,
    paddingVertical: 18,
    borderRadius: 24,
    marginVertical: 0,
  },
  planTitle: {
    fontSize: 15,
    fontWeight: '600',
  },
  planPrice: {
    fontSize: 24,
    fontWeight: '800',
  },
  planPeriod: {
    fontSize: 13,
  },
  planHint: {
    fontSize: 13,
    lineHeight: 17,
  },
  badge: {
    position: 'absolute',
    top: -10,
    right: 10,
    borderRadius: 999,
    paddingHorizontal: 9,
    paddingVertical: 4,
    elevation: 4,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '700',
  },
  manage: {
    marginHorizontal: 20,
  },
  cancel: {
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 24,
  },
  cancelText: {
    fontSize: 15,
    fontWeight: '600',
  },
  cancelHint: {
    fontSize: 13,
    lineHeight: 18,
    textAlign: 'center',
  },
  legal: {
    paddingHorizontal: 24,
    paddingBottom: 16,
    gap: 10,
    alignItems: 'center',
  },
  legalTitle: {
    fontSize: 12,
    fontWeight: '600',
  },
  legalText: {
    fontSize: 12,
    lineHeight: 16,
    textAlign: 'center',
  },
  legalLinks: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  legalLink: {
    fontSize: 12,
    fontWeight: '600',
  },
});
