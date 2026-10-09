import {useCallback, useEffect, useRef, useSyncExternalStore} from 'react';
import {View} from 'react-native';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {navigationRef} from '../navigation/navigationRef';

/**
 * The new-user tutorial: a guided tour over the live app that dims everything
 * but one control at a time and explains it in a callout card. Port of the iOS
 * TutorialManager / TutorialStep.
 */

export type TutorialStepId =
  | 'welcome'
  | 'storesFAB'
  | 'storesToolbar'
  | 'remindersCategories'
  | 'remindersInfoMenu'
  | 'remindersItemMenu'
  | 'messagesCompose'
  | 'friendsInProfile'
  | 'mapSearch'
  | 'complete';

type TabName = 'Stores' | 'Messages' | 'Search';

export type TutorialStep = {
  id: TutorialStepId;
  title: string;
  description: string;
  /** The tab the live app shows under this step. */
  tab: TabName;
  /** The registered control this step highlights, if any. */
  targetId?: string;
  /**
   * Part of the simulated Reminders walkthrough the overlay draws as a
   * full-screen mock, rather than a highlight over the live app.
   */
  isReminderScene?: boolean;
};

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    id: 'welcome',
    title: 'Welcome to Allim!',
    description:
      "Let's take a quick tour of the key features so you can get the most out of your shopping experience.",
    tab: 'Stores',
  },
  {
    id: 'storesFAB',
    title: 'Add Your First Store',
    description:
      'Tap the + button to add your favorite grocery stores and start managing shopping reminders.',
    tab: 'Stores',
    targetId: 'tutorial_fab',
  },
  {
    id: 'storesToolbar',
    title: 'Organize Your Stores',
    description:
      'Sort your stores by reminder count, or switch between list and grid view using these buttons.',
    tab: 'Stores',
    targetId: 'tutorial_toolbar',
  },
  {
    id: 'remindersCategories',
    title: 'Auto-Sorted Reminders',
    description:
      'Open a store to see its reminders. As you add items, Smart Category automatically groups them into sections like Produce, Dairy, and Bakery — no sorting needed.',
    tab: 'Stores',
    isReminderScene: true,
  },
  {
    id: 'remindersInfoMenu',
    title: 'The List Menu',
    description:
      "Tap the info (i) button in the top-right to open the list menu. From here you can turn on Auto Delete, toggle Smart Category, add ingredients from a recipe, and visit the store's website.",
    tab: 'Stores',
    isReminderScene: true,
  },
  {
    id: 'remindersItemMenu',
    title: 'Item Shortcuts',
    description:
      'Touch and hold any reminder to open its shortcut menu. Mark it out of stock, move it to another store, add a photo or quantity, or change its category.',
    tab: 'Stores',
    isReminderScene: true,
  },
  {
    id: 'messagesCompose',
    title: 'Message Friends',
    description:
      'Tap the compose button to start a conversation. Share stores and reminders directly with friends.',
    tab: 'Messages',
    targetId: 'tutorial_compose',
  },
  {
    id: 'friendsInProfile',
    title: 'Friends & Family',
    description:
      'Open your profile here to find Friends. Add friends to share stores and reminders with, and put the closest of them in your Family group so they come first whenever you share.',
    // Friends lives under Profile, and Stores is the tab the profile button
    // sits on.
    tab: 'Stores',
    targetId: 'tutorial_profile',
  },
  {
    id: 'mapSearch',
    title: 'Find Stores Nearby',
    description:
      'Use the search bar to find stores near you on the map. Tap any pin to view or add reminders.',
    tab: 'Search',
    targetId: 'tutorial_mapSearch',
  },
  {
    id: 'complete',
    title: "You're All Set!",
    description: "You're ready to go! Start by tapping the + button to add your first store.",
    tab: 'Stores',
  },
];

export type TargetFrame = {x: number; y: number; width: number; height: number};

type State = {isActive: boolean; stepIndex: number};

let state: State = {isActive: false, stepIndex: 0};
let currentUid: string | null = null;
let startTimer: ReturnType<typeof setTimeout> | null = null;
const listeners = new Set<() => void>();

// Frames of the highlightable controls, in window coordinates. Kept outside
// React state so a control re-reporting its frame doesn't re-render the screen
// it lives on — only the overlay subscribes.
const frames = new Map<string, TargetFrame>();
const measurers = new Map<string, () => void>();
const frameListeners = new Set<() => void>();
let frameVersion = 0;

