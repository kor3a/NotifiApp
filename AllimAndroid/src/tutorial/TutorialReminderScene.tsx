import React, {useEffect, useRef} from 'react';
import {
  Animated,
  StyleSheet,
  Text,
  View,
  useColorScheme,
  ColorSchemeName,
} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import Icon from '../components/AppIcon';
import GradientBackground from '../components/GradientBackground';
import {Colors, cardStyle, textPrimary, textSecondary} from '../theme/AppTheme';
import {profilePalette} from '../screens/profile/profileUi';
import {TutorialStepId} from './tutorialManager';

type IconName = React.ComponentProps<typeof Icon>['name'];

type MockReminder = {title: string; quantity?: number; isDone?: boolean};
type MockCategory = {name: string; icon: IconName; items: MockReminder[]};

const CATEGORIES: MockCategory[] = [
  {
    name: 'Produce',
    icon: 'leaf-outline',
    items: [
      {title: 'Bananas', quantity: 2},
      {title: 'Baby Spinach'},
      {title: 'Avocados', quantity: 3},
    ],
  },
  {
    name: 'Dairy',
    icon: 'cafe-outline',
    items: [{title: 'Whole Milk'}, {title: 'Greek Yogurt', isDone: true}],
  },
  {
    name: 'Bakery',
    icon: 'basket-outline',
    items: [{title: 'Sourdough Bread'}],
  },
];

// The reminder the "hold for shortcuts" step anchors its menu to.
const ANCHOR = CATEGORIES[0].items[0];

/**
 * A self-contained, non-interactive mock of the Reminders screen used by the
 * tutorial. Port of the iOS TutorialReminderScene: it draws over the live app
 * (which stays on the Stores tab) so the tour can walk through a reminder list
 * without real data or pushing the real screen. Each step emphasises one
 * feature — auto-categorised items, the info (i) list menu, and the
 * touch-and-hold item menu.
 */
export default function TutorialReminderScene({step}: {step: TutorialStepId}) {
  const scheme = useColorScheme();
  const p = profilePalette(scheme);
  const insets = useSafeAreaInsets();

  const pulse = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {toValue: 1, duration: 1100, useNativeDriver: true}),
        Animated.timing(pulse, {toValue: 0, duration: 1100, useNativeDriver: true}),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [pulse]);

  const pulseOpacity = pulse.interpolate({inputRange: [0, 1], outputRange: [0.3, 1]});
  const pulseScale = pulse.interpolate({inputRange: [0, 1], outputRange: [0.9, 1.15]});

  return (
    <View style={StyleSheet.absoluteFill}>
      {/* Opaque, so the scene fully covers the live app. */}
      <GradientBackground />

      {/* Navigation bar */}
      <View style={[styles.navBar, {paddingTop: insets.top + 6, borderBottomColor: p.outline}]}>
        <View style={styles.navBack}>
          <Icon name="chevron-back" size={24} color={p.accent} />
          <Text style={[styles.navBackText, {color: p.accent}]}>Stores</Text>
        </View>
        <View style={styles.navTitleBlock}>
          <Text style={[styles.navTitle, {color: textPrimary(scheme)}]}>Whole Foods</Text>
          <Text style={[styles.navSubtitle, {color: textSecondary(scheme)}]}>6 items</Text>
        </View>
        <View style={styles.navInfo}>
          {step === 'remindersInfoMenu' && (
            <Animated.View
              style={[
                styles.navInfoPulse,
                {backgroundColor: p.blush, transform: [{scale: pulseScale}]},
              ]}
            />
          )}
          <Icon
            name={step === 'remindersInfoMenu' ? 'information-circle' : 'information-circle-outline'}
            size={24}
            color={p.accent}
          />
        </View>
      </View>

      {/* Reminders */}
      <View style={styles.list}>
        {CATEGORIES.map(category => (
          <View key={category.name} style={styles.section}>
            <View style={styles.categoryHeader}>
              {step === 'remindersCategories' && (
                <Animated.View
                  style={[
                    StyleSheet.absoluteFill,
                    styles.categoryGlow,
                    {borderColor: p.accent, backgroundColor: p.blush, opacity: pulseOpacity},
                  ]}
                />
              )}
              <Icon name={category.icon} size={16} color={p.accent} style={styles.categoryIcon} />
              <Text style={[styles.categoryName, {color: textPrimary(scheme)}]}>
                {category.name}
              </Text>
              <View style={styles.countBadge}>
                <Text style={styles.countText}>{category.items.length}</Text>
              </View>
              <View style={{flex: 1}} />
              <Icon name="chevron-down" size={15} color={textSecondary(scheme)} />
            </View>

            {category.items.map(item => (
              <ReminderRow
                key={item.title}
                scheme={scheme}
                item={item}
                isAnchor={step === 'remindersItemMenu' && item === ANCHOR}
                pulseOpacity={pulseOpacity}
              />
            ))}
          </View>
        ))}
      </View>

      {step === 'remindersInfoMenu' && (
        <Animated.View
          style={[
            styles.infoMenuWrap,
            {top: insets.top + 58},
          ]}>
          <InfoMenu scheme={scheme} pulseOpacity={pulseOpacity} />
        </Animated.View>
      )}

      {step === 'remindersItemMenu' && (
        <View style={[styles.itemMenuWrap, {top: insets.top + 174}]}>
          <ItemShortcutMenu scheme={scheme} />
        </View>
      )}
    </View>
  );
}

