import {activeReminderCount} from '../storeService';

jest.mock('@react-native-firebase/firestore', () => () => ({}));
jest.mock('@react-native-firebase/storage', () => () => ({}));
jest.mock('../storeShareService', () => ({}));
jest.mock('../storeSharing', () => ({}));

const doc = (fields: {isDone?: boolean; isOutOfStock?: boolean}) => ({
  data: () => fields,
});

describe('activeReminderCount', () => {
  it('counts unchecked items', () => {
    expect(
      activeReminderCount([doc({isDone: false}), doc({}), doc({isDone: false})]),
    ).toBe(3);
  });

  it('leaves checked items out', () => {
    expect(
      activeReminderCount([
        doc({isDone: true}),
        doc({isDone: true}),
        doc({isDone: true}),
        doc({isDone: true}),
      ]),
    ).toBe(0);
  });

  it('keeps out-of-stock items in, checked or not', () => {
    expect(
      activeReminderCount([
        doc({isDone: false, isOutOfStock: true}),
        doc({isDone: true, isOutOfStock: true}),
        doc({isDone: true}),
        doc({isDone: false}),
      ]),
    ).toBe(3);
  });
});
