import {useSyncExternalStore} from 'react';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {navigationRef} from '../navigation/navigationRef';

/**
 * The new-user tutorial: a short playable story drawn over the whole app
 * rather than a tour of the live UI — an opening page, five hands-on chapters
 * the user taps, drags and holds their way through, and a closing cheat sheet.
 * Port of the iOS TutorialManager / TutorialStep.
 */

export type TutorialStepId =
  | 'intro'
  | 'addStore'
  | 'smartSort'
  | 'nearby'
  | 'shortcuts'
  | 'share'
  | 'finale';

export type TutorialStep = {
  id: TutorialStepId;
  /** The short subject that sits beside the chapter number. */
  eyebrow: string;
  title: string;
  description: string;
  /** What the user is asked to do in the chapter's demo. */
  hint?: string;
  /** What replaces the hint once they have done it. */
  doneNote?: string;
};

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    id: 'intro',
    eyebrow: 'Welcome to Allim',
    title: 'Your list knows\nwhere you are.',
    description:
      "Take the one-minute tour. Nothing to read through — you'll try each thing yourself.",
  },
  {
    id: 'addStore',
    eyebrow: 'Stores',
    title: 'Start with a store.',
    description: 'Every list in Allim belongs to a place you shop. The + button adds one.',
    hint: 'Tap the + button',
    doneNote: "That's it — your first store",
  },
  {
    id: 'smartSort',
    eyebrow: 'Smart Category',
    title: 'Add items.\nAllim sorts them.',
    description:
      'Type things in any order. Smart Category files each one under Produce, Dairy, Bakery and so on.',
    hint: 'Tap a few items to add them',
    doneNote: 'Sorted, without lifting a finger',
  },
  {
    id: 'nearby',
    eyebrow: 'Nearby alerts',
    title: "Get nudged when you're close.",
    description:
      'When you come near a saved store, Allim sends your list for it — before you drive past.',
    hint: 'Drag yourself to the store',
    doneNote: 'Right on time',
  },
  {
    id: 'shortcuts',
    eyebrow: 'Shortcuts',
    title: 'Everything is one press away.',
    description:
      "Touch and hold an item to mark it out of stock, move it, or add a photo. The ⓘ button holds the list's settings.",
    hint: 'Touch and hold an item, or tap ⓘ',
    doneNote: 'Found it',
  },
  {
    id: 'share',
    eyebrow: 'Sharing',
    title: 'Shop together.',
    description:
      'Share a store with friends, and keep Family at the front of the line. They see changes as you make them.',
    hint: 'Tap someone to share the list',
    doneNote: "Shared — they'll see it live",
  },
  {
    id: 'finale',
    eyebrow: "That's the tour",
    title: "You're all set.",
    description:
      "Here's where everything lives. Add your first store and Allim takes it from there.",
  },
];

/** The hands-on chapters, in order. These are what the progress bar counts. */
export const TUTORIAL_CHAPTERS = TUTORIAL_STEPS.filter(
  s => s.id !== 'intro' && s.id !== 'finale',
);

type State = {
  isActive: boolean;
  stepIndex: number;
  /**
   * Chapters whose demo the user has played through. Drives the hint under
   * the demo and how loudly Next asks to be pressed; it never gates anything.
   */
  done: TutorialStepId[];
};

const IDLE: State = {isActive: false, stepIndex: 0, done: []};

let state: State = IDLE;
let currentUid: string | null = null;
let startTimer: ReturnType<typeof setTimeout> | null = null;
const listeners = new Set<() => void>();

function setState(next: State) {
  state = next;
  listeners.forEach(listener => listener());
}

function completionKey(uid: string) {
  return `hasCompletedTutorial_auth_${uid}`;
}

function complete() {
  if (currentUid) {
    AsyncStorage.setItem(completionKey(currentUid), 'true').catch(() => {});
  }
  setState(IDLE);
  // The tutorial covers the whole screen, so whatever tab was underneath is a
  // surprise; land on Stores, where the first thing to do is.
  if (navigationRef.isReady()) {
    navigationRef.navigate('Tabs', {screen: 'Stores'});
  }
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
        setState({isActive: true, stepIndex: 0, done: []});
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
      setState(IDLE);
    }
  },

  advance() {
    if (state.stepIndex + 1 >= TUTORIAL_STEPS.length) {
      complete();
      return;
    }
    setState({...state, stepIndex: state.stepIndex + 1});
  },

  back() {
    if (state.stepIndex > 0) {
      setState({...state, stepIndex: state.stepIndex - 1});
    }
  },

  /** Called by a chapter's demo the first time the user completes it. */
  markDone(id: TutorialStepId) {
    if (state.isActive && !state.done.includes(id)) {
      setState({...state, done: [...state.done, id]});
    }
  },

  skip: complete,
  finish: complete,
};

function subscribe(listener: () => void) {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

/** The current tutorial state; re-renders when it changes. */
export function useTutorial(): State & {step: TutorialStep; isDone: boolean} {
  const snapshot = useSyncExternalStore(subscribe, () => state);
  const step = TUTORIAL_STEPS[snapshot.stepIndex];
  return {...snapshot, step, isDone: snapshot.done.includes(step.id)};
}

/** True while the tour is on screen — screens swap in their mock data. */
export function useTutorialActive(): boolean {
  return useSyncExternalStore(subscribe, () => state.isActive);
}
