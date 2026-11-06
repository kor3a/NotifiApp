// The free-tier store limit, enforced by firestore.rules from the count that
// functions/storeCounts.js keeps. Run with `npm test` in this folder.
const {readFileSync} = require('node:fs');
const {createRequire} = require('node:module');
const {join} = require('node:path');
const {after, before, beforeEach, test} = require('node:test');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} = require('firebase/firestore');

const PROJECT = 'demo-allim-rules';
process.env.GCLOUD_PROJECT = PROJECT;
// The Admin SDK instance functions/storeCounts.js itself will use.
const requireFromFunctions = createRequire(join(__dirname, '../functions/index.js'));
const {initializeApp} = requireFromFunctions('firebase-admin/app');
const {getFirestore} = requireFromFunctions('firebase-admin/firestore');
const {
  backfillCounts,
  recountUserStores,
  userIdsToRecount,
} = require('../functions/storeCounts');

const EMAIL = 'free@allim.test';
let env;
let admin;

function client(email = EMAIL) {
  return env.authenticatedContext(email, {email}).firestore();
}

const ownStore = (name = 'New Store', userId = 'tester', userEmail = EMAIL) => ({
  userId,
  userEmail,
  storeId: name.toLowerCase().replace(/\s+/g, '-'),
  storeName: name,
  permission: 'owner',
  sortOrder: 0,
  addedAt: 1,
});

const sharedStore = () => ({
  ...ownStore('From A Friend'),
  permission: 'edit',
  sharedFrom: 'friend',
  sharedFromName: 'Friend',
  sourceUserStoreId: 'friends-store',
});

// Seeds with rules off, so the rules under test only see the client's write.
async function seed({stores, isSubscribed = false, adminSubscribed = false, counted = true}) {
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/tester'), {
      userId: 'tester',
      name: 'Tester',
      email: EMAIL,
      isSubscribed,
      adminSubscribed,
    });
    for (let i = 0; i < stores; i++) {
      await addDoc(collection(db, 'user_stores'), ownStore(`Store ${i}`));
    }
    if (counted && stores > 0) {
      await setDoc(doc(db, 'user_store_counts/tester'), {count: stores});
    }
  });
}

before(async () => {
  const [host, port] = process.env.FIRESTORE_EMULATOR_HOST.split(':');
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(join(__dirname, '../firestore.rules'), 'utf8'),
    },
  });
  initializeApp({projectId: PROJECT});
  admin = getFirestore();
});

beforeEach(() => env.clearFirestore());
after(() => env.cleanup());

// ─── The limit ───────────────────────────────────────────────────────────────

test('a free account below the limit can add a store', async () => {
  await seed({stores: 4});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), ownStore()));
});

test('a free account at the limit cannot add a store', async () => {
  await seed({stores: 5});
  await assertFails(addDoc(collection(client(), 'user_stores'), ownStore()));
});

test('a free account over the limit cannot add a store, and keeps what it has', async () => {
  await seed({stores: 7});
  const db = client();
  await assertFails(addDoc(collection(db, 'user_stores'), ownStore()));

  // Grandfathered stores stay usable: reads, edits and deletes aren't limited.
  await env.withSecurityRulesDisabled(ctx =>
    setDoc(doc(ctx.firestore(), 'user_stores/existing'), ownStore('Existing')),
  );
  await assertSucceeds(getDoc(doc(db, 'user_stores/existing')));
  await assertSucceeds(updateDoc(doc(db, 'user_stores/existing'), {sortOrder: 3}));
  await assertSucceeds(deleteDoc(doc(db, 'user_stores/existing')));
});

test('a store with no permission field counts as the user\'s own', async () => {
  await seed({stores: 5});
  const {permission, ...legacy} = ownStore();
  await assertFails(addDoc(collection(client(), 'user_stores'), legacy));
});

test('isSubscribed lets an account add past the limit', async () => {
  await seed({stores: 7, isSubscribed: true});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), ownStore()));
});

test('adminSubscribed lets an account add past the limit', async () => {
  await seed({stores: 7, adminSubscribed: true});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), ownStore()));
});

test('revoking access stops further adds on the next write', async () => {
  await seed({stores: 7, adminSubscribed: true});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), ownStore('Before')));
  await env.withSecurityRulesDisabled(ctx =>
    updateDoc(doc(ctx.firestore(), 'users/tester'), {adminSubscribed: false}),
  );
  await assertFails(addDoc(collection(client(), 'user_stores'), ownStore('After')));
});

test('premium on someone else\'s profile does not count', async () => {
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/paying'), {
      userId: 'paying',
      name: 'Paying',
      email: 'paying@allim.test',
      adminSubscribed: true,
    });
    await setDoc(doc(db, 'user_store_counts/paying'), {count: 9});
  });
  await assertFails(
    addDoc(collection(client(), 'user_stores'), ownStore('Sneaky', 'paying')),
  );
});

test('a shared store can always be accepted, even over the limit', async () => {
  await seed({stores: 7});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), sharedStore()));
});

