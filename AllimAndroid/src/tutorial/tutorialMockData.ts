import {Conversation, UserStoreItem} from '../models';

/**
 * Stand-in data the Stores and Messages tabs show while the tutorial runs, so a
 * brand-new account has something for the tour to point at. Port of the iOS
 * TutorialMockData. None of it is written to Firestore, and the overlay keeps
 * every touch off it.
 */
export const TUTORIAL_STORES: UserStoreItem[] = [
  {
    id: 'tutorial_us_1',
    store: {id: 'tutorial_whole-foods', name: 'Whole Foods', reminderCount: 3},
    permission: 'owner',
    isShared: false,
  },
  {
    id: 'tutorial_us_2',
    store: {id: 'tutorial_target', name: 'Target', reminderCount: 2},
    permission: 'owner',
    isShared: false,
  },
  {
    id: 'tutorial_us_3',
    store: {id: 'tutorial_cvs', name: 'CVS Pharmacy', reminderCount: 1},
    permission: 'owner',
    isShared: false,
  },
];

/** Built around the real user ID so the rows resolve the other person's name. */
export function tutorialConversations(currentUserId: string): Conversation[] {
  const now = Date.now() / 1000;
  return [
    {
      id: 'tutorial_conv_1',
      participantIds: [currentUserId, 'tutorial_mom'],
      participantNames: {[currentUserId]: 'You', tutorial_mom: 'Mom'},
      createdAt: now - 3600,
      lastMessageContent: "Don't forget the milk! 🥛",
      lastMessageAt: now - 60,
      lastMessageSenderId: 'tutorial_mom',
      unreadCount: {[currentUserId]: 1},
    },
    {
      id: 'tutorial_conv_2',
      participantIds: [currentUserId, 'tutorial_alex'],
      participantNames: {[currentUserId]: 'You', tutorial_alex: 'Alex'},
      createdAt: now - 86400,
      lastMessageContent: 'Did you pick up the groceries?',
      lastMessageAt: now - 86400,
      lastMessageSenderId: 'tutorial_alex',
      unreadCount: {[currentUserId]: 0},
    },
  ];
}
