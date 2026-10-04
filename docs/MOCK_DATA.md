# Confession content (bundled JSON)

Accounts and profiles are real (Firebase). **Confession content** comes from
`assets/mock/` for now. All stories are fictional.

| File | Contents |
|---|---|
| `categories.json` | The six categories (`relationships`, `school`, `workplace`, `friendship`, `family`, `life`), each with a description (shown in onboarding) and an order. |
| `confessions.json` | 28 confessions with these fields: `id` (`conf-001`…), `categoryId`, `text`, `createdAt` (ISO-8601 UTC), `likeCount`, `viewCount`, `reactionCounts` (`same`/`hugs`/`wow`/`oof`), `mature`, `authorDisplayName` ("Anonymous" or an `@handle`) and `status`. They contain no account identifiers. |

`"mature": true` marks adult themes such as affairs. These confessions are
hidden from readers who chose the 13–17 age range.

## How it loads

`LocalContentStore` (`lib/core/data/local/local_content_store.dart`):

1. Looks for saved state under `lets_spill.content.v2` in `shared_preferences`.
2. On first run, seeds from `confessions.json`.
3. Keeps each user's likes, reactions, saves, views and own posts under their
   **Firebase uid**. Two accounts on the same device never see each other's
   activity.

## Editing the seed

Edit the JSON and keep the `id`s unique and the `categoryId`s valid. Saved
state takes precedence over the seed, so clear the app's storage (or
reinstall) to see your edits. `flutter test test/data/local_content_test.dart`
validates the file. Update `seedConfessionCount` and `seedMatureCount` in
`test/helpers.dart` if you change the counts.