function ReminderRow({
  scheme,
  item,
  isAnchor,
  pulseOpacity,
}: {
  scheme: ColorSchemeName;
  item: MockReminder;
  isAnchor: boolean;
  pulseOpacity: Animated.AnimatedInterpolation<number>;
}) {
  const p = profilePalette(scheme);
  const ink = item.isDone ? textSecondary(scheme) : textPrimary(scheme);
  return (
    <View
      style={[
        cardStyle(scheme),
        styles.row,
        isAnchor && styles.rowAnchor,
      ]}>
      {isAnchor && (
        <Animated.View
          style={[
            StyleSheet.absoluteFill,
            styles.rowGlow,
            {borderColor: p.accent, opacity: pulseOpacity},
          ]}
        />
      )}
      <Icon name={item.isDone ? 'checkbox-outline' : 'square-outline'} size={22} color={ink} />
      <Text
        style={[
          styles.rowTitle,
          {color: ink, textDecorationLine: item.isDone ? 'line-through' : 'none'},
        ]}>
        {item.title}
      </Text>
      {item.quantity != null && (
        <View style={[styles.qty, {backgroundColor: p.field}]}>
          <Text style={[styles.qtyText, {color: textSecondary(scheme)}]}>
            Qty: {item.quantity}
          </Text>
        </View>
      )}
    </View>
  );
}

function InfoMenu({
  scheme,
  pulseOpacity,
}: {
  scheme: ColorSchemeName;
  pulseOpacity: Animated.AnimatedInterpolation<number>;
}) {
  const p = profilePalette(scheme);
  const rows: {
    icon: IconName;
    title: string;
    subtitle: string;
    trailing: {toggle: boolean} | 'chevron' | 'arrow';
  }[] = [
    {icon: 'trash-outline', title: 'Auto Delete', subtitle: 'Delete checked items automatically', trailing: {toggle: false}},
    {icon: 'sparkles', title: 'Smart Category', subtitle: 'AI auto-categorizes new items', trailing: {toggle: true}},
    {icon: 'restaurant-outline', title: 'Recipes', subtitle: 'Add ingredients from a saved recipe', trailing: 'chevron'},
    {icon: 'compass-outline', title: 'Visit store', subtitle: "Open the store's app or website", trailing: 'arrow'},
  ];
  return (
    <View style={[cardStyle(scheme), styles.menu, {width: 300}]}>
      <Animated.View
        style={[
          StyleSheet.absoluteFill,
          styles.menuGlow,
          {borderColor: p.accent, opacity: pulseOpacity},
        ]}
      />
      {rows.map((row, i) => (
        <View key={row.title}>
          {i > 0 && <View style={[styles.menuDivider, {backgroundColor: p.outline}]} />}
          <View style={styles.infoRow}>
            <View style={[styles.infoIcon, {backgroundColor: p.blush}]}>
              <Icon name={row.icon} size={15} color={p.accent} />
            </View>
            <View style={{flex: 1, gap: 2}}>
              <Text style={[styles.infoTitle, {color: textPrimary(scheme)}]}>{row.title}</Text>
              <Text style={[styles.infoSubtitle, {color: textSecondary(scheme)}]}>
                {row.subtitle}
              </Text>
            </View>
            {typeof row.trailing === 'object' ? (
              // Static toggle mock (non-interactive).
              <View
                style={[
                  styles.toggle,
                  {
                    backgroundColor: row.trailing.toggle ? p.accent : p.field,
                    alignItems: row.trailing.toggle ? 'flex-end' : 'flex-start',
                  },
                ]}>
                <View style={styles.toggleKnob} />
              </View>
            ) : (
              <Icon
                name={row.trailing === 'chevron' ? 'chevron-forward' : 'open-outline'}
                size={14}
                color={textSecondary(scheme)}
                style={{opacity: 0.7}}
              />
            )}
          </View>
        </View>
      ))}
    </View>
  );
}

