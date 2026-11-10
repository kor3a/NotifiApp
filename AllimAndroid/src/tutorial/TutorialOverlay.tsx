import React, {useEffect, useRef} from 'react';
import {
  Animated,
  Easing,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useColorScheme,
} from 'react-native';
import {useSafeAreaInsets} from 'react-native-safe-area-context';
import Icon from '../components/AppIcon';
import GradientBackground from '../components/GradientBackground';
import {Colors} from '../theme/AppTheme';
import {
  AddStoreScene,
  Appear,
  Chip,
  NearbyScene,
  ShareScene,
  ShortcutsScene,
  SmartSortScene,
  tutorialPalette,
} from './TutorialScenes';
import {
  TUTORIAL_CHAPTERS,
  TUTORIAL_STEPS,
  TutorialStep,
  tutorial,
  useTutorial,
} from './tutorialManager';

type IconName = React.ComponentProps<typeof Icon>['name'];
type Palette = ReturnType<typeof tutorialPalette>;

/**
 * The new-user tutorial: a full-screen, playable story. Instead of dimming the
 * live app and pointing at its buttons, each chapter stages a small working
 * demo of one idea (see TutorialScenes) and asks the user to try it — tap the
 * +, drag themselves to a store, hold an item. Nothing is gated: Next always
 * works, it just asks louder once the demo is played. Port of the iOS
 * TutorialOverlayView.
 */
export default function TutorialOverlay() {
  const {isActive, step, stepIndex, isDone} = useTutorial();
  const scheme = useColorScheme();
  const p = tutorialPalette(scheme);
  const insets = useSafeAreaInsets();

  const appear = useRef(new Animated.Value(0)).current;
  useEffect(() => {
    if (!isActive) {
      appear.setValue(0);
      return;
    }
    Animated.timing(appear, {toValue: 1, duration: 250, useNativeDriver: true}).start();
  }, [isActive, appear]);

  if (!isActive) {
    return null;
  }

  const isIntro = step.id === 'intro';
  const isFinale = step.id === 'finale';
  const chapterNumber = TUTORIAL_CHAPTERS.findIndex(c => c.id === step.id) + 1;

  return (
    <Animated.View
      style={[StyleSheet.absoluteFill, {opacity: appear}]}
      // Claim every touch so nothing underneath reacts mid-tour.
      onStartShouldSetResponder={() => true}>
      <GradientBackground />

      <View
        style={[
          styles.content,
          {paddingTop: insets.top + 8, paddingBottom: insets.bottom + 16},
        ]}>
        {/* Progress: one segment per hands-on chapter. */}
        <View style={styles.header}>
          <View
            style={styles.progress}
            accessibilityLabel={
              chapterNumber > 0
                ? `Step ${chapterNumber} of ${TUTORIAL_CHAPTERS.length}`
                : isFinale
                  ? 'Tour complete'
                  : 'Tour not started'
            }>
            {TUTORIAL_CHAPTERS.map(chapter => (
              <View
                key={chapter.id}
                style={[
                  styles.segment,
                  {
                    backgroundColor:
                      TUTORIAL_STEPS.indexOf(chapter) <= stepIndex ? p.accent : p.outline,
                  },
                ]}
              />
            ))}
          </View>
          {!isFinale && (
            <TouchableOpacity onPress={tutorial.skip} hitSlop={12} activeOpacity={0.6}>
              <Text style={[styles.skip, {color: p.inkSoft}]}>Skip</Text>
            </TouchableOpacity>
          )}
        </View>

        {/* Keyed by step so each page mounts fresh and springs in. */}
        <Appear key={step.id} style={{flex: 1}}>
          {isIntro ? (
            <IntroPage step={step} p={p} />
          ) : isFinale ? (
            <FinalePage step={step} p={p} />
          ) : (
            <View style={{flex: 1}}>
              <View style={styles.eyebrowRow}>
                <Text style={[styles.chapterNumber, {backgroundColor: p.accent}]}>
                  {String(chapterNumber).padStart(2, '0')}
                </Text>
                <Text style={[styles.eyebrow, {color: p.accent}]}>
                  {step.eyebrow.toUpperCase()}
                </Text>
              </View>
              <Text style={[styles.title, {color: p.ink}]}>{step.title}</Text>
              <Text style={[styles.description, {color: p.inkSoft}]}>{step.description}</Text>

              {/* The card the chapter's demo plays on. */}
              <View style={[styles.stage, {backgroundColor: p.surface, borderColor: p.outline}]}>
                <Scene step={step} startsDone={isDone} />
              </View>

              {/* The instruction, which turns into a "done" note once the
                  demo has been played. */}
              <View
                key={String(isDone)}
                style={[styles.hint, {backgroundColor: isDone ? p.sage : p.blush}]}>
                <Icon
                  name={isDone ? 'checkmark-circle' : 'hand-left'}
                  size={15}
                  color={isDone ? p.sageInk : p.inkOnBlush}
                />
                <Text style={[styles.hintText, {color: isDone ? p.sageInk : p.inkOnBlush}]}>
                  {isDone ? step.doneNote : step.hint}
                </Text>
              </View>
            </View>
          )}
        </Appear>

        <View style={styles.footer}>
          {!isIntro && !isFinale && (
            <TouchableOpacity
              onPress={tutorial.back}
              activeOpacity={0.7}
              accessibilityLabel="Back"
              style={[styles.back, {backgroundColor: p.blush}]}>
              <Icon name="chevron-back" size={22} color={p.accent} />
            </TouchableOpacity>
          )}
          {/* Quiet until the demo has been played, then filled: the button
              never blocks, it just changes how hard it asks. */}
          <Pill
            p={p}
            title={isIntro ? 'Take the tour' : isFinale ? 'Start shopping' : 'Next'}
            icon={isFinale ? undefined : 'arrow-forward'}
            prominent={isIntro || isFinale || isDone}
            onPress={isFinale ? tutorial.finish : tutorial.advance}
          />
        </View>
      </View>
    </Animated.View>
  );
}

