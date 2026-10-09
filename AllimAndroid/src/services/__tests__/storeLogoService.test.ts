import {
  bestLogoKey,
  canonicalLogoKey,
  guessedDomain,
  logoKeyFor,
  mappedDomain,
} from '../storeLogoService';

jest.mock('@react-native-async-storage/async-storage', () => ({}));
jest.mock('@react-native-firebase/firestore', () => () => ({}));
jest.mock('@react-native-firebase/functions', () => () => ({}));
jest.mock('expo-constants', () => ({expoConfig: {extra: {}}}));

describe('canonicalLogoKey', () => {
  it('drops symbols and collapses separators', () => {
    expect(canonicalLogoKey('85°c-bakery-cafe')).toBe('85c-bakery-cafe');
    expect(canonicalLogoKey('85C Bakery  Cafe')).toBe('85c-bakery-cafe');
    expect(canonicalLogoKey('-a-°-b-')).toBe('a-b');
  });

  it('keeps non-Latin letters', () => {
    expect(canonicalLogoKey('한아름 마트')).toBe('한아름-마트');
  });
});

describe('bestLogoKey', () => {
  const keys = ['walmart', 'trader-joes', '85°c-bakery-cafe', 'h-mart'];

  it('matches a store name with a suffix to its brand', () => {
    expect(bestLogoKey(keys, logoKeyFor('Walmart Supercenter'))).toBe(
      'walmart',
    );
  });

  it('matches across punctuation differences', () => {
    expect(bestLogoKey(keys, logoKeyFor("Trader Joe's"))).toBe('trader-joes');
    expect(bestLogoKey(keys, logoKeyFor('85C Bakery Cafe'))).toBe(
      '85°c-bakery-cafe',
    );
  });

  it('has nothing for an unknown store', () => {
    expect(bestLogoKey(keys, logoKeyFor('Rosalind Bakery'))).toBeUndefined();
  });
});

describe('mappedDomain', () => {
  it('uses the map for names whose domain differs', () => {
    expect(mappedDomain(logoKeyFor('Whole Foods Market'))).toBe(
      'wholefoodsmarket.com',
    );
    expect(mappedDomain(logoKeyFor('The Home Depot'))).toBe('homedepot.com');
    expect(mappedDomain(logoKeyFor('Costco Wholesale'))).toBe('costco.com');
  });

  it('strips a business suffix only to re-check the map', () => {
    expect(mappedDomain(logoKeyFor('Chase Bank'))).toBe('chase.com');
    expect(mappedDomain(logoKeyFor('Rosalind Bakery'))).toBeUndefined();
  });
});

describe('guessedDomain', () => {
  it('joins the name into a .com', () => {
    expect(guessedDomain('zion-market')).toBe('zionmarket.com');
    expect(guessedDomain('starbucks')).toBe('starbucks.com');
  });

  it('skips civic places', () => {
    expect(guessedDomain('rancho-cucamonga-public-library')).toBeUndefined();
  });
});
