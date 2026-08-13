import React from 'react';
import {View, Text, StyleSheet, useColorScheme} from 'react-native';
import Icon from '@expo/vector-icons/Ionicons';
import {Colors, Spacing, Radius, cardStyle, textPrimary, textSecondary} from '../theme/AppTheme';

export default function AdBanner() {
  const scheme = useColorScheme();

  return (
    <View
      style={[
        styles.container,
        cardStyle(scheme),
        scheme !== 'dark' && {backgroundColor: Colors.backgroundBottomLight},
      ]}>
      <View style={styles.adLabel}>
        <Text style={styles.adLabelText}>AD</Text>
      </View>
      <View style={styles.content}>
        <View style={[styles.iconWrapper, {backgroundColor: Colors.blue + '22'}]}>
          <Icon name="sparkles" size={22} color={Colors.blue} />
        </View>
        <View style={styles.textWrapper}>
          <Text style={[styles.title, {color: textPrimary(scheme)}]}>
            Upgrade to Premium
          </Text>
          <Text style={[styles.subtitle, {color: textSecondary(scheme)}]}>
            Remove ads and unlock all features
          </Text>
        </View>
        <Icon name="chevron-forward" size={18} color={textSecondary(scheme)} />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    padding: Spacing.md,
    marginBottom: Spacing.md,
  },
  adLabel: {
    alignSelf: 'flex-start',
    backgroundColor: Colors.blue + '22',
    borderRadius: Radius.sm,
    paddingHorizontal: 6,
    paddingVertical: 2,
    marginBottom: Spacing.sm,
  },
  adLabelText: {
    fontSize: 10,
    fontWeight: '700',
    color: Colors.blue,
    letterSpacing: 0.5,
  },
  content: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.md,
  },
  iconWrapper: {
    width: 42,
    height: 42,
    borderRadius: Radius.md,
    alignItems: 'center',
    justifyContent: 'center',
  },
  textWrapper: {
    flex: 1,
  },
  title: {
    fontSize: 15,
    fontWeight: '600',
  },
  subtitle: {
    fontSize: 13,
    marginTop: 2,
  },
});
