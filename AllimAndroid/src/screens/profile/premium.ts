import React from 'react';
import Icon from '../../components/AppIcon';
import {FREE_STORE_LIMIT} from '../../services/subscription';

// What the paywall sells and the management screen lists once you own it,
// kept in one place so the two never drift apart (iOS PremiumFeature.all).

type IconName = React.ComponentProps<typeof Icon>['name'];

export const GOOGLE_PLAY_TERMS_URL = 'https://play.google.com/about/play-terms/';

// iOS PremiumFeature.all, with Ionicons standing in for the SF Symbols:
// infinity -> infinite, fork.knife -> restaurant, sparkles -> sparkles,
// hand.thumbsup.fill -> thumbs-up.
export const PREMIUM_FEATURES: {icon: IconName; title: string; description: string}[] = [
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

export type PlanId = 'monthly' | 'annual';

// Google Play Billing isn't wired up yet, so these are the list prices the
// App Store products carry rather than ones fetched from the store.
export const PLANS: Record<PlanId, {title: string; price: number; period: string}> = {
  monthly: {title: 'Monthly', price: 0.99, period: 'per month'},
  annual: {title: 'Annual', price: 10.0, period: 'per year'},
};

// Savings % compared to paying monthly for a full year, as on iOS.
export function savingsPercent(): number | null {
  const monthlyAnnualized = PLANS.monthly.price * 12;
  const pct = ((monthlyAnnualized - PLANS.annual.price) / monthlyAnnualized) * 100;
  return pct > 0 ? Math.round(pct) : null;
}

export function formatPrice(price: number) {
  return `$${price.toFixed(2)}`;
}