function Scene({step, startsDone}: {step: TutorialStep; startsDone: boolean}) {
  const onDone = () => tutorial.markDone(step.id);
  switch (step.id) {
    case 'addStore':
      return <AddStoreScene onDone={onDone} startsDone={startsDone} />;
    case 'smartSort':
      return <SmartSortScene onDone={onDone} />;
    case 'nearby':
      return <NearbyScene onDone={onDone} />;
    case 'shortcuts':
      return <ShortcutsScene onDone={onDone} />;
    case 'share':
      return <ShareScene onDone={onDone} />;
    default:
      return null;
  }
}

function Pill({
  p,
  title,
  icon,
  prominent,
  onPress,
}: {
  p: Palette;
  title: string;
  icon?: IconName;
  prominent: boolean;
  onPress: () => void;
}) {
  const color = prominent ? p.onAccent : p.inkOnBlush;
  return (
    <TouchableOpacity
      onPress={onPress}
      activeOpacity={0.8}
      style={[styles.pill, {backgroundColor: prominent ? p.accent : p.blush}]}>
      <Text style={[styles.pillText, {color}]}>{title}</Text>
      {icon && <Icon name={icon} size={18} color={color} />}
    </TouchableOpacity>
  );
}

// ─── Intro ────────────────────────────────────────────────────────────────────

function IntroPage({step, p}: {step: TutorialStep; p: Palette}) {
  return (
    <View style={{flex: 1}}>
      <View style={styles.heroWrap}>
        <Hero p={p} />
      </View>
      <Text style={[styles.eyebrow, {color: p.accent}]}>{step.eyebrow.toUpperCase()}</Text>
      <Text style={[styles.introTitle, {color: p.ink}]}>{step.title}</Text>
      <Text style={[styles.introDescription, {color: p.inkSoft}]}>{step.description}</Text>
    </View>
  );
}

