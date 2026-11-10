import {storeService} from '../storeService';

const STORE_LIMIT = {code: 'store-limit-reached'};

// Just enough Firestore for addStore: the user's stores, their profile, and the
// write itself.
let mockStoreDocs: {data: () => object}[] = [];
let mockProfile: object | null = null;
const mockAdd = jest.fn();

jest.mock('@react-native-firebase/storage', () => () => ({}));
jest.mock('../storeShareService', () => ({}));
jest.mock('../storeSharing', () => ({}));
jest.mock('@react-native-firebase/firestore', () => () => ({
  collection: (name: string) => ({
    where: () => ({
      get: async () =>
        name === 'users'
          ? {
              empty: !mockProfile,
              docs: mockProfile
                ? [{id: 'tester', data: () => mockProfile}]
                : [],
            }
          : {docs: mockStoreDocs},
    }),
    add: mockAdd,
  }),
}));

function givenStores(count: number) {
  mockStoreDocs = Array.from({length: count}, (_, i) => ({
    data: () => ({sortOrder: i}),
  }));
}

const add = () => storeService.addStore('tester', 'tester@allim.test', 'New Store');

beforeEach(() => {
  mockAdd.mockReset();
  mockAdd.mockResolvedValue({id: 'new'});
});

describe('addStore', () => {
  it('adds for a free account below the limit', async () => {
    givenStores(4);
    mockProfile = {userId: 'tester', isSubscribed: false, adminSubscribed: false};
    await add();
    expect(mockAdd).toHaveBeenCalledWith(
      expect.objectContaining({
        userId: 'tester',
        permission: 'owner',
        sortOrder: 4,
      }),
    );
  });

  it('refuses a free account at the limit, without writing', async () => {
    givenStores(5);
    mockProfile = {userId: 'tester', isSubscribed: false, adminSubscribed: false};
    await expect(add()).rejects.toMatchObject(STORE_LIMIT);
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('refuses a free account already over the limit', async () => {
    givenStores(8);
    mockProfile = {userId: 'tester'};
    await expect(add()).rejects.toMatchObject(STORE_LIMIT);
    expect(mockAdd).not.toHaveBeenCalled();
  });

  it('adds past the limit for a subscriber', async () => {
    givenStores(8);
    mockProfile = {userId: 'tester', isSubscribed: true};
    await add();
    expect(mockAdd).toHaveBeenCalledTimes(1);
  });

  it('adds past the limit with a hand-granted override', async () => {
    givenStores(8);
    mockProfile = {userId: 'tester', adminSubscribed: true};
    await add();
    expect(mockAdd).toHaveBeenCalledTimes(1);
  });

  it('treats the rules refusing the write as the limit too', async () => {
    givenStores(3);
    mockProfile = {userId: 'tester'};
    mockAdd.mockRejectedValue(
      Object.assign(new Error('denied'), {code: 'firestore/permission-denied'}),
    );
    await expect(add()).rejects.toMatchObject(STORE_LIMIT);
  });

  it('passes other failures through', async () => {
    givenStores(3);
    mockProfile = {userId: 'tester'};
    mockAdd.mockRejectedValue(new Error('offline'));
    await expect(add()).rejects.toThrow('offline');
  });
});
