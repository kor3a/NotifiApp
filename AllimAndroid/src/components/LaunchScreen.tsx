import React, {useCallback, useEffect, useRef, useState} from 'react';
import {
  AccessibilityInfo,
  ActivityIndicator,
  Animated,
  Dimensions,
  Easing,
  Image,
  ImageSourcePropType,
  StatusBar,
  StyleSheet,
  View,
} from 'react-native';
import * as SplashScreen from 'expo-splash-screen';

// Hold the native splash until the layers below are decoded, otherwise it lifts
// onto a bare teal screen for a frame. Has to run before the first render, so
// it can't wait for a component to mount.
SplashScreen.preventAutoHideAsync().catch(() => {});
// The default is a 400ms fade, which would sit on top of the opening beats. The
// two screens match at the handoff, so there is nothing to fade between.
SplashScreen.setOptions({duration: 0, fade: false});

const TEAL = '#0B7285';

// The artwork is drawn in icon.png's 1024 space (scripts/render_launch_logo.js)
// and shown at the 200dp the native splash uses. These boxes match that script.
const LOGO_DP = 200;
const dp = (units: number) => (units * LOGO_DP) / 1024;
const SCALLOP = {x: 173, y: 442, width: 163, height: 100, pitch: 128.8, count: 5};
const BADGE = {x: 628, y: 644, width: 224, height: 224};
const CHECK = {x: 675, y: 698, width: 135, height: 114};

const LAYERS: Record<'store' | 'scallop' | 'badge' | 'check', ImageSourcePropType> = {
  store: require('../../assets/launch/store.png'),
  scallop: require('../../assets/launch/scallop.png'),
  badge: require('../../assets/launch/badge.png'),
  check: require('../../assets/launch/check.png'),
};
const LAYER_COUNT = 3 + SCALLOP.count;

// If a layer never reports in, start anyway rather than sit on the splash.
const LAYER_LOAD_TIMEOUT_MS = 1000;
// Only say "still working" if the session outlasts the animation by this much.
const SPINNER_DELAY_MS = 400;
const EXIT_MS = 260;

// All on one clock, in the manner of a GSAP timeline: every part of the logo
// reads its keyframes off a single value, and that value runs on the UI thread.
// Startup is when the JS thread is busiest (Firebase, the session lookup), so
// nothing here depends on JS after the clock starts, which chained
// Animated.sequence() and `delay` steps would.
const TIMELINE_MS = 1320;
const SAMPLES_PER_TWEEN = 16;

type Ease = (t: number) => number;
/** [time in ms, value at that time, ease used to get there] */
type Keyframe = [at: number, value: number, ease?: Ease];

const backOut = (overshoot: number): Ease => Easing.out(Easing.back(overshoot));
const quadOut: Ease = Easing.out(Easing.quad);
const sineInOut: Ease = Easing.inOut(Easing.sin);

/**
 * Native-driven interpolation can only join points with straight lines, so each
 * eased tween is baked into enough short segments to hide that.
 */
function track(
  clock: Animated.Value,
  keyframes: Keyframe[],
  unit?: 'deg',
): Animated.AnimatedInterpolation<number | string> {
  const inputRange: number[] = [keyframes[0][0]];
  const outputs: number[] = [keyframes[0][1]];
  for (let i = 1; i < keyframes.length; i++) {
    const [fromAt, fromValue] = keyframes[i - 1];
    const [toAt, toValue, ease = Easing.linear] = keyframes[i];
    for (let step = 1; step <= SAMPLES_PER_TWEEN; step++) {
      const t = step / SAMPLES_PER_TWEEN;
      inputRange.push(fromAt + (toAt - fromAt) * t);
      outputs.push(fromValue + (toValue - fromValue) * ease(t));
    }
  }
  return clock.interpolate({
    inputRange,
    outputRange: unit ? outputs.map(value => `${value}${unit}`) : outputs,
    extrapolate: 'clamp',
  });
}