const FLOATERS = [
  {name: 'Bananas', category: 'Produce' as const, x: -104, y: -78, delay: 0},
  {name: 'Whole Milk', category: 'Dairy' as const, x: 108, y: -34, delay: 500},
  {name: 'Sourdough', category: 'Bakery' as const, x: -86, y: 86, delay: 1000},
];

/**
 * The opening illustration: a store, the rings of the area Allim watches
 * around it, and a few list items floating by.
 */
function Hero({p}: {p: Palette}) {
  const rings = useRef([0, 1, 2].map(() => new Animated.Value(0))).current;
  const bob = useRef(FLOATERS.map(() => new Animated.Value(0))).current;

  useEffect(() => {
    const loops = [
      ...rings.map((value, index) =>
        Animated.loop(
          Animated.sequence([
            Animated.delay(index * 900),
            Animated.timing(value, {
              toValue: 1,
              duration: 2700,
              easing: Easing.out(Easing.quad),
              useNativeDriver: true,
            }),
          ]),
        ),
      ),
      ...bob.map((value, index) =>
        Animated.loop(
          Animated.sequence([
            Animated.delay(FLOATERS[index].delay),
            Animated.timing(value, {
              toValue: 1,
              duration: 2200,
              easing: Easing.inOut(Easing.quad),
              useNativeDriver: true,
            }),
            Animated.timing(value, {
              toValue: 0,
              duration: 2200,
              easing: Easing.inOut(Easing.quad),
              useNativeDriver: true,
            }),
          ]),
        ),
      ),
    ];
    loops.forEach(loop => loop.start());
    return () => loops.forEach(loop => loop.stop());
  }, [rings, bob]);

  return (
    <View style={styles.hero} accessibilityElementsHidden importantForAccessibility="no-hide-descendants">
      {rings.map((value, index) => (
        <Animated.View
          key={index}
          style={[
            styles.heroRing,
            {
              borderColor: p.highlight,
              opacity: value.interpolate({inputRange: [0, 1], outputRange: [0.7, 0]}),
              transform: [{scale: value.interpolate({inputRange: [0, 1], outputRange: [1, 2.7]})}],
            },
          ]}
        />
      ))}
      <View style={[styles.heroDisc, {backgroundColor: p.accent}]}>
        <Icon name="storefront" size={42} color={p.onAccent} />
      </View>
      {FLOATERS.map((floater, index) => (
        <Animated.View
          key={floater.name}
          style={{
            position: 'absolute',
            transform: [
              {translateX: floater.x},
              {
                translateY: bob[index].interpolate({
                  inputRange: [0, 1],
                  outputRange: [floater.y + 7, floater.y - 7],
                }),
              },
            ],
          }}>
          <Chip name={floater.name} category={floater.category} />
        </Animated.View>
      ))}
    </View>
  );
}

// ─── Finale ───────────────────────────────────────────────────────────────────

const PLACES: {name: string; icon: IconName; detail: string}[] = [
  {name: 'Stores', icon: 'storefront', detail: 'Your stores and their lists. Tap + to add one.'},
  {name: 'Messages', icon: 'chatbubble', detail: 'Chat, and send a store or an item along.'},
  {name: 'AI Recipe', icon: 'restaurant', detail: 'Turn any recipe into a shopping list.'},
  {name: 'Search', icon: 'map', detail: 'Find stores near you on the map.'},
  {name: 'Profile', icon: 'person-circle', detail: 'Friends, Family and your settings.'},
];

