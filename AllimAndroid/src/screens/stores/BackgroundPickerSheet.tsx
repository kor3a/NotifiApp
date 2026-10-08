import React, {useRef, useState} from 'react';
import {
  View,
  Text,
  Modal,
  ScrollView,
  StyleSheet,
  TouchableOpacity,
  PanResponder,
  LayoutChangeEvent,
  useColorScheme,
} from 'react-native';
import {SafeAreaView} from 'react-native-safe-area-context';
import LinearGradient from 'react-native-linear-gradient';
import Icon from '../../components/AppIcon';

import {
  Colors,
  Spacing,
  Radius,
  textPrimary,
  textSecondary,
  cardBackground,
  cardBorder,
} from '../../theme/AppTheme';
import {
  BACKGROUND_COLORS,
  BackgroundColorId,
  backgroundColorName,
  backgroundStops,
} from '../../theme/BackgroundTheme';
import {
  BackgroundSurface,
  backgroundPreferences,
  useBackgroundPreference,
} from '../../services/backgroundPreferences';

interface Props {
  visible: boolean;
  surface: BackgroundSurface;
  title: string;
  onClose: () => void;
}

const SWATCHES: {id: BackgroundColorId; name: string}[] = [
  {id: 'system', name: 'Default'},
  ...BACKGROUND_COLORS.map(c => ({id: c.id, name: c.name})),
];

// The iOS BackgroundPickerView, colors and shade: a miniature of the screen,
// the palette, and a slider for how deep the chosen color sits. Changes apply
// as they're made; Done just closes.
export default function BackgroundPickerSheet({
  visible,
  surface,
  title,
  onClose,
}: Props) {
  const scheme = useColorScheme();
  const {color, shade} = useBackgroundPreference(surface);
  const isDefault = color === 'system' && shade === 0;

  const subject = color === 'system' ? 'the default background' : backgroundColorName(color);

  return (
    <Modal
      visible={visible}
      animationType="slide"
      presentationStyle="pageSheet"
      onRequestClose={onClose}>
      <SafeAreaView
        style={[
          styles.container,
          {
            backgroundColor:
              scheme === 'dark' ? Colors.backgroundTopDark : Colors.backgroundTopLight,
          },
        ]}>
        <View style={styles.header}>
          <TouchableOpacity
            onPress={() => backgroundPreferences.reset(surface)}
            disabled={isDefault}
            style={styles.headerSide}>
            <Text
              style={[
                styles.headerAction,
                {color: Colors.blue, opacity: isDefault ? 0.35 : 1},
              ]}>
              Reset
            </Text>
          </TouchableOpacity>
          <Text
            style={[styles.title, {color: textPrimary(scheme)}]}
            numberOfLines={1}>
            {title} Background
          </Text>
          <TouchableOpacity
            onPress={onClose}
            style={[styles.headerSide, {alignItems: 'flex-end'}]}>
            <Text style={[styles.headerAction, styles.done]}>Done</Text>
          </TouchableOpacity>
        </View>

        <ScrollView contentContainerStyle={styles.scroll}>
          {/* Preview — judged against the cards it will sit behind. */}
          <View style={[styles.preview, {borderColor: cardBorder(scheme)}]}>
            <LinearGradient
              colors={backgroundStops(color, scheme, shade)}
              style={StyleSheet.absoluteFill}
            />
            {[
              {title: 'Whole Foods', subtitle: '4 items'},
              {title: "Trader Joe's", subtitle: '2 items'},
            ].map(row => (
              <View
                key={row.title}
                style={[styles.previewCard, {backgroundColor: cardBackground(scheme)}]}>
                <View style={[styles.previewDot, {backgroundColor: Colors.blue + '26'}]} />
                <View>
                  <Text style={[styles.previewTitle, {color: textPrimary(scheme)}]}>
                    {row.title}
                  </Text>
                  <Text style={[styles.previewSubtitle, {color: textSecondary(scheme)}]}>
                    {row.subtitle}
                  </Text>
                </View>
              </View>
            ))}
          </View>
          <Text style={[styles.previewLabel, {color: textSecondary(scheme)}]}>
            {backgroundColorName(color)}
          </Text>

          {/* Swatches carry the current shade, so the slider previews the
              whole palette at that depth. */}
          <SectionHeader title="COLORS" scheme={scheme} />
          <View style={styles.grid}>
            {SWATCHES.map(swatch => {
              const selected = swatch.id === color;
              return (
                <TouchableOpacity
                  key={swatch.id}
                  style={styles.swatchCell}
                  onPress={() => backgroundPreferences.set(surface, {color: swatch.id})}
                  accessibilityLabel={swatch.name}
                  accessibilityState={{selected}}
                  activeOpacity={0.8}>
                  <View
                    style={[
                      styles.swatch,
                      {
                        borderColor: selected ? Colors.blue : cardBorder(scheme),
                        borderWidth: selected ? 2.5 : 1,
                      },
                    ]}>
                    <LinearGradient
                      colors={backgroundStops(swatch.id, scheme, shade)}
                      style={StyleSheet.absoluteFill}
                    />
                    {selected && (
                      <Icon name="checkmark-circle" size={22} color={Colors.blue} />
                    )}
                  </View>
                  <Text
                    style={[
                      styles.swatchName,
                      {
                        color: selected ? textPrimary(scheme) : textSecondary(scheme),
                        fontWeight: selected ? '700' : '400',
                      },
                    ]}
                    numberOfLines={1}>
                    {swatch.name}
                  </Text>
                </TouchableOpacity>
              );
            })}
          </View>

          <View style={styles.shadeHeader}>
            <SectionHeader title="SHADE" scheme={scheme} />
            {shade !== 0 && (
              <TouchableOpacity onPress={() => backgroundPreferences.set(surface, {shade: 0})}>
                <Text style={styles.shadeReset}>Default</Text>
              </TouchableOpacity>
            )}
          </View>
          <View style={[styles.card, {backgroundColor: cardBackground(scheme)}]}>
            <View style={styles.sliderRow}>
              <Icon name="sunny" size={16} color={textSecondary(scheme)} />
              <ShadeSlider
                value={shade}
                onChange={v => backgroundPreferences.set(surface, {shade: v})}
                trackColor={cardBorder(scheme)}
              />
              <Icon name="moon" size={16} color={textSecondary(scheme)} />
            </View>
            <Text style={[styles.hint, {color: textSecondary(scheme)}]}>
              Drag right to deepen {subject}, left to lighten it. Watch the preview
              above — a very dark background in Light Mode can make text harder to
              read.
            </Text>
          </View>
        </ScrollView>
      </SafeAreaView>
    </Modal>
  );
}

