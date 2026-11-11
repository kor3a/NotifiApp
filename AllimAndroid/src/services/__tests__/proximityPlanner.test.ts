import {
  MAX_BRANCHES_PER_STORE,
  distanceMeters,
  groupStores,
  pickCandidates,
  proximityStoreKey,
} from '../proximityPlanner';

describe('groupStores', () => {
  it('folds rows naming the same store into one entry with every list behind it', () => {
    const entries = groupStores(
      [
        {storeName: 'H Mart', reminderStoreId: 'own', notificationsEnabled: true},
        {storeName: 'h mart ', reminderStoreId: 'shared', notificationsEnabled: true},
        {storeName: 'Costco', reminderStoreId: 'costco', notificationsEnabled: true},
      ],
      new Map([
        ['own', 2],
        ['shared', 3],
      ]),
    );
    expect(entries).toEqual([
      {key: 'h-mart', name: 'H Mart', reminderStoreIds: ['own', 'shared'], cachedCount: 5},
      {key: 'costco', name: 'Costco', reminderStoreIds: ['costco'], cachedCount: 0},
    ]);
  });

  it('counts a list two rows point at only once', () => {
    const [entry] = groupStores(
      [
        {storeName: 'Vons', reminderStoreId: 'same', notificationsEnabled: true},
        {storeName: 'Vons', reminderStoreId: 'same', notificationsEnabled: true},
      ],
      new Map([['same', 4]]),
    );
    expect(entry.reminderStoreIds).toEqual(['same']);
    expect(entry.cachedCount).toBe(4);
  });

  it('leaves out stores whose alerts are turned off', () => {
    expect(
      groupStores(
        [{storeName: 'Target', reminderStoreId: 't', notificationsEnabled: false}],
        new Map(),
      ),
    ).toEqual([]);
  });
});

describe('pickCandidates', () => {
  const here = {latitude: 34.0, longitude: -117.7};

  it('keeps the nearest branches within the search radius', () => {
    const branches = [
      {latitude: 34.05, longitude: -117.7}, // ~5.6 km
      {latitude: 34.001, longitude: -117.7}, // ~110 m
      {latitude: 34.5, longitude: -117.7}, // ~55 km — out of range
    ];
    expect(pickCandidates('vons', branches, here)).toEqual([
      {key: 'vons', latitude: 34.001, longitude: -117.7},
      {key: 'vons', latitude: 34.05, longitude: -117.7},
    ]);
  });

  it(`caps a store at ${MAX_BRANCHES_PER_STORE} branches`, () => {
    const branches = Array.from({length: 9}, (_, i) => ({
      latitude: 34 + i * 0.001,
      longitude: -117.7,
    }));
    expect(pickCandidates('vons', branches, here)).toHaveLength(MAX_BRANCHES_PER_STORE);
  });
});

describe('helpers', () => {
  it('normalizes store names to a stable key', () => {
    expect(proximityStoreKey("  Trader Joe's ")).toBe('trader-joes');
  });

  it('measures distance in meters', () => {
    const d = distanceMeters({latitude: 0, longitude: 0}, {latitude: 0.001, longitude: 0});
    expect(d).toBeGreaterThan(110);
    expect(d).toBeLessThan(112);
  });
});
