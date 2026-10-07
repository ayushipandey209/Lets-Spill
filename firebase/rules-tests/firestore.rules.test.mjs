// Firestore rules tests. Run from this folder:
//   npm install && npm test
// Requires firebase-tools (npm i -g firebase-tools) and Java 11+ for the emulator.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, getDoc, setDoc, updateDoc, deleteDoc, writeBatch, serverTimestamp,
  runTransaction, collection, query, where, getDocs,
} from 'firebase/firestore';

let env;
const ALICE = 'alice';
const BOB = 'bob';

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-lets-spill',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(async () => env.cleanup());
beforeEach(async () => env.clearFirestore());

const db = (uid) => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();

const profile = (username, extra = {}) => ({
  username,
  usernameLower: username.toLowerCase(),
  ageRange: 'young',
  preferredCategoryIds: ['life', 'school'],
  onboardingComplete: true,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

async function onboard(uid, username = 'QuietComet27', extra = {}) {
  const d = db(uid);
  const b = writeBatch(d);
  b.set(doc(d, 'users', uid), profile(username, extra));
  b.set(doc(d, 'usernames', username.toLowerCase()), { uid, createdAt: serverTimestamp() });
  return b.commit();
}

test('onboarding writes profile + username claim together', async () => {
  await assertSucceeds(onboard(ALICE));
});

test('profile without a claim is rejected', async () => {
  await assertFails(setDoc(doc(db(ALICE), 'users', ALICE), profile('QuietComet27')));
});

test('cannot take a username claimed by someone else', async () => {
  await onboard(ALICE, 'QuietComet27');
  await assertFails(onboard(BOB, 'QuietComet27'));
});

test('typed / non-generated usernames and bad values are rejected', async () => {
  await assertFails(onboard(ALICE, 'John Smith'));
  await assertFails(onboard(ALICE, 'abc'));
  await assertFails(onboard(ALICE, 'QuietComet27', { ageRange: '12' }));
  await assertFails(onboard(ALICE, 'QuietComet27', { preferredCategoryIds: [] }));
  await assertFails(onboard(ALICE, 'QuietComet27', { email: 'a@b.com' }));
});

test('profiles are private', async () => {
  await onboard(ALICE);
  await assertSucceeds(getDoc(doc(db(ALICE), 'users', ALICE)));
  await assertFails(getDoc(doc(db(BOB), 'users', ALICE)));
  await assertFails(getDoc(doc(db(null), 'users', ALICE)));
});

test('only preferences can change after onboarding', async () => {
  await onboard(ALICE);
  const d = db(ALICE);
  await assertSucceeds(updateDoc(doc(d, 'users', ALICE), { preferredCategoryIds: ['family'], updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(d, 'users', ALICE), { username: 'WildFox11', updatedAt: serverTimestamp() }));
  await assertFails(updateDoc(doc(d, 'users', ALICE), { ageRange: 'senior', updatedAt: serverTimestamp() }));
});

test('availability check is readable by signed-in users only', async () => {
  await onboard(ALICE);
  await assertSucceeds(getDoc(doc(db(BOB), 'usernames', 'quietcomet27')));
  await assertFails(getDoc(doc(db(null), 'usernames', 'quietcomet27')));
});

test('account deletion removes profile and releases the name', async () => {
  await onboard(ALICE);
  const d = db(ALICE);
  await assertFails(deleteDoc(doc(db(BOB), 'usernames', 'quietcomet27')));
  const b = writeBatch(d);
  b.delete(doc(d, 'users', ALICE));
  b.delete(doc(d, 'usernames', 'quietcomet27'));
  await assertSucceeds(b.commit());
});

test('reports: one per user, reporterUid must be the caller', async () => {
  const d = db(BOB);
  const report = {
    confessionId: 'conf-001', reporterUid: BOB, reason: 'harassment', details: '',
    createdAt: serverTimestamp(), reviewStatus: 'open',
  };
  await assertSucceeds(setDoc(doc(d, 'reports', `conf-001_${BOB}`), report));
  await assertFails(setDoc(doc(d, 'reports', `conf-001_${BOB}`), report));
  await assertFails(setDoc(doc(db(ALICE), 'reports', `conf-001_${ALICE}`), { ...report, reporterUid: BOB }));
  await assertSucceeds(getDoc(doc(d, 'reports', `conf-001_${BOB}`)));
  await assertFails(getDoc(doc(db(ALICE), 'reports', `conf-001_${BOB}`)));
});

test('settings can be synced to the profile', async () => {
  await onboard(ALICE);
  await assertSucceeds(updateDoc(doc(db(ALICE), 'users', ALICE), {
    settings: { theme: 'dark', textSize: 'small' }, updatedAt: serverTimestamp(),
  }));
});

test('everything else is closed', async () => {
  await assertFails(setDoc(doc(db(ALICE), 'somethingElse', 'x'), { text: 'hi' }));
});

// ---------------------------------------------------------------- confessions

const EPOCH = 1704067200;
const hotNow = () => (Date.now() / 1000 - EPOCH) / 45000;

const newConfession = (extra = {}) => ({
  text: 'I still keep the train ticket from our first date.',
  categoryId: 'relationships',
  mature: false,
  status: 'published',
  authorDisplayName: 'Anonymous',
  createdAt: serverTimestamp(),
  likeCount: 0,
  viewCount: 0,
  saveCount: 0,
  reactionCounts: { same: 0, hugs: 0, wow: 0, oof: 0 },
  reactionTotal: 0,
  hotScore: hotNow(),
  searchTokens: ['ticket', 'train'],
  ...extra,
});

async function post(uid, id = 'c1', extra = {}) {
  const d = db(uid);
  const b = writeBatch(d);
  b.set(doc(d, 'confessions', id), newConfession(extra));
  b.set(doc(d, 'confessionAuthors', id), { uid, createdAt: serverTimestamp() });
  b.set(doc(d, 'users', uid, 'posts', id), { confessionId: id, createdAt: serverTimestamp() });
  return b.commit();
}

async function like(uid, id = 'c1', liked = true) {
  const d = db(uid);
  return runTransaction(d, async (tx) => {
    const ref = doc(d, 'confessions', id);
    const snap = await tx.get(ref);
    const n = snap.data().likeCount + (liked ? 1 : -1);
    tx.update(ref, { likeCount: n, hotScore: snap.data().hotScore + (n >= 2 && liked ? Math.log10(n) - Math.log10(n - 1) : 0) });
    const mine = doc(d, 'users', uid, 'likes', id);
    const theirs = doc(d, 'confessions', id, 'likes', uid);
    if (liked) {
      tx.set(theirs, { uid, createdAt: serverTimestamp() });
      tx.set(mine, { confessionId: id, createdAt: serverTimestamp() });
    } else {
      tx.delete(theirs);
      tx.delete(mine);
    }
  });
}

test('posting writes the confession, private author link and post mirror together', async () => {
  await onboard(ALICE);
  await assertSucceeds(post(ALICE));
  // Author mapping is private.
  await assertSucceeds(getDoc(doc(db(ALICE), 'confessionAuthors', 'c1')));
  await assertFails(getDoc(doc(db(BOB), 'confessionAuthors', 'c1')));
});

test('posting rejects fake counters, wrong names and missing author link', async () => {
  await onboard(ALICE);
  await assertFails(post(ALICE, 'c2', { likeCount: 500 }));
  await assertFails(post(ALICE, 'c3', { authorDisplayName: '@SomeoneElse12' }));
  await assertFails(setDoc(doc(db(ALICE), 'confessions', 'c4'), newConfession()));
  await assertSucceeds(post(ALICE, 'c5', { authorDisplayName: '@QuietComet27' }));
});

test('teens cannot post or read 18+', async () => {
  await onboard(ALICE);
  await onboard(BOB, 'ShyFoxes12', { ageRange: 'teen' });
  await assertFails(post(BOB, 'c1', { mature: true }));
  await assertSucceeds(post(ALICE, 'm1', { mature: true }));
  await assertFails(getDoc(doc(db(BOB), 'confessions', 'm1')));
  await assertSucceeds(getDocs(query(collection(db(BOB), 'confessions'),
    where('status', '==', 'published'), where('mature', '==', false))));
  await assertFails(getDocs(query(collection(db(BOB), 'confessions'),
    where('status', '==', 'published'))));
});

test('likes move the counter by exactly one, once per person', async () => {
  await onboard(ALICE);
  await onboard(BOB, 'ShyFoxes12');
  await post(ALICE);
  await assertSucceeds(like(BOB));
  await assertFails(like(BOB)); // Already liked: +1 again is rejected.
  await assertSucceeds(like(BOB, 'c1', false));
  // A counter bump without the like document is rejected.
  await assertFails(updateDoc(doc(db(BOB), 'confessions', 'c1'), { likeCount: 10 }));
});

test('views are counted once per reader', async () => {
  await onboard(ALICE);
  await post(ALICE);
  const view = (uid) => runTransaction(db(uid), async (tx) => {
    const ref = doc(db(uid), 'confessions', 'c1');
    const snap = await tx.get(ref);
    tx.update(ref, { viewCount: snap.data().viewCount + 1 });
    tx.set(doc(db(uid), 'confessions', 'c1', 'views', uid), { uid, createdAt: serverTimestamp() });
  });
  await onboard(BOB, 'ShyFoxes12');
  await assertSucceeds(view(BOB));
  await assertFails(view(BOB));
});

test('only the author can delete a confession', async () => {
  await onboard(ALICE);
  await onboard(BOB, 'ShyFoxes12');
  await post(ALICE);
  await assertFails(deleteDoc(doc(db(BOB), 'confessions', 'c1')));
  const d = db(ALICE);
  const b = writeBatch(d);
  b.delete(doc(d, 'confessions', 'c1'));
  b.delete(doc(d, 'confessionAuthors', 'c1'));
  b.delete(doc(d, 'users', ALICE, 'posts', 'c1'));
  await assertSucceeds(b.commit());
});
