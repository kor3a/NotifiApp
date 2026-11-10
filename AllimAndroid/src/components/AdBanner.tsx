import React, {useState} from 'react';
import {View, StyleSheet, StyleProp, ViewStyle} from 'react-native';
import Constants from 'expo-constants';
import {BannerAd, BannerAdSize, TestIds} from 'react-native-google-mobile-ads';

import {useSession} from '../context/SessionContext';
import {hasPremiumAccess} from '../services/subscription';

// The AdMob banner unit for release builds (app.config.js → extra). Debug
// builds always ask for Google's test banner instead, so nobody working on the
// app loads — or taps — a real ad, which AdMob treats as invalid traffic.
const RELEASE_BANNER_ID: string =
  (Constants.expoConfig?.extra as any)?.admobBannerId ?? TestIds.BANNER;
const BANNER_UNIT_ID = __DEV__ ? TestIds.BANNER : RELEASE_BANNER_ID;

// iOS AdSizeBanner, the fixed 320×50 the iOS app reserves for it.
const BANNER_HEIGHT = 50;

// Port of iOS BannerAdView: a Google AdMob banner for accounts without
// Premium. Subscribers (and admin-granted Premium) get nothing, so screens can
// place this unconditionally. Until an ad arrives the 50pt strip is held, as
// iOS's fixed frame does; if none can be loaded it collapses rather than
// leaving an empty band.
export default function AdBanner({
  backgroundColor,
  style,
}: {
  // The strip behind the 320pt-wide ad on wider screens — the canvas colour
  // where the banner is pinned above the tab bar, as on iOS.
  backgroundColor?: string;
  style?: StyleProp<ViewStyle>;
}) {
  const {currentUser} = useSession();
  const [failed, setFailed] = useState(false);

  if (!currentUser || hasPremiumAccess(currentUser) || failed) {
    return null;
  }

  return (
    <View style={[styles.container, backgroundColor ? {backgroundColor} : null, style]}>
      <BannerAd
        unitId={BANNER_UNIT_ID}
        size={BannerAdSize.BANNER}
        onAdFailedToLoad={error => {
          if (__DEV__) {
            console.warn('AdMob: banner failed to load —', error.message);
          }
          setFailed(true);
        }}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    height: BANNER_HEIGHT,
    alignItems: 'center',
    justifyContent: 'center',
    overflow: 'hidden',
  },
});
