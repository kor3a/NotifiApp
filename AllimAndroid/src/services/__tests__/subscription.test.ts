import {
  FREE_STORE_LIMIT,
  canAddStore,
  hasPremiumAccess,
  isStoreLimitError,
  storeLimitError,
  withLatestAccess,
} from '../subscription';

describe('hasPremiumAccess', () => {
  it('accepts a purchase or a hand-granted override', () => {
    expect(hasPremiumAccess({isSubscribed: true})).toBe(true);
    expect(hasPremiumAccess({adminSubscribed: true})).toBe(true);
    expect(hasPremiumAccess({isSubscribed: false, adminSubscribed: true})).toBe(true);
  });

  it('treats removed or missing access as none', () => {
    expect(hasPremiumAccess({isSubscribed: false, adminSubscribed: false})).toBe(false);
    expect(hasPremiumAccess({})).toBe(false);
    expect(hasPremiumAccess(null)).toBe(false);
    expect(hasPremiumAccess(undefined)).toBe(false);
  });

  it('only counts a real true, as iOS does', () => {
    // A field edited by hand in the console can end up as a string.
    expect(hasPremiumAccess({adminSubscribed: 'false' as unknown as boolean})).toBe(false);
  });
});

describe('canAddStore', () => {
  it('lets a free account add up to the limit', () => {
    expect(FREE_STORE_LIMIT).toBe(5);
    expect(canAddStore(false, 0)).toBe(true);
    expect(canAddStore(false, 4)).toBe(true);
    expect(canAddStore(false, 5)).toBe(false);
  });

  it('blocks a free account that is already over the limit', () => {
    expect(canAddStore(false, 9)).toBe(false);
  });

  it('never limits a subscriber', () => {
    expect(canAddStore(true, 5)).toBe(true);
    expect(canAddStore(true, 50)).toBe(true);
  });
});

describe('withLatestAccess', () => {
  const user = {userId: 'a', name: 'A', isSubscribed: false, adminSubscribed: true};

  it('applies a revocation and leaves the other fields alone', () => {
    const next = withLatestAccess(user, {
      userId: 'a',
      isSubscribed: false,
      adminSubscribed: false,
    });
    expect(next).toEqual({...user, adminSubscribed: false});
  });

  it('applies a field that was deleted rather than set false', () => {
    const next = withLatestAccess(user, {userId: 'a', isSubscribed: false});
    expect(hasPremiumAccess(next)).toBe(false);
  });

  it('keeps the same object when access did not change', () => {
    expect(
      withLatestAccess(user, {userId: 'a', isSubscribed: false, adminSubscribed: true}),
    ).toBe(user);
  });

  it('ignores another account and a missing document', () => {
    expect(withLatestAccess(user, {userId: 'b', adminSubscribed: false})).toBe(user);
    expect(withLatestAccess(user, null)).toBe(user);
    expect(withLatestAccess(null, {userId: 'a'})).toBeNull();
  });
});

describe('store limit error', () => {
  it('is recognised, and other errors are not', () => {
    expect(isStoreLimitError(storeLimitError())).toBe(true);
    expect(isStoreLimitError(new Error('offline'))).toBe(false);
    expect(isStoreLimitError(null)).toBe(false);
  });
});