function buildTimeline(clock: Animated.Value) {
  // A wave runs along the awning towards the corner the badge lands in...
  const scallopScaleY = Array.from({length: SCALLOP.count}, (_, i) => {
    const start = 120 + i * 65;
    return track(clock, [
      [start, 1],
      [start + 150, 1.34, quadOut],
      [start + 420, 1, backOut(2.2)],
    ]);
  });

  return {
    scallopScaleY,
    // ...the store dips as it arrives and rebounds on the impact...
    markScale: track(clock, [
      [280, 1],
      [500, 0.965, sineInOut],
      [660, 1.025, quadOut],
      [900, 1, sineInOut],
    ]),
    // ...the badge stamps on, and the check is drawn into it...
    badgeScale: track(clock, [
      [500, 0],
      [860, 1, backOut(2.4)],
      // ...which it answers with a small pop as the stroke finishes.
      [980, 1],
      [1100, 1.1, quadOut],
      [1320, 1, sineInOut],
    ]),
    badgeRotate: track(clock, [[500, -40], [860, 0, backOut(1.6)]], 'deg'),
    // The clip slides left to right while the image inside it stays put, which
    // reads as drawing because the check itself runs left to right. Width can't
    // be animated natively, but these two translates can.
    checkClipX: track(clock, [[720, -dp(CHECK.width)], [980, 0, quadOut]]),
    checkImageX: track(clock, [[720, dp(CHECK.width)], [980, 0, quadOut]]),
  };
}

type Props = {
  /** The screen underneath has settled, so the launch screen may leave. */
  ready: boolean;
  onFinished: () => void;
};

/**
 * The logo's opening animation. Sits over the app rather than in place of it, so
 * whatever screen the launch ends on is already drawn when this fades away.
 *
 * Takes over from the native splash, which shows the store with no badge
 * (assets/splash-logo.png), and ends on icon.png's artwork.
 */
