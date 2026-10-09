import React, {useEffect, useRef, useState} from 'react';
import {
  Animated,
  StyleSheet,
  Text,
  TouchableOpacity,
  View,
  useWindowDimensions,
} from 'react-native';
import Icon from '../components/AppIcon';
import {Colors} from '../theme/AppTheme';
import TutorialReminderScene from './TutorialReminderScene';
import {
  TUTORIAL_STEPS,
  TargetFrame,
  tutorial,
  useTutorial,
  useTutorialFrameVersion,
} from './tutorialManager';

// The cutout stands this far off the control it frames, with these corners.
const HOLE_PADDING = 14;
const HOLE_RADIUS = 14;
const SCRIM = 'rgba(0,0,0,0.62)';
// Before the card has measured itself, position it as though it were this tall.
const DEFAULT_CARD_HEIGHT = 180;

// The dots count the steps between the welcome and closing cards.
const DOT_STEPS = TUTORIAL_STEPS.filter(s => s.id !== 'welcome' && s.id !== 'complete');

/**
 * Full-screen tour overlay: dims the app, cuts a rounded hole around the
 * control the current step is about, rings it with a pulsing border, and shows
 * a callout card above or below it. Port of the iOS TutorialOverlayView.
 *
 * It swallows every touch, so the live app (and the mock data it is showing)
 * can't be poked mid-tour.
 */
export default function TutorialOverlay() {
  const {isActive, step} = useTutorial();
  // Re-render when a highlighted control reports a new frame.
  useTutorialFrameVersion();
  const {width: screenW, height: screenH} = useWindowDimensions();
  const [cardHeight, setCardHeight] = useState(DEFAULT_CARD_HEIGHT);
  // Where this overlay sits in the coordinates targets report their frames in.
  // Android's measureInWindow is relative to the visible frame, which starts
  // below the status bar the app draws under — so the overlay measures itself
  // the same way and the difference cancels out.
  const rootRef = useRef<View>(null);
  const [origin, setOrigin] = useState({x: 0, y: 0});
  function measureOrigin() {
    rootRef.current?.measureInWindow((x, y) => {
      if (x !== origin.x || y !== origin.y) {
        setOrigin({x, y});
      }
    });
  }

  const appear = useRef(new Animated.Value(0)).current;
  const pulse = useRef(new Animated.Value(0)).current;
  const cardIn = useRef(new Animated.Value(1)).current;

  useEffect(() => {
    if (!isActive) {
      appear.setValue(0);
      return;
    }
    Animated.timing(appear, {toValue: 1, duration: 250, useNativeDriver: true}).start();
    const loop = Animated.loop(
      Animated.sequence([
        Animated.timing(pulse, {toValue: 1, duration: 1100, useNativeDriver: true}),
        Animated.timing(pulse, {toValue: 0, duration: 1100, useNativeDriver: true}),
      ]),
    );
    loop.start();
    return () => loop.stop();
  }, [isActive, appear, pulse]);

  // Each step's card springs in; the target is re-measured once the tab switch
  // that came with the step has settled.
  useEffect(() => {
    if (!isActive) {
      return;
    }
    cardIn.setValue(0);
    Animated.spring(cardIn, {
      toValue: 1,
      friction: 8,
      tension: 70,
      useNativeDriver: true,
    }).start();
    const targetId = step.targetId;
    if (!targetId) {
      return;
    }
    tutorial.remeasure(targetId);
    const timer = setTimeout(() => tutorial.remeasure(targetId), 400);
    return () => clearTimeout(timer);
  }, [isActive, step, cardIn]);

  if (!isActive) {
    return null;
  }

  const frame = step.targetId ? tutorial.frameFor(step.targetId) : undefined;
  const hole: TargetFrame | undefined = frame && {
    x: frame.x - origin.x - HOLE_PADDING,
    y: frame.y - origin.y - HOLE_PADDING,
    width: frame.width + HOLE_PADDING * 2,
    height: frame.height + HOLE_PADDING * 2,
  };

  const cardWidth = Math.min(screenW - 40, 340);
  const cardTop = step.isReminderScene
    ? screenH - cardHeight - 70
    : cardTopFor(hole, cardHeight, screenH);

  const isFirst = step.id === 'welcome';
  const isLast = step.id === 'complete';

  return (
    <Animated.View
      style={[StyleSheet.absoluteFill, {opacity: appear}]}
      // Claim every touch so nothing underneath reacts mid-tour.
      onStartShouldSetResponder={() => true}>
      <View
        ref={rootRef}
        collapsable={false}
        pointerEvents="none"
        style={StyleSheet.absoluteFill}
        onLayout={measureOrigin}
      />
      {step.isReminderScene ? (
        <>
          <TutorialReminderScene step={step.id} />
          {/* A scrim along the bottom so the card stays legible over the
              mock list. */}
          <View pointerEvents="none" style={styles.bottomScrim}>
            {[0.06, 0.14, 0.24, 0.34, 0.44, 0.52].map(alpha => (
              <View key={alpha} style={{flex: 1, backgroundColor: `rgba(0,0,0,${alpha})`}} />
            ))}
          </View>
        </>
      ) : hole ? (
        <>
          <Cutout hole={hole} span={screenW + screenH} />
          <HighlightRing hole={hole} pulse={pulse} />
        </>
      ) : (
        // Welcome, closing card, or a target not on screen yet: dim it all.
        <View style={[StyleSheet.absoluteFill, {backgroundColor: SCRIM}]} />
      )}

      <Animated.View
        onLayout={e => setCardHeight(e.nativeEvent.layout.height)}
        style={[
          styles.card,
          {
            width: cardWidth,
            left: (screenW - cardWidth) / 2,
            top: cardTop,
            opacity: cardIn,
            transform: [
              {scale: cardIn.interpolate({inputRange: [0, 1], outputRange: [0.92, 1]})},
            ],
          },
        ]}>
        {!isFirst && !isLast && (
          <View style={styles.dots}>
            {DOT_STEPS.map(s => {
              const current = s.id === step.id;
              return (
                <View
                  key={s.id}
                  style={{
                    width: current ? 8 : 6,
                    height: current ? 8 : 6,
                    borderRadius: 4,
                    backgroundColor: current ? '#fff' : 'rgba(255,255,255,0.3)',
                  }}
                />
              );
            })}
          </View>
        )}

        <Text style={styles.title}>{step.title}</Text>
        <Text style={styles.description}>{step.description}</Text>

        <View style={styles.buttons}>
          {!isLast && (
            <TouchableOpacity onPress={tutorial.skip} hitSlop={10} activeOpacity={0.6}>
              <Text style={styles.skip}>Skip</Text>
            </TouchableOpacity>
          )}
          <View style={{flex: 1}} />
          <TouchableOpacity
            onPress={isLast ? tutorial.finish : tutorial.advance}
            activeOpacity={0.8}
            style={styles.next}>
            <Text style={styles.nextText}>{isLast ? 'Get Started' : 'Next'}</Text>
            {!isLast && <Icon name="chevron-forward" size={14} color="#fff" />}
          </TouchableOpacity>
        </View>
      </Animated.View>
    </Animated.View>
  );
}

