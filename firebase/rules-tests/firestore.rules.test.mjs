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

test('everything else is closed', async () => {
  await assertFails(setDoc(doc(db(ALICE), 'confessions', 'x'), { text: 'hi' }));
});
