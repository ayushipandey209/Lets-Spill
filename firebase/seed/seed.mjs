// Loads the sample confessions from assets/mock/confessions.json into
// Cloud Firestore so a fresh install doesn't open on an empty feed.
//
//   cd firebase/seed
//   npm install
//   gcloud auth application-default login     (or set GOOGLE_APPLICATION_CREDENTIALS
//                                               to a service account key file)
//   npm run seed -- --project lets-spill
//
// Options:
//   --project <id>   Firebase project id (default: from .firebaserc / env)
//   --dry-run        Print what would be written
//   --delete         Remove the sample posts again
//
// The Admin SDK bypasses security rules, so run this only from a trusted
// machine. Sample posts start with zero likes, views and reactions so every
// counter matches the activity documents behind it. Dates are shifted so the
// newest sample is about an hour old and the gaps between posts are kept.
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, Timestamp, FieldValue } from 'firebase-admin/firestore';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '..', '..');
const args = process.argv.slice(2);
const flag = (name) => args.includes(name);
const option = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};

function projectId() {
  const fromArg = option('--project');
  if (fromArg) return fromArg;
  if (process.env.GCLOUD_PROJECT) return process.env.GCLOUD_PROJECT;
  try {
    const rc = JSON.parse(readFileSync(resolve(root, '.firebaserc'), 'utf8'));
    return rc.projects?.default;
  } catch {
    return undefined;
  }
}

// Keep in sync with lib/features/confessions/domain/ranking.dart.
const EPOCH_SECONDS = 1704067200;
const DECAY_SECONDS = 45000;
const MAX_TOKENS = 60;

function hotScore(createdAt, likes, reactions) {
  const s = Math.max(0, likes) + Math.max(0, reactions);
  const order = Math.log10(Math.max(s, 1));
  const seconds = createdAt.getTime() / 1000 - EPOCH_SECONDS;
  return Math.round((order + seconds / DECAY_SECONDS) * 1e7) / 1e7;
}

function searchTokens(text, categoryId) {
  const words = new Set();
  for (const raw of text.toLowerCase().split(/[^a-z0-9']+/)) {
    const w = raw.replaceAll("'", '');
    if (w.length >= 2) words.add(w);
  }
  if (categoryId) words.add(categoryId.toLowerCase());
  return [...words].sort((a, b) => b.length - a.length).slice(0, MAX_TOKENS);
}

const SEED_AUTHOR = 'lets-spill-team';

async function main() {
  const project = projectId();
  if (!project) {
    console.error('No project id. Pass --project <id>.');
    process.exit(1);
  }
  const { confessions } = JSON.parse(
    readFileSync(resolve(root, 'assets/mock/confessions.json'), 'utf8'),
  );

  initializeApp({ credential: applicationDefault(), projectId: project });
  const db = getFirestore();

  if (flag('--delete')) {
    const batch = db.batch();
    for (const c of confessions) {
      batch.delete(db.collection('confessions').doc(c.id));
      batch.delete(db.collection('confessionAuthors').doc(c.id));
    }
    if (!flag('--dry-run')) await batch.commit();
    console.log(`Removed ${confessions.length} sample confessions from ${project}.`);
    return;
  }

  const times = confessions.map((c) => new Date(c.createdAt).getTime());
  const shift = Date.now() - 60 * 60 * 1000 - Math.max(...times);

  const batch = db.batch();
  for (const c of confessions) {
    const createdAt = new Date(new Date(c.createdAt).getTime() + shift);
    const doc = {
      text: c.text,
      categoryId: c.categoryId,
      mature: c.mature === true,
      status: 'published',
      authorDisplayName: 'Anonymous',
      createdAt: Timestamp.fromDate(createdAt),
      likeCount: 0,
      viewCount: 0,
      saveCount: 0,
      reactionCounts: { same: 0, hugs: 0, wow: 0 },
      reactionTotal: 0,
      hotScore: hotScore(createdAt, 0, 0),
      searchTokens: searchTokens(c.text, c.categoryId),
    };
    if (flag('--dry-run')) {
      console.log(c.id, doc.categoryId, doc.createdAt.toDate().toISOString());
      continue;
    }
    batch.set(db.collection('confessions').doc(c.id), doc);
    batch.set(db.collection('confessionAuthors').doc(c.id), {
      uid: SEED_AUTHOR,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  if (!flag('--dry-run')) await batch.commit();
  console.log(`Seeded ${confessions.length} sample confessions into ${project}.`);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