function emit() {
  listeners.forEach(listener => listener());
}

function setState(next: State) {
  state = next;
  emit();
}

function completionKey(uid: string) {
  return `hasCompletedTutorial_auth_${uid}`;
}

function showTab(tab: TabName) {
  if (navigationRef.isReady()) {
    navigationRef.navigate('Tabs', {screen: tab});
  }
}

function complete() {
  if (currentUid) {
    AsyncStorage.setItem(completionKey(currentUid), 'true').catch(() => {});
  }
  setState({isActive: false, stepIndex: 0});
  showTab('Stores');
}

export const tutorial = {
  /**
   * Starts the tour for `uid` unless this device has already shown it to that
   * account. The short delay lets the Stores tab draw first, the way iOS waits
   * on the first profile load.
   */
  async startIfNeeded(uid: string) {
    currentUid = uid;
    if (state.isActive) {
      return;
    }
    let completed = false;
    try {
      completed = (await AsyncStorage.getItem(completionKey(uid))) === 'true';
    } catch (_) {
      // Unknown is treated as done: a tour that shows up on every launch is
      // worse than one that is missed.
      completed = true;
    }
    if (completed || currentUid !== uid) {
      return;
    }
    if (startTimer) {
      clearTimeout(startTimer);
    }
    startTimer = setTimeout(() => {
      startTimer = null;
      if (currentUid === uid && !state.isActive) {
        showTab('Stores');
        setState({isActive: true, stepIndex: 0});
      }
    }, 800);
  },

  /** Signed out or switched accounts: drop any tour in progress. */
  reset() {
    if (startTimer) {
      clearTimeout(startTimer);
      startTimer = null;
    }
    currentUid = null;
    if (state.isActive) {
      setState({isActive: false, stepIndex: 0});
    }
  },

  advance() {
    const nextIndex = state.stepIndex + 1;
    if (nextIndex >= TUTORIAL_STEPS.length) {
      complete();
      return;
    }
    const next = TUTORIAL_STEPS[nextIndex];
    showTab(next.tab);
    setState({isActive: true, stepIndex: nextIndex});
  },

  skip: complete,
  finish: complete,

  /** Re-reads a control's frame — after a tab switch has had time to settle. */
  remeasure(id: string) {
    measurers.get(id)?.();
  },

  frameFor(id: string): TargetFrame | undefined {
    return frames.get(id);
  },
};

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

function subscribeFrames(listener: () => void) {
  frameListeners.add(listener);
  return () => {
    frameListeners.delete(listener);
  };
}

function reportFrame(id: string, frame: TargetFrame) {
  if (frame.width <= 0 || frame.height <= 0) {
    return;
  }
  const previous = frames.get(id);
  if (
    previous &&
    previous.x === frame.x &&
    previous.y === frame.y &&
    previous.width === frame.width &&
    previous.height === frame.height
  ) {
    return;
  }
  frames.set(id, frame);
  frameVersion += 1;
  frameListeners.forEach(listener => listener());
}

/** The current tutorial state; re-renders when it changes. */
export function useTutorial(): State & {step: TutorialStep} {
  const snapshot = useSyncExternalStore(subscribe, () => state);
  return {...snapshot, step: TUTORIAL_STEPS[snapshot.stepIndex]};
}

/** True while the tour is on screen — screens swap in their mock data. */
export function useTutorialActive(): boolean {
  return useSyncExternalStore(subscribe, () => state.isActive);
}

/** A counter that ticks whenever a registered frame changes. */
export function useTutorialFrameVersion(): number {
  return useSyncExternalStore(subscribeFrames, () => frameVersion);
}

/**
 * Registers a control the tutorial can highlight. Spread the result onto the
 * View that wraps it. Port of the iOS `.tutorialHighlight(id:)` modifier.
 */
export function useTutorialTarget(id: string) {
  const ref = useRef<View>(null);

  const measure = useCallback(() => {
    ref.current?.measureInWindow((x, y, width, height) => {
      reportFrame(id, {x, y, width, height});
    });
  }, [id]);

  useEffect(() => {
    measurers.set(id, measure);
    return () => {
      if (measurers.get(id) === measure) {
        measurers.delete(id);
      }
    };
  }, [id, measure]);

  return {ref, onLayout: measure, collapsable: false as const};
}