function FinalePage({step, p}: {step: TutorialStep; p: Palette}) {
  return (
    <View style={styles.finale}>
      <Appear from="scale" delay={100} style={{alignSelf: 'flex-start'}}>
        <View style={[styles.finaleCheck, {backgroundColor: p.sageInk}]}>
          <Icon name="checkmark" size={30} color={Colors.white} />
        </View>
      </Appear>
      <Text style={[styles.introTitle, {color: p.ink, fontSize: 36, lineHeight: 42}]}>
        {step.title}
      </Text>
      <Text style={[styles.description, {color: p.inkSoft}]}>{step.description}</Text>

      <View style={[styles.places, {backgroundColor: p.surface, borderColor: p.outline}]}>
        {PLACES.map((place, index) => (
          <Appear key={place.name} delay={150 + index * 70}>
            <View
              style={[
                styles.place,
                index > 0 && {borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: p.outline},
              ]}>
              <View style={[styles.placeIcon, {backgroundColor: p.blush}]}>
                <Icon name={place.icon} size={18} color={p.accent} />
              </View>
              <View style={{flex: 1}}>
                <Text style={[styles.placeName, {color: p.ink}]}>{place.name}</Text>
                <Text style={[styles.placeDetail, {color: p.inkSoft}]}>{place.detail}</Text>
              </View>
            </View>
          </Appear>
        ))}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  content: {
    flex: 1,
    width: '100%',
    maxWidth: 560,
    alignSelf: 'center',
    paddingHorizontal: 24,
  },
  header: {
    height: 48,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
  },
  progress: {
    flex: 1,
    flexDirection: 'row',
    gap: 5,
  },
  segment: {
    flex: 1,
    height: 4,
    borderRadius: 2,
  },
  skip: {
    fontSize: 15,
    fontWeight: '600',
  },
  eyebrowRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginTop: 10,
  },
  chapterNumber: {
    color: Colors.white,
    fontSize: 13,
    fontWeight: '900',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 10,
    overflow: 'hidden',
  },
  eyebrow: {
    fontSize: 13,
    fontWeight: '700',
    letterSpacing: 1.2,
  },
  title: {
    fontSize: 30,
    lineHeight: 36,
    fontWeight: '800',
    marginTop: 12,
  },
  description: {
    fontSize: 16,
    lineHeight: 23,
    marginTop: 8,
  },
  stage: {
    flex: 1,
    marginTop: 18,
    borderRadius: 32,
    borderWidth: 1,
    overflow: 'hidden',
  },
  hint: {
    alignSelf: 'center',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 14,
    paddingVertical: 9,
    borderRadius: 20,
    marginTop: 12,
    marginBottom: 14,
  },
  hintText: {
    fontSize: 14,
    fontWeight: '600',
  },
  footer: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
  },
  back: {
    width: 56,
    height: 56,
    borderRadius: 28,
    alignItems: 'center',
    justifyContent: 'center',
  },
  pill: {
    flex: 1,
    height: 56,
    borderRadius: 28,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
  },
  pillText: {
    fontSize: 17,
    fontWeight: '700',
  },
  heroWrap: {
    flex: 1,
    minHeight: 220,
    alignItems: 'center',
    justifyContent: 'center',
  },
  hero: {
    width: 260,
    height: 260,
    alignItems: 'center',
    justifyContent: 'center',
  },
  heroRing: {
    position: 'absolute',
    width: 96,
    height: 96,
    borderRadius: 48,
    borderWidth: 2,
  },
  heroDisc: {
    width: 96,
    height: 96,
    borderRadius: 48,
    alignItems: 'center',
    justifyContent: 'center',
    elevation: 8,
  },
  introTitle: {
    fontSize: 40,
    lineHeight: 46,
    fontWeight: '800',
    marginTop: 12,
  },
  introDescription: {
    fontSize: 17,
    lineHeight: 25,
    marginTop: 12,
    marginBottom: 28,
  },
  finale: {
    flex: 1,
    justifyContent: 'center',
    paddingBottom: 20,
  },
  finaleCheck: {
    width: 60,
    height: 60,
    borderRadius: 30,
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  places: {
    marginTop: 22,
    paddingHorizontal: 16,
    paddingVertical: 6,
    borderRadius: 28,
    borderWidth: 1,
  },
  place: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    paddingVertical: 10,
  },
  placeIcon: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  placeName: {
    fontSize: 16,
    fontWeight: '700',
  },
  placeDetail: {
    fontSize: 13,
    lineHeight: 18,
  },
});
