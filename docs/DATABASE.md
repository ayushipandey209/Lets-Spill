# Database (Cloud Firestore)

Every user action is a document, mapped to the user's Firebase uid. Field
names live in `lib/core/data/firebase/firestore_paths.dart`; the rules in
`firebase/firestore.rules` enforce everything below.

## Collections

```
users/{uid}                                  PRIVATE, owner only
  username               "QuietComet27"      generated, chosen not typed
  usernameLower          "quietcomet27"
  ageRange               teen | young | adult | mid | senior
  preferredCategoryIds   ["life", "family"]
  onboardingComplete     true
  settings               { theme, textSize, feedLayout, defaultFeed,
                           showMature, blurMature, postIdentity,
                           mutedCategoryIds, showConfessionOfDay, haptics,
                           reduceMotion, analyticsEnabled }
  createdAt, updatedAt

  posts/{confessionId}       { confessionId, createdAt }   posts I wrote
  likes/{confessionId}       { confessionId, createdAt }   posts I liked
  reactions/{confessionId}   { confessionId, reaction, createdAt }
  saves/{confessionId}       { confessionId, createdAt }   my bookmarks

usernames/{usernameLower}                    { uid, createdAt }

confessions/{confessionId}                   readable by signed-in users
  text                   up to 2,000 characters
  categoryId             relationships | school | workplace | friendship |
                         family | life
  mature                 true for 18+ (never served to readers under 18)
  status                 published | hidden | removed
  authorDisplayName      "Anonymous" or "@QuietComet27"
  createdAt              server time
  likeCount              = number of likes/{uid} documents
  reactionCounts         { same, hugs, wow, oof }
  reactionTotal          = number of reactions/{uid} documents
  viewCount              = number of views/{uid} documents
  saveCount              = number of users/*/saves/{confessionId}
  hotScore               ranking for the Hot tab (see below)
  searchTokens           lower-case words used by search

  likes/{uid}            { uid, createdAt }            who liked it
  reactions/{uid}        { uid, reaction, createdAt }  who reacted, and how
  views/{uid}            { uid, createdAt }            who read it for 15 s

confessionAuthors/{confessionId}             { uid, createdAt }
                         private author mapping: only the author can read it
                         (moderators use the Admin SDK)

reports/{confessionId}_{uid}
  confessionId, reporterUid, reason, details, createdAt, reviewStatus
```

## How one like is written

In a single transaction:

1. read `confessions/{id}` and `confessions/{id}/likes/{uid}`
2. `likeCount + 1` and the new `hotScore` on the confession
3. create `confessions/{id}/likes/{uid}`
4. create `users/{uid}/likes/{id}`

The rules accept the counter change only if the like document is created in
the same write and did not exist before. Unliking is the reverse. Reactions,
reads and saves follow the same pattern.

## Ranking

`hotScore = log10(max(likes + reactions, 1)) + (createdAt - 2024-01-01) / 45000 s`

Newer posts start higher; ten times the engagement is worth 12.5 hours. The
value doesn't change as time passes, so Firestore can sort by it directly.
The rules allow each like or reaction to move it by at most 0.41 (log10(2)
plus the 0.1 clock tolerance allowed when the post was created).

## Indexes

`firebase/firestore.indexes.json` holds the composite indexes for every feed
query (status, optional category and 18+ filter, sorted by new, hot or top)
and for search. Deploy them with `firebase deploy --only firestore:indexes`.

## Account deletion

`FirestoreConfessionRepository.clearUserData()` removes the user's likes,
reactions, saves and reads (each with its counter decremented in a
transaction) and their posts. Then the profile and username claim are
deleted, and finally the Firebase Auth account. Reports are kept for safety
records and contain no name or email.

## Moderation

Hide a post by setting `status` to `hidden` in the console or with the Admin
SDK. It disappears from every feed; its author can still see it in their
own Posts list. Find the author of a reported post in
`confessionAuthors/{confessionId}`.