function ItemShortcutMenu({scheme}: {scheme: ColorSchemeName}) {
  const p = profilePalette(scheme);
  const rows: {title: string; icon: IconName; submenu?: boolean}[] = [
    {title: 'Out of Stock', icon: 'close-circle-outline'},
    {title: 'Move to Store', icon: 'arrow-redo-outline', submenu: true},
    {title: 'Add Photos', icon: 'images-outline'},
    {title: 'Add Quantity', icon: 'calculator-outline'},
    {title: 'Change Category', icon: 'pricetag-outline'},
  ];
  return (
    <View style={[cardStyle(scheme), styles.menu, {width: 240}]}>
      {rows.map((row, i) => (
        <View key={row.title}>
          {i > 0 && <View style={[styles.menuDivider, {backgroundColor: p.outline}]} />}
          <View style={styles.shortcutRow}>
            <Text style={[styles.shortcutTitle, {color: textPrimary(scheme)}]}>{row.title}</Text>
            {row.submenu && (
              <Icon
                name="chevron-forward"
                size={14}
                color={textSecondary(scheme)}
                style={{marginRight: 6}}
              />
            )}
            <Icon name={row.icon} size={18} color={textPrimary(scheme)} />
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  navBar: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 12,
    paddingBottom: 10,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  navBack: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 2,
  },
  navBackText: {
    fontSize: 17,
  },
  navTitleBlock: {
    alignItems: 'center',
    gap: 1,
  },
  navTitle: {
    fontSize: 17,
    fontWeight: '700',
  },
  navSubtitle: {
    fontSize: 12,
  },
  navInfo: {
    flex: 1,
    alignItems: 'flex-end',
    justifyContent: 'center',
    height: 44,
    paddingRight: 10,
  },
  navInfoPulse: {
    position: 'absolute',
    right: 2,
    width: 40,
    height: 40,
    borderRadius: 20,
  },
  list: {
    paddingHorizontal: 14,
    paddingTop: 12,
    gap: 10,
  },
  section: {
    gap: 10,
  },
  categoryHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    paddingHorizontal: 8,
    paddingVertical: 6,
  },
  categoryGlow: {
    borderRadius: 14,
    borderWidth: 1.5,
  },
  categoryIcon: {
    width: 20,
    textAlign: 'center',
  },
  categoryName: {
    fontSize: 20,
    fontWeight: '800',
  },
  countBadge: {
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
    backgroundColor: Colors.orange,
  },
  countText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '700',
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 14,
    paddingVertical: 14,
    borderRadius: 20,
    marginVertical: 0,
  },
  rowAnchor: {
    transform: [{scale: 1.02}],
    zIndex: 5,
  },
  rowGlow: {
    borderRadius: 20,
    borderWidth: 2,
  },
  rowTitle: {
    flex: 1,
    fontSize: 17,
    fontWeight: '600',
  },
  qty: {
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 10,
  },
  qtyText: {
    fontSize: 12,
    fontWeight: '600',
  },
  infoMenuWrap: {
    position: 'absolute',
    right: 12,
  },
  itemMenuWrap: {
    position: 'absolute',
    left: 0,
    right: 0,
    alignItems: 'center',
  },
  menu: {
    borderRadius: 24,
    marginVertical: 0,
    elevation: 10,
  },
  menuGlow: {
    borderRadius: 24,
    borderWidth: 1.5,
  },
  menuDivider: {
    height: StyleSheet.hairlineWidth,
    marginHorizontal: 16,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    paddingHorizontal: 16,
    paddingVertical: 12,
  },
  infoIcon: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  infoTitle: {
    fontSize: 15,
    fontWeight: '600',
  },
  infoSubtitle: {
    fontSize: 12,
  },
  toggle: {
    width: 44,
    height: 28,
    borderRadius: 14,
    padding: 2,
    justifyContent: 'center',
  },
  toggleKnob: {
    width: 24,
    height: 24,
    borderRadius: 12,
    backgroundColor: '#fff',
  },
  shortcutRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: 16,
    paddingVertical: 13,
  },
  shortcutTitle: {
    flex: 1,
    fontSize: 16,
  },
});
