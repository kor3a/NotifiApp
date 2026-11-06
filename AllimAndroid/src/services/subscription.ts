import {User} from '../models';

// What a subscription unlocks, in one place for every screen and service.
// Mirrors the iOS SubscriptionManager, and firestore.rules enforces the same
// limit for writes that come from anywhere else.

// iOS SubscriptionManager.freeStoreLimit.
export const FREE_STORE_LIMIT = 5;

type Access = Pick<User, 'isSubscribed' | 'adminSubscribed'>;

// isSubscribed comes from a purchase; adminSubscribed is granted by hand in
// Firestore. Anything other than true, including a missing field, is no access.
export function hasPremiumAccess(user: Access | null | undefined): boolean {
  return user?.isSubscribed === true || user?.adminSubscribed === true;
}

// Whether a user may add another store themselves, checked against the current
// count at add time. Someone already over the limit keeps every store, but can't
// add more without a subscription. Stores accepted from a share count toward the
// limit, but accepting one is never blocked (storeShareService.acceptSharedStore).
export function canAddStore(
  isPremium: boolean,
  currentStoreCount: number,
): boolean {
  return isPremium || currentStoreCount < FREE_STORE_LIMIT;
}

// Applies a fresh copy of the profile to the signed-in user. Returns the same
// object unless access changed, so writes to other fields of the document (the
// push token, for one) don't re-render or re-subscribe everything that depends
// on the user.
export function withLatestAccess<T extends Access & {userId: string}>(
  current: T | null,
  latest: (Access & {userId: string}) | null,
): T | null {
  if (
    !current ||
    !latest ||
    latest.userId !== current.userId ||
    (latest.isSubscribed === current.isSubscribed &&
      latest.adminSubscribed === current.adminSubscribed)
  ) {
    return current;
  }
  return {
    ...current,
    isSubscribed: latest.isSubscribed,
    adminSubscribed: latest.adminSubscribed,
  };
}

const STORE_LIMIT_CODE = 'store-limit-reached';

// Thrown by storeService.addStore. The screen shows the paywall instead of an
// error message.
export function storeLimitError(): Error {
  return Object.assign(
    new Error(`Free accounts are limited to ${FREE_STORE_LIMIT} stores.`),
    {code: STORE_LIMIT_CODE},
  );
}

export function isStoreLimitError(error: unknown): boolean {
  return (error as {code?: string} | null)?.code === STORE_LIMIT_CODE;
}
