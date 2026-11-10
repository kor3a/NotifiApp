import {Conversation, totalUnreadCount} from '../../models';

const convo = (unreadCount?: {[uid: string]: number}): Conversation => ({
  id: Math.random().toString(),
  participantIds: ['me', 'friend'],
  unreadCount,
});

describe('totalUnreadCount', () => {
  it('adds up this user’s unread messages across conversations', () => {
    expect(
      totalUnreadCount(
        [convo({me: 2, friend: 5}), convo({me: 1}), convo({me: 0, friend: 3})],
        'me',
      ),
    ).toBe(3);
  });

  it('is 0 when everything has been read', () => {
    expect(totalUnreadCount([convo({me: 0}), convo({friend: 4})], 'me')).toBe(0);
  });

  it('skips conversations with no unread field', () => {
    expect(totalUnreadCount([convo(), convo({me: 4})], 'me')).toBe(4);
  });

  it('is 0 with no conversations', () => {
    expect(totalUnreadCount([], 'me')).toBe(0);
  });
});
