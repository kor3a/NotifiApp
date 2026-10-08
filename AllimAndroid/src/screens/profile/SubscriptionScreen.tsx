import React, {useState} from 'react';
import {
  View,
  Text,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  Alert,
  Linking,
  Platform,
  useColorScheme,
  ColorSchemeName,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import {useNavigation} from '@react-navigation/native';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {Colors, cardBackground, cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {PRIVACY_POLICY_URL} from './AboutScreen';
import {profilePalette} from './profileUi';

type IconName = React.ComponentProps<typeof Icon>['name'];

const GOOGLE_PLAY_TERMS_URL = 'https://play.google.com/about/play-terms/';

// iOS SubscriptionManager.freeStoreLimit.
const FREE_STORE_LIMIT = 5;

// iOS PremiumFeature.all, with Ionicons standing in for the SF Symbols:
// infinity -> infinite, fork.knife -> restaurant, sparkles -> sparkles,
// hand.thumbsup.fill -> thumbs-up.
const PREMIUM_FEATURES: {icon: IconName; title: string; description: string}[] = [
  {
    icon: 'infinite',
    title: 'Unlimited Stores',
    description: `Free accounts are limited to ${FREE_STORE_LIMIT} stores of your own — go unlimited with Premium`,
  },
  {
    icon: 'restaurant',
    title: 'Smart Recipe',
    description: 'Ask for any recipe and add ingredients directly to your stores',
  },
  {
    icon: 'sparkles',
    title: 'Smart Category',
    description: 'AI auto-categorizes every item you add to your shopping list',
  },
  {
    icon: 'thumbs-up',
    title: 'Ad-Free Experience',
    description: 'Enjoy the app without any banner advertisements',
  },
];

type PlanId = 'monthly' | 'annual';

// Google Play Billing isn't wired up yet, so these are the list prices the
// App Store products carry rather than ones fetched from the store.
const PLANS: Record<PlanId, {title: string; price: number; period: string}> = {
  monthly: {title: 'Monthly', price: 0.99, period: 'per month'},
  annual: {title: 'Annual', price: 10.0, period: 'per year'},
};

// Savings % compared to paying monthly for a full year, as on iOS.
function savingsPercent(): number | null {
  const monthlyAnnualized = PLANS.monthly.price * 12;
  const pct = ((monthlyAnnualized - PLANS.annual.price) / monthlyAnnualized) * 100;
  return pct > 0 ? Math.round(pct) : null;
}

// Port of iOS SubscriptionPaywallView.
export default function SubscriptionScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const navigation = useNavigation();
  const [selectedPlan, setSelectedPlan] = useState<PlanId>('annual');

  const savings = savingsPercent();

  function showUnavailable() {
    Alert.alert(
      'Coming Soon',
      'Allim Premium subscriptions through Google Play aren’t available yet. Check back in a future update.',
    );
  }

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right', 'bottom']}>
        <View style={styles.header}>
          <TouchableOpacity
            onPress={() => navigation.goBack()}
            hitSlop={{top: 10, bottom: 10, left: 10, right: 10}}>
            <Text style={[styles.closeText, {color: p.accent}]}>Close</Text>
          </TouchableOpacity>
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
            <Text style={[styles.heroSubtitle, {color: textSecondary(scheme)}]}>
              Unlock the full experience
            </Text>
          </View>

          {/* Features — every glyph accent on blush rather than a colour per
              feature, as on iOS. */}
          <View style={[cardStyle(scheme), styles.featureCard]}>
            {PREMIUM_FEATURES.map(feature => (
              <View key={feature.title} style={styles.featureRow}>
                <View style={[styles.featureIcon, {backgroundColor: p.blush}]}>
                  <Icon name={feature.icon} size={17} color={p.accent} />
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

          {/* Plans */}
          <View style={styles.plans}>
            <PlanCard
              scheme={scheme}
              title={PLANS.monthly.title}
              price={formatPrice(PLANS.monthly.price)}
              period={PLANS.monthly.period}
              trialText="7-day free trial"
              selected={selectedPlan === 'monthly'}
              onPress={() => setSelectedPlan('monthly')}
            />
            <PlanCard
              scheme={scheme}
              title={PLANS.annual.title}
              price={formatPrice(PLANS.annual.price)}
              period={PLANS.annual.period}
              badge={savings !== null ? `Save ${savings}%` : 'Best Value'}
              trialText="7-day free trial"
              selected={selectedPlan === 'annual'}
              onPress={() => setSelectedPlan('annual')}
            />
          </View>

          {/* Subscribe — two lines of type in the accent capsule. */}
          <TouchableOpacity
            onPress={showUnavailable}
            activeOpacity={0.85}
            style={[styles.subscribe, {backgroundColor: p.accent}]}>
            <Text style={styles.subscribeTitle}>Start Free Trial</Text>
            <Text style={styles.subscribeSubtitle}>7 days free, then auto-renews</Text>
          </TouchableOpacity>

          <TouchableOpacity onPress={showUnavailable} style={styles.restore}>
            <Text style={[styles.restoreText, {color: textSecondary(scheme)}]}>
              Restore Purchases
            </Text>
          </TouchableOpacity>

          {/* Legal */}
          <View style={styles.legal}>
            <Text style={[styles.legalText, {color: textSecondary(scheme)}]}>
              Subscription renews automatically unless cancelled at least 24 hours before
              the end of the current period. Manage or cancel anytime in Google Play
              Settings.
            </Text>
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

function formatPrice(price: number) {
  return `$${price.toFixed(2)}`;
}

function PlanCard({
  scheme,
  title,
  price,
  period,
  badge,
  trialText,
  selected,
  onPress,
}: {
  scheme: ColorSchemeName;
  title: string;
  price: string;
  period: string;
  badge?: string;
  trialText?: string;
  selected: boolean;
  onPress: () => void;
}) {
  const p = profilePalette(scheme);
  const onAccent = Colors.white;

  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.85}
      accessibilityRole="radio"
      accessibilityState={{selected}}
      style={styles.planWrapper}>
      <View
        style={[
          styles.planCard,
          shadow(scheme),
          {backgroundColor: selected ? p.accent : cardBackground(scheme)},
          badge ? {paddingTop: 30} : null,
        ]}>
        <Text
          style={[styles.planTitle, {color: selected ? onAccent : textSecondary(scheme)}]}>
          {title}
        </Text>
        <Text
          style={[styles.planPrice, {color: selected ? onAccent : textPrimary(scheme)}]}>
          {price}
        </Text>
        <Text
          style={[
            styles.planPeriod,
            selected ? {color: onAccent, opacity: 0.8} : {color: textSecondary(scheme)},
          ]}>
          {period}
        </Text>
        {trialText ? (
          <View
            style={[
              styles.trial,
              {backgroundColor: selected ? 'rgba(255,255,255,0.22)' : p.sage},
            ]}>
            <Text style={[styles.trialText, {color: selected ? onAccent : p.sageInk}]}>
              {trialText}
            </Text>
          </View>
        ) : null}
      </View>

      {badge ? (
        <View style={[styles.badge, {backgroundColor: p.sage}]}>
          <Text style={[styles.badgeText, {color: p.sageInk}]}>{badge}</Text>
        </View>
      ) : null}
    </TouchableOpacity>
  );
}

// The plan cards swap their fill on selection, so they take cardStyle's
// shadow without its border — a pale border reads as a ring on the accent.
function shadow(scheme: ColorSchemeName) {
  return Platform.select({
    ios: {
      shadowColor: Colors.black,
      shadowOffset: {width: 0, height: 4},
      shadowOpacity: scheme === 'dark' ? 0.3 : 0.1,
      shadowRadius: 10,
    },
    android: {elevation: 3},
    default: {},
  });
}

const styles = StyleSheet.create({
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 20,
    height: 52,
  },
  closeText: {
    fontSize: 17,
    fontWeight: '600',
  },
  scroll: {
    paddingTop: 8,
    paddingBottom: 16,
    gap: 24,
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
  heroSubtitle: {
    fontSize: 16,
  },
  featureCard: {
    marginHorizontal: 20,
    marginVertical: 0,
    padding: 20,
    borderRadius: 28,
    gap: 18,
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
  plans: {
    flexDirection: 'row',
    gap: 12,
    // Centred like the iOS HStack, so the shorter monthly card doesn't
    // stretch to the badged annual one.
    alignItems: 'center',
    paddingHorizontal: 20,
    // Room for the badge that straddles the annual card's top edge.
    paddingTop: 10,
  },
  planWrapper: {
    flex: 1,
  },
  planCard: {
    alignItems: 'center',
    gap: 6,
    paddingVertical: 20,
    borderRadius: 24,
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
  trial: {
    borderRadius: 999,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  trialText: {
    fontSize: 11,
    fontWeight: '600',
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
  subscribe: {
    marginHorizontal: 20,
    borderRadius: 999,
    paddingVertical: 16,
    alignItems: 'center',
    gap: 2,
  },
  subscribeTitle: {
    color: Colors.white,
    fontSize: 17,
    fontWeight: '700',
  },
  subscribeSubtitle: {
    color: Colors.white,
    fontSize: 12,
    opacity: 0.85,
  },
  restore: {
    alignSelf: 'center',
    paddingVertical: 4,
  },
  restoreText: {
    fontSize: 15,
    fontWeight: '600',
  },
  legal: {
    paddingHorizontal: 24,
    paddingBottom: 16,
    gap: 8,
    alignItems: 'center',
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