/**
 * Below the highlight when it fits, above it when that fits, otherwise below
 * with overlap allowed — the iOS placement rule. Centred with no highlight.
 */
function cardTopFor(hole: TargetFrame | undefined, cardHeight: number, screenH: number) {
  const padding = 16;
  if (!hole) {
    return (screenH - cardHeight) / 2;
  }
  const spaceAbove = hole.y;
  const spaceBelow = screenH - (hole.y + hole.height);
  if (spaceBelow >= cardHeight + padding * 2) {
    return hole.y + hole.height + padding;
  }
  if (spaceAbove >= cardHeight + padding * 2) {
    return hole.y - padding - cardHeight;
  }
  return Math.min(hole.y + hole.height + padding, screenH - cardHeight - padding);
}

/**
 * The scrim with a rounded hole in it. One view whose border is wide enough to
 * reach every edge of the screen from the hole: its inner edge is the cutout,
 * and an outer radius of border + HOLE_RADIUS leaves the inner corners rounded
 * by HOLE_RADIUS.
 */
function Cutout({hole, span}: {hole: TargetFrame; span: number}) {
  return (
    <View
      pointerEvents="none"
      style={{
        position: 'absolute',
        left: hole.x - span,
        top: hole.y - span,
        width: hole.width + span * 2,
        height: hole.height + span * 2,
        borderWidth: span,
        borderRadius: span + HOLE_RADIUS,
        borderColor: SCRIM,
      }}
    />
  );
}

/**
 * The pulsing ring around the cutout: a white edge with a glow of the accent
 * breathing behind it. Pulsed by opacity only, never scale, so it can't drift
 * outside the hole whatever the control's size.
 */
function HighlightRing({hole, pulse}: {hole: TargetFrame; pulse: Animated.Value}) {
  const frame = {
    position: 'absolute' as const,
    left: hole.x,
    top: hole.y,
    width: hole.width,
    height: hole.height,
    borderRadius: HOLE_RADIUS,
  };
  return (
    <>
      <Animated.View
        pointerEvents="none"
        style={[
          frame,
          styles.glow,
          {opacity: pulse.interpolate({inputRange: [0, 1], outputRange: [0.35, 1]})},
        ]}
      />
      <Animated.View
        pointerEvents="none"
        style={[
          frame,
          styles.ring,
          {opacity: pulse.interpolate({inputRange: [0, 1], outputRange: [1, 0.55]})},
        ]}
      />
    </>
  );
}

const styles = StyleSheet.create({
  bottomScrim: {
    position: 'absolute',
    left: 0,
    right: 0,
    bottom: 0,
    height: '50%',
  },
  glow: {
    borderWidth: 5,
    borderColor: Colors.blue,
    margin: -3,
  },
  ring: {
    borderWidth: 2.5,
    borderColor: '#fff',
  },
  card: {
    position: 'absolute',
    gap: 14,
    padding: 20,
    borderRadius: 20,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.18)',
    backgroundColor: 'rgba(32,32,43,0.94)',
    elevation: 16,
  },
  dots: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  title: {
    color: '#fff',
    fontSize: 18,
    fontWeight: '700',
  },
  description: {
    color: 'rgba(255,255,255,0.88)',
    fontSize: 14,
    lineHeight: 20,
  },
  buttons: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  skip: {
    color: 'rgba(255,255,255,0.55)',
    fontSize: 14,
    fontWeight: '500',
  },
  next: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingHorizontal: 20,
    paddingVertical: 10,
    borderRadius: 20,
    backgroundColor: Colors.blue,
  },
  nextText: {
    color: '#fff',
    fontSize: 15,
    fontWeight: '600',
  },
});
