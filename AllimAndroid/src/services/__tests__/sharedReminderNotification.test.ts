import {sendReminderChangeNotifications} from '../sharedReminderNotificationService';

// user_stores documents, by id and by the field a query filters on.
type Doc = {id: string; data: {[k: string]: any}};
let mockUserStores: Doc[] = [];
let mockAuthEmail: string | null = 'me@allim.test';
const mockSet = jest.fn();
const mockCommit = jest.fn();

jest.mock('@react-native-firebase/auth', () => () => ({
  get currentUser() {
    return mockAuthEmail ? {email: mockAuthEmail} : null;
  },
}));

jest.mock('@react-native-firebase/firestore', () => () => {
  let nextId = 0;
  const wrap = (d: Doc) => ({id: d.id, exists: true, data: () => d.data});
  return {
    collection: (name: string) => ({
      where: (field: string, _op: string, value: any) => ({
        get: async () => ({
          docs: mockUserStores.filter(d => d.data[field] === value).map(wrap),
        }),
      }),
      doc: (id?: string) => {
        if (name === 'user_stores' && id) {
          const found = mockUserStores.find(d => d.id === id);
          return {
            get: async () =>
              found ? wrap(found) : {id, exists: false, data: () => undefined},
          };
        }
        return {id: id ?? `notif-${nextId++}`, collection: name};
      },
    }),
    batch: () => ({set: mockSet, commit: mockCommit}),
  };
});

const changes = {addedCount: 2, otherChangeCount: 1};

beforeEach(() => {
  mockSet.mockReset();
  mockCommit.mockReset();
  mockCommit.mockResolvedValue(undefined);
  mockAuthEmail = 'me@allim.test';
  mockUserStores = [
    // The owner's store, and two people it was shared with.
    {id: 'owner-us', data: {userId: 'owner', userEmail: 'owner@allim.test'}},
    {
      id: 'me-us',
      data: {userId: 'me', userEmail: 'me@allim.test', sourceUserStoreId: 'owner-us'},
    },
    {
      id: 'friend-us',
      data: {
        userId: 'friend',
        userEmail: 'friend@allim.test',
        sourceUserStoreId: 'owner-us',
      },
    },
  ];
});

function payloads() {
  return mockSet.mock.calls.map(call => call[1]);
}

describe('sendReminderChangeNotifications', () => {
  it('notifies the owner and the other recipients, not the sender', async () => {
    const sent = await sendReminderChangeNotifications({
      store: {id: 'me-us', permission: 'edit', sourceUserStoreId: 'owner-us'},
      storeName: 'Costco',
      changes,
      currentUserId: 'me',
      currentUserName: 'Me',
    });
    expect(sent).toBe(2);
    expect(payloads().map(p => p.recipientUserId).sort()).toEqual([
      'friend',
      'owner',
    ]);
    expect(payloads()[0]).toEqual({
      recipientUserId: expect.any(String),
      recipientEmail: expect.any(String),
      senderName: 'Me',
      senderEmail: 'me@allim.test',
      storeName: 'Costco',
      addedCount: 2,
      otherChangeCount: 1,
      createdAt: expect.any(Number),
    });
    expect(mockCommit).toHaveBeenCalledTimes(1);
  });

  it('notifies every recipient when the owner edits', async () => {
    mockAuthEmail = 'owner@allim.test';
    const sent = await sendReminderChangeNotifications({
      store: {id: 'owner-us', permission: 'owner'},
      storeName: 'Costco',
      changes,
      currentUserId: 'owner',
      currentUserName: 'Owner',
    });
    expect(sent).toBe(2);
    expect(payloads().map(p => p.recipientUserId).sort()).toEqual([
      'friend',
      'me',
    ]);
  });

  it('skips members who turned notifications off for the store', async () => {
    mockUserStores[2].data.notificationsEnabled = false;
    await sendReminderChangeNotifications({
      store: {id: 'me-us', permission: 'edit', sourceUserStoreId: 'owner-us'},
      storeName: 'Costco',
      changes,
      currentUserId: 'me',
      currentUserName: 'Me',
    });
    expect(payloads().map(p => p.recipientUserId)).toEqual(['owner']);
  });

  it('writes nothing when there were no changes', async () => {
    const sent = await sendReminderChangeNotifications({
      store: {id: 'owner-us', permission: 'owner'},
      storeName: 'Costco',
      changes: {addedCount: 0, otherChangeCount: 0},
      currentUserId: 'owner',
      currentUserName: 'Owner',
    });
    expect(sent).toBe(0);
    expect(mockCommit).not.toHaveBeenCalled();
  });

  it('writes nothing when nobody else is on the store', async () => {
    mockUserStores = [
      {id: 'solo-us', data: {userId: 'me', userEmail: 'me@allim.test'}},
    ];
    const sent = await sendReminderChangeNotifications({
      store: {id: 'solo-us', permission: 'owner'},
      storeName: 'Costco',
      changes,
      currentUserId: 'me',
      currentUserName: 'Me',
    });
    expect(sent).toBe(0);
    expect(mockCommit).not.toHaveBeenCalled();
  });
});
