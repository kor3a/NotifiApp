import React from 'react';
import {View, Text, ScrollView, StyleSheet, Linking, useColorScheme} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import Constants from 'expo-constants';
import Icon from '../../components/AppIcon';

import GradientBackground from '../../components/GradientBackground';
import {cardStyle, textPrimary, textSecondary} from '../../theme/AppTheme';
import {
  ProfileHeader,
  SectionLabel,
  NavRow,
  profilePalette,
  profileStyles,
} from './profileUi';

// The policy the website links to. iOS renders the same text in-app.
const PRIVACY_POLICY_URL = 'https://github.com/kor3a/allim-privacy-policy';

export function appVersionLabel(): string {
  const version = Constants.expoConfig?.version ?? '1.0';
  const build = Constants.expoConfig?.android?.versionCode ?? 1;
  return `${version} (${build})`;
}

// Port of iOS AboutView.
export default function AboutScreen() {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);

  return (
    <View style={{flex: 1}}>
      <GradientBackground />
      <SafeAreaView style={{flex: 1}} edges={['top', 'left', 'right']}>
        <ProfileHeader scheme={scheme} title="About" />
        <ScrollView contentContainerStyle={profileStyles.scroll}>
          <View style={styles.hero}>
            <View style={[styles.heroIcon, {backgroundColor: p.blush}]}>
              <Icon name="cart" size={40} color={p.accent} />
            </View>
            <Text style={[styles.appName, {color: textPrimary(scheme)}]}>Allim</Text>
            <Text style={[styles.tagline, {color: textSecondary(scheme)}]}>
              Smart Shopping List
            </Text>
            <Text style={[styles.version, {color: textSecondary(scheme)}]}>
              Version {appVersionLabel()}
            </Text>
          </View>

          <View style={profileStyles.section}>
            <SectionLabel scheme={scheme} title="What it does" />
            <View style={[cardStyle(scheme), styles.blurbCard]}>
              <Text style={[styles.blurb, {color: textSecondary(scheme)}]}>
                Allim keeps your grocery lists tied to the places you actually shop. Save a
                store, add what you need, and Allim reminds you when you're nearby — so
                nothing gets left behind.
              </Text>
            </View>
          </View>

          <View style={profileStyles.section}>
            <SectionLabel scheme={scheme} title="Legal" />
            <NavRow
              scheme={scheme}
              icon="hand-left"
              title="Privacy Policy"
              subtitle="What we collect, and what we never do with it"
              accessory="open-outline"
              onPress={() => Linking.openURL(PRIVACY_POLICY_URL)}
            />
          </View>
        </ScrollView>
      </SafeAreaView>
    </View>
  );
}

const styles = StyleSheet.create({
  hero: {
    alignItems: 'center',
    gap: 12,
    paddingVertical: 24,
  },
  heroIcon: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
  },
  appName: {
    fontSize: 30,
    fontWeight: '800',
  },
  tagline: {
    fontSize: 16,
    fontWeight: '600',
  },
  version: {
    fontSize: 13,
    opacity: 0.8,
  },
  blurbCard: {
    padding: 18,
    borderRadius: 22,
    marginVertical: 0,
  },
  blurb: {
    fontSize: 16,
    lineHeight: 22,
  },
});
