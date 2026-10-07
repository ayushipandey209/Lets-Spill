# Sample confessions

`assets/mock/` holds the app's categories and 28 fictional sample
confessions. No real people, schools or companies.

| File | Used for |
|---|---|
| `categories.json` | The six categories (`relationships`, `school`, `workplace`, `friendship`, `family`, `life`) with descriptions and order. Shipped with the app; the rules hold the same list. |
| `confessions.json` | Sample posts. Loaded into Firestore once with the seed script, and used by the tests' in-memory repository. |

`"mature": true` marks adult themes such as affairs. These are hidden from
readers aged 13 to 17.

## Loading them into Firestore

```sh
cd firebase/seed && npm install
npm run seed -- --project <your-project-id>          # add
npm run seed -- --project <your-project-id> --delete  # remove
```

The seed shifts the dates so the newest post is about an hour old and starts
every counter at zero, so likes and views always match the real activity
documents.

## Editing

Keep the `id`s unique and the `categoryId`s valid.
`flutter test test/data/local_content_test.dart` validates the file. Update
`seedConfessionCount` and `seedMatureCount` in `test/helpers.dart` if you
change the counts.