test('an account with no count document yet can add (before the backfill)', async () => {
  await seed({stores: 7, counted: false});
  await assertSucceeds(addDoc(collection(client(), 'user_stores'), ownStore()));
});

test('stores can\'t be created under another account\'s email', async () => {
  await seed({stores: 0});
  await assertFails(
    addDoc(
      collection(client(), 'user_stores'),
      ownStore('Theirs', 'tester', 'other@allim.test'),
    ),
  );
});

// ─── The count and the premium flag can't be forged ──────────────────────────

test('clients cannot read or write store counts', async () => {
  await seed({stores: 7});
  const db = client();
  await assertFails(getDoc(doc(db, 'user_store_counts/tester')));
  await assertFails(setDoc(doc(db, 'user_store_counts/tester'), {count: 0}));
  await assertFails(deleteDoc(doc(db, 'user_store_counts/tester')));
});

test('a user cannot grant themselves adminSubscribed', async () => {
  await seed({stores: 0});
  await assertFails(updateDoc(doc(client(), 'users/tester'), {adminSubscribed: true}));
});

test('a new profile cannot start out with premium', async () => {
  const profile = {userId: 'tester', name: 'Tester', email: EMAIL};
  await assertFails(
    setDoc(doc(client(), 'users/tester'), {...profile, adminSubscribed: true}),
  );
  await assertFails(
    setDoc(doc(client(), 'users/tester'), {...profile, isSubscribed: true}),
  );
});

test('both signup shapes still work', async () => {
  const profile = {userId: 'tester', name: 'Tester', email: EMAIL};
  // Android writes both flags false.
  await assertSucceeds(
    setDoc(doc(client(), 'users/tester'), {
      ...profile,
      isSubscribed: false,
      adminSubscribed: false,
    }),
  );
  await env.clearFirestore();
  // iOS writes isSubscribed only.
  await assertSucceeds(
    setDoc(doc(client(), 'users/tester'), {...profile, isSubscribed: false}),
  );
});

test('ordinary profile edits still work, including what the iOS app syncs', async () => {
  await seed({stores: 0, adminSubscribed: true});
  const db = client();
  await assertSucceeds(updateDoc(doc(db, 'users/tester'), {name: 'New Name'}));
  await assertSucceeds(updateDoc(doc(db, 'users/tester'), {fcmToken: 'token'}));
  await assertSucceeds(updateDoc(doc(db, 'users/tester'), {isSubscribed: false}));
  await assertSucceeds(updateDoc(doc(db, 'users/tester'), {isSubscribed: true}));
});

// ─── Keeping the count ───────────────────────────────────────────────────────

test('only a write that moves a store between users needs a recount', () => {
  assert.deepEqual(userIdsToRecount(undefined, {userId: 'a'}), ['a']);
  assert.deepEqual(userIdsToRecount({userId: 'a'}, undefined), ['a']);
  assert.deepEqual(userIdsToRecount({userId: 'a'}, {userId: 'b'}), ['a', 'b']);
  assert.deepEqual(
    userIdsToRecount({userId: 'a', sortOrder: 1}, {userId: 'a', sortOrder: 2}),
    [],
  );
  assert.deepEqual(userIdsToRecount(undefined, {storeName: 'no user'}), []);
});

test('a recount includes shared stores, and leaves nothing behind at zero', async () => {
  const stores = admin.collection('user_stores');
  const own = await stores.add(ownStore('Mine'));
  const shared = await stores.add(sharedStore());
  await stores.add(ownStore('Theirs', 'someone-else', 'else@allim.test'));

  assert.equal(await recountUserStores(admin, 'tester'), 2);
  const counter = admin.doc('user_store_counts/tester');
  assert.equal((await counter.get()).data().count, 2);

  await own.delete();
  await shared.delete();
  assert.equal(await recountUserStores(admin, 'tester'), 0);
  assert.equal((await counter.get()).exists, false);
});

test('the backfill writes every count and reports what could block a subscriber', async () => {
  const stores = admin.collection('user_stores');
  for (let i = 0; i < 6; i++) {
    await stores.add(ownStore(`Store ${i}`));
  }
  await stores.add(ownStore('One', 'light-user', 'light@allim.test'));
  await admin.doc('users/AuthUid123').set({
    userId: 'legacy',
    email: 'l@allim.test',
    adminSubscribed: true,
  });
  await admin.doc('users/tester').set({
    userId: 'tester',
    email: EMAIL,
    adminSubscribed: true,
  });

  const report = await backfillCounts(admin);
  assert.equal((await admin.doc('user_store_counts/tester').get()).data().count, 6);
  assert.equal((await admin.doc('user_store_counts/light-user').get()).data().count, 1);
  assert.equal(report.users, 2);
  assert.equal(report.stores, 7);
  assert.equal(report.usersAtOrOverFreeLimit, 1);
  assert.deepEqual(report.premiumDocsNotKeyedByUserId, ['AuthUid123']);
});
