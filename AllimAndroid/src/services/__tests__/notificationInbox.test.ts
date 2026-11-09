import {notificationInbox} from '../notificationInbox';

// Just enough Firestore for the inbox: a query per collection whose snapshot
// listener the test drives by hand, and a delete per document.
type Listener = {
  collection: string;
  field: string;
  value: string;
  onNext: (snapshot: any) => void;
  unsubscribe: jest.Mock;
};
let mockListeners: Listener[] = [];
const mockDelete = jest.fn();

jest.mock('@react-native-firebase/firestore', () => () => ({
  collection: (collection: string) => ({
    where: (field: string, _op: string, value: string) => ({
      onSnapshot: (onNext: (snapshot: any) => void) => {
        const unsubscribe = jest.fn();
        mockListeners.push({collection, field, value, onNext, unsubscribe});
        return unsubscribe;
      },
    }),
  }),
}));

function change(type: string, path: string) {
  return {type, doc: {ref: {path, delete: () => mockDelete(path)}}};
}

function emit(collection: string, changes: object[]) {
  const listener = mockListeners.find(l => l.collection === collection);
  if (!listener) {
    throw new Error(`no listener on ${collection}`);
  }
  listener.onNext({docChanges: () => changes});
}

const flush = () => new Promise<void>(resolve => setImmediate(resolve));

beforeEach(() => {
  notificationInbox.stop();
  mockListeners = [];
  mockDelete.mockReset();
  mockDelete.mockResolvedValue(undefined);
});

describe('notificationInbox', () => {
  it('listens on both collections for the signed-in email', () => {
    notificationInbox.start('me@allim.test');

    expect(
      mockListeners.map(({collection, field, value}) => [
        collection,
        field,
        value,
      ]),
    ).toEqual([
      ['reminder_change_notifications', 'recipientEmail', 'me@allim.test'],
      ['on_my_way_notifications', 'recipientEmail', 'me@allim.test'],
    ]);
  });

  it('deletes each document addressed to the user, once', () => {
    notificationInbox.start('me@allim.test');

    emit('reminder_change_notifications', [
      change('added', 'reminder_change_notifications/a'),
      change('added', 'reminder_change_notifications/b'),
    ]);
    emit('on_my_way_notifications', [
      change('added', 'on_my_way_notifications/c'),
    ]);
    // A reconnect that reports a document again before its delete lands, and
    // the removal that the delete itself causes.
    emit('reminder_change_notifications', [
      change('added', 'reminder_change_notifications/a'),
      change('removed', 'reminder_change_notifications/b'),
    ]);

    expect(mockDelete.mock.calls).toEqual([
      ['reminder_change_notifications/a'],
      ['reminder_change_notifications/b'],
      ['on_my_way_notifications/c'],
    ]);
  });

  it('retries a delete that failed', async () => {
    jest.spyOn(console, 'warn').mockImplementation(() => {});
    mockDelete.mockRejectedValueOnce(new Error('unavailable'));
    notificationInbox.start('me@allim.test');

    emit('on_my_way_notifications', [
      change('added', 'on_my_way_notifications/c'),
    ]);
    await flush();
    emit('on_my_way_notifications', [
      change('added', 'on_my_way_notifications/c'),
    ]);

    expect(mockDelete).toHaveBeenCalledTimes(2);
  });

  it('keeps one set of listeners when started again for the same email', () => {
    notificationInbox.start('me@allim.test');
    notificationInbox.start('me@allim.test');

    expect(mockListeners).toHaveLength(2);
  });

  it('stops listening on sign-out', () => {
    notificationInbox.start('me@allim.test');
    notificationInbox.stop();

    mockListeners.forEach(l => expect(l.unsubscribe).toHaveBeenCalled());
  });

  it('moves to the new account when another one signs in', () => {
    notificationInbox.start('me@allim.test');
    const previous = [...mockListeners];
    notificationInbox.start('you@allim.test');

    previous.forEach(l => expect(l.unsubscribe).toHaveBeenCalled());
    expect(mockListeners.slice(2).map(l => l.value)).toEqual([
      'you@allim.test',
      'you@allim.test',
    ]);
  });
});
