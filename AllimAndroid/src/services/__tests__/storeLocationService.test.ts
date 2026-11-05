import {
  isSameStore,
  pickBranches,
  searchTile,
} from '../storeLocationService';

jest.mock('@react-native-async-storage/async-storage', () => ({}));
jest.mock('@react-native-firebase/functions', () => () => ({}));
jest.mock('react-native-geolocation-service', () => ({}));

describe('searchTile', () => {
  it('gives nearby points the same tile', () => {
    expect(searchTile({latitude: 34.1201, longitude: -117.7102})).toEqual(
      searchTile({latitude: 34.1349, longitude: -117.6951}),
    );
  });

  it('separates points a tile apart', () => {
    expect(searchTile({latitude: 34.1, longitude: -117.7})).not.toEqual(
      searchTile({latitude: 34.2, longitude: -117.7}),
    );
  });
});

describe('isSameStore', () => {
  it('matches a branch name that extends the store name', () => {
    expect(isSameStore('H Mart', 'H Mart Diamond Bar')).toBe(true);
  });

  it('matches a place name shorter than the store name', () => {
    expect(isSameStore('Starbucks Coffee Company', 'Starbucks')).toBe(true);
  });

  it('ignores punctuation and symbols', () => {
    expect(isSameStore("Trader Joe's", 'Trader Joes')).toBe(true);
    expect(isSameStore('85°C Bakery Cafe', '85C Bakery Cafe')).toBe(true);
  });

  it('keeps names in non-Latin scripts', () => {
    expect(isSameStore('한남체인', '한남체인 LA')).toBe(true);
    expect(isSameStore('한남체인', '갤러리아')).toBe(false);
  });

  it('rejects a different store', () => {
    expect(isSameStore('Vons', 'Ralphs')).toBe(false);
  });

  it('never matches on an empty name', () => {
    expect(isSameStore('', 'Vons')).toBe(false);
    expect(isSameStore('Vons', "'")).toBe(false);
  });
});

describe('pickBranches', () => {
  const center = {latitude: 34, longitude: -117};
  const place = (name: string, latitude: number) => ({
    name,
    latitude,
    longitude: -117,
  });

  it('drops other stores and sorts nearest first', () => {
    const picked = pickBranches(
      'Vons',
      [place('Vons', 34.5), place('Ralphs', 34.01), place('Vons', 34.1)],
      center,
    );
    expect(picked.map(b => b.latitude)).toEqual([34.1, 34.5]);
  });

  it('caps the number of branches at ten', () => {
    const many = Array.from({length: 20}, (_, i) => place('Vons', 34 + i / 100));
    // Each a separate spot, so only the cap can limit them.
    expect(pickBranches('Vons', many, center)).toHaveLength(10);
  });

  it('keeps one branch when a place is listed twice', () => {
    const picked = pickBranches(
      'Vons',
      [place('Vons', 34.1), place('Vons Pharmacy', 34.1)],
      center,
    );
    expect(picked).toHaveLength(1);
  });

  it('counts departments of one building as one branch', () => {
    const picked = pickBranches(
      'Vons',
      [place('Vons', 34.1), place('Vons Bakery', 34.1003)],
      center,
    );
    expect(picked.map(b => b.name)).toEqual(['Vons']);
  });

  it('keeps two branches a few blocks apart', () => {
    const picked = pickBranches(
      'Vons',
      [place('Vons', 34.1), place('Vons', 34.11)],
      center,
    );
    expect(picked).toHaveLength(2);
  });

  it('gives each branch an id from its position', () => {
    expect(pickBranches('Vons', [place('Vons', 34.1)], center)[0].id).toBe(
      '34.1_-117',
    );
  });
});