export default function LaunchScreen({ready, onFinished}: Props) {
  const clock = useRef(new Animated.Value(0)).current;
  const exit = useRef(new Animated.Value(0)).current;
  const timeline = useRef(buildTimeline(clock)).current;
  const opacity = useRef(
    exit.interpolate({inputRange: [0, 1], outputRange: [1, 0]}),
  ).current;
  const exitScale = useRef(
    exit.interpolate({inputRange: [0, 1], outputRange: [1, 1.1]}),
  ).current;

  const loadedLayers = useRef(0);
  const [layersReady, setLayersReady] = useState(false);
  const [timelineDone, setTimelineDone] = useState(false);
  const [showSpinner, setShowSpinner] = useState(false);

  const onLayerLoaded = useCallback(() => {
    loadedLayers.current += 1;
    if (loadedLayers.current >= LAYER_COUNT) {
      setLayersReady(true);
    }
  }, []);

  useEffect(() => {
    const timeout = setTimeout(() => setLayersReady(true), LAYER_LOAD_TIMEOUT_MS);
    return () => clearTimeout(timeout);
  }, []);

  useEffect(() => {
    if (!layersReady) {
      return;
    }
    SplashScreen.hideAsync().catch(() => {});

    let cancelled = false;
    AccessibilityInfo.isReduceMotionEnabled()
      .catch(() => false)
      .then(reduceMotion => {
        if (cancelled) {
          return;
        }
        if (reduceMotion) {
          clock.setValue(TIMELINE_MS);
          setTimelineDone(true);
          return;
        }
        Animated.timing(clock, {
          toValue: TIMELINE_MS,
          duration: TIMELINE_MS,
          easing: Easing.linear,
          useNativeDriver: true,
        }).start(() => setTimelineDone(true));
      });
    return () => {
      cancelled = true;
      clock.stopAnimation();
    };
  }, [layersReady, clock]);

  // The animation is the short wait. A slow session lookup gets the spinner the
  // old launch screen always showed.
  useEffect(() => {
    if (!timelineDone || ready) {
      setShowSpinner(false);
      return;
    }
    const timeout = setTimeout(() => setShowSpinner(true), SPINNER_DELAY_MS);
    return () => clearTimeout(timeout);
  }, [timelineDone, ready]);

  useEffect(() => {
    if (!timelineDone || !ready) {
      return;
    }
    const animation = Animated.timing(exit, {
      toValue: 1,
      duration: EXIT_MS,
      easing: Easing.out(Easing.quad),
      useNativeDriver: true,
    });
    animation.start(() => onFinished());
    return () => animation.stop();
  }, [timelineDone, ready, exit, onFinished]);

  return (
    <Animated.View
      pointerEvents={timelineDone && ready ? 'none' : 'auto'}
      accessible
      accessibilityLabel="Allim"
      style={[styles.root, {opacity}]}>
      <StatusBar barStyle="light-content" translucent backgroundColor="transparent" />
      <Animated.View
        style={[styles.logo, {transform: [{scale: exitScale}, {scale: timeline.markScale}]}]}>
        <Image
          source={LAYERS.store}
          fadeDuration={0}
          onLoadEnd={onLayerLoaded}
          style={styles.logo}
        />
        {timeline.scallopScaleY.map((scaleY, i) => (
          <Animated.Image
            key={i}
            source={LAYERS.scallop}
            fadeDuration={0}
            onLoadEnd={onLayerLoaded}
            style={[
              styles.scallop,
              {left: dp(SCALLOP.x + i * SCALLOP.pitch), transform: [{scaleY}]},
            ]}
          />
        ))}
        <Animated.View
          style={[
            styles.badge,
            {
              transform: [
                {scale: timeline.badgeScale},
                {rotate: timeline.badgeRotate},
              ],
            },
          ]}>
          <Image
            source={LAYERS.badge}
            fadeDuration={0}
            onLoadEnd={onLayerLoaded}
            style={styles.badgeImage}
          />
          <Animated.View
            style={[styles.checkClip, {transform: [{translateX: timeline.checkClipX}]}]}>
            <Animated.Image
              source={LAYERS.check}
              fadeDuration={0}
              onLoadEnd={onLayerLoaded}
              style={[styles.check, {transform: [{translateX: timeline.checkImageX}]}]}
            />
          </Animated.View>
        </Animated.View>
      </Animated.View>
      {showSpinner ? (
        <ActivityIndicator size="small" color="#E0F1F4" style={styles.spinner} />
      ) : null}
    </Animated.View>
  );
}

const styles = StyleSheet.create({
  root: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    // The native splash centres on the whole screen. Below Android 15 the app's
    // window stops short of the navigation bar, so centring on the window would
    // jump the logo at the handoff. Anything past the window's edge is clipped.
    height: Dimensions.get('screen').height,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: TEAL,
  },
  logo: {
    width: LOGO_DP,
    height: LOGO_DP,
  },
  scallop: {
    position: 'absolute',
    top: dp(SCALLOP.y),
    width: dp(SCALLOP.width),
    height: dp(SCALLOP.height),
    // Hangs from the awning, so it stretches downwards.
    transformOrigin: 'top',
  },
  badge: {
    position: 'absolute',
    left: dp(BADGE.x),
    top: dp(BADGE.y),
    width: dp(BADGE.width),
    height: dp(BADGE.height),
  },
  badgeImage: {
    width: dp(BADGE.width),
    height: dp(BADGE.height),
  },
  checkClip: {
    position: 'absolute',
    left: dp(CHECK.x - BADGE.x),
    top: dp(CHECK.y - BADGE.y),
    width: dp(CHECK.width),
    height: dp(CHECK.height),
    overflow: 'hidden',
  },
  check: {
    width: dp(CHECK.width),
    height: dp(CHECK.height),
  },
  spinner: {
    position: 'absolute',
    bottom: 96,
  },
});