function SectionHeader({
  title,
  scheme,
}: {
  title: string;
  scheme: ReturnType<typeof useColorScheme>;
}) {
  return (
    <Text style={[styles.sectionHeader, {color: textSecondary(scheme)}]}>{title}</Text>
  );
}

const THUMB = 26;

// A -1…1 slider. React Native no longer ships one, and this is the only place
// the app needs it.
function ShadeSlider({
  value,
  onChange,
  trackColor,
}: {
  value: number;
  onChange: (value: number) => void;
  trackColor: string;
}) {
  const [width, setWidth] = useState(0);
  const latest = useRef({width, onChange, start: 0});
  latest.current.width = width;
  latest.current.onChange = onChange;

  const valueAt = (x: number) => {
    const usable = latest.current.width - THUMB;
    if (usable <= 0) {
      return 0;
    }
    const v = ((x - THUMB / 2) / usable) * 2 - 1;
    // Snap to the untouched middle so Default is easy to land on.
    const clamped = Math.min(Math.max(v, -1), 1);
    return Math.abs(clamped) < 0.04 ? 0 : Math.round(clamped * 100) / 100;
  };

  const pan = useRef(
    PanResponder.create({
      onStartShouldSetPanResponder: () => true,
      onMoveShouldSetPanResponder: () => true,
      onPanResponderTerminationRequest: () => false,
      onPanResponderGrant: e => {
        latest.current.start = e.nativeEvent.locationX;
        latest.current.onChange(valueAt(e.nativeEvent.locationX));
      },
      onPanResponderMove: (_, g) => {
        latest.current.onChange(valueAt(latest.current.start + g.dx));
      },
    }),
  ).current;

  const thumbLeft = ((value + 1) / 2) * Math.max(width - THUMB, 0);

  return (
    <View
      style={styles.slider}
      onLayout={(e: LayoutChangeEvent) => setWidth(e.nativeEvent.layout.width)}
      accessibilityRole="adjustable"
      accessibilityLabel="Background shade"
      accessibilityValue={{min: -100, max: 100, now: Math.round(value * 100)}}
      accessibilityActions={[{name: 'increment'}, {name: 'decrement'}]}
      onAccessibilityAction={e =>
        onChange(
          Math.min(
            Math.max(value + (e.nativeEvent.actionName === 'increment' ? 0.1 : -0.1), -1),
            1,
          ),
        )
      }
      {...pan.panHandlers}>
      {/* Only the slider itself takes touches, so locationX is always
          measured from its left edge. */}
      <View
        style={[styles.sliderTrack, {backgroundColor: trackColor}]}
        pointerEvents="none"
      />
      <View
        pointerEvents="none"
        style={[
          styles.sliderFill,
          {
            left: Math.min(thumbLeft, (width - THUMB) / 2) + THUMB / 2,
            width: Math.abs(thumbLeft - (width - THUMB) / 2),
          },
        ]}
      />
      <View style={[styles.sliderThumb, {left: thumbLeft}]} pointerEvents="none" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.md,
    paddingVertical: 14,
  },
  headerSide: {
    width: 70,
  },
  headerAction: {
    fontSize: 17,
  },
  done: {
    color: Colors.blue,
    fontWeight: '600',
  },
  title: {
    flex: 1,
    textAlign: 'center',
    fontSize: 17,
    fontWeight: '600',
  },
  scroll: {
    paddingHorizontal: 20,
    paddingBottom: 40,
  },
  preview: {
    height: 170,
    borderRadius: Radius.xl,
    borderWidth: 1,
    overflow: 'hidden',
    padding: Spacing.md,
    justifyContent: 'center',
    gap: 10,
  },
  previewCard: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    padding: 10,
    borderRadius: 18,
    elevation: 2,
  },
  previewDot: {
    width: 34,
    height: 34,
    borderRadius: 17,
  },
  previewTitle: {
    fontSize: 14,
    fontWeight: '600',
  },
  previewSubtitle: {
    fontSize: 12,
  },
  previewLabel: {
    textAlign: 'center',
    fontSize: 14,
    fontWeight: '600',
    marginTop: 10,
    marginBottom: Spacing.lg,
  },
  sectionHeader: {
    fontSize: 11,
    fontWeight: '700',
    letterSpacing: 0.8,
    paddingHorizontal: 4,
    marginBottom: 12,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    marginHorizontal: -7,
    marginBottom: Spacing.lg,
  },
  swatchCell: {
    width: '25%',
    paddingHorizontal: 7,
    marginBottom: 14,
    alignItems: 'center',
  },
  swatch: {
    width: '100%',
    height: 56,
    borderRadius: Radius.lg,
    overflow: 'hidden',
    alignItems: 'center',
    justifyContent: 'center',
  },
  swatchName: {
    fontSize: 11,
    marginTop: 6,
  },
  shadeHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  shadeReset: {
    fontSize: 12,
    fontWeight: '700',
    color: Colors.blue,
  },
  card: {
    borderRadius: 20,
    padding: 14,
  },
  sliderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  hint: {
    fontSize: 12,
    marginTop: 8,
    lineHeight: 16,
  },
  slider: {
    flex: 1,
    height: 36,
    justifyContent: 'center',
  },
  sliderTrack: {
    position: 'absolute',
    left: THUMB / 2,
    right: THUMB / 2,
    height: 4,
    borderRadius: 2,
  },
  sliderFill: {
    position: 'absolute',
    height: 4,
    borderRadius: 2,
    backgroundColor: Colors.blue,
  },
  sliderThumb: {
    position: 'absolute',
    width: THUMB,
    height: THUMB,
    borderRadius: THUMB / 2,
    backgroundColor: Colors.white,
    elevation: 3,
    shadowColor: '#000',
    shadowOpacity: 0.2,
    shadowRadius: 3,
    shadowOffset: {width: 0, height: 1},
  },
});
