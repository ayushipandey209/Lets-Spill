# Analytics (Google Analytics for Firebase)

Event names are defined in `lib/core/analytics/analytics.dart`
(`AnalyticsEvents`). Nothing here includes confession text, search words,
names or emails. No advertising ID is collected and ad personalisation is
off (some readers are 13 to 17). Readers can turn analytics off in
Settings, Privacy, Usage analytics.

## Screens

Logged automatically for every route (`confession`, `create`, `category`,
`search`, `settings`, `guidelines`, `info`, `delete-account`) and for the
signed-in tabs (`home`, `explore`, `profile`) and gate screens (`intro`,
`onboarding`).

## Events

| Event | When | Parameters |
|---|---|---|
| `login` | Google sign in finished | method |
| `sign_up` | onboarding completed | age_range, categories |
| `onboarding_step` | each onboarding step shown | step |
| `sign_out` | signed out from Settings | |
| `account_deleted` | account deleted | |
| `feed_tab_select` | For you / Hot / New / Top | tab, surface |
| `feed_category_select` | category chip on Home | category |
| `feed_refresh` | pull to refresh | tab |
| `feed_load_more` | next page loaded | tab, loaded |
| `cotd_open` | Confession of the Day opened | confession_id |
| `confession_open` | any confession opened | confession_id, category, source |
| `confession_view_qualified` | read for 15 s (once per reader) | confession_id, category |
| `category_open` | category page opened | category |
| `search` | search finished | words, results |
| `confession_like` / `confession_unlike` | like toggled | confession_id, category, surface |
| `confession_react` | reaction set or cleared | confession_id, reaction, category |
| `confession_save` / `confession_unsave` | bookmark toggled | confession_id, surface |
| `share` | share sheet opened | content_type, item_id, source |
| `confession_report` | report submitted | confession_id |
| `confession_create_start` | composer opened | |
| `confession_post` | confession posted | category, identity, mature, length_bucket |
| `confession_discard` | draft discarded | |
| `confession_delete` | own post deleted | confession_id |
| `setting_changed` | any setting changed | setting, value |
| `reading_prefs_saved` | interests saved | count |

## User properties

`age_range`, `theme`, `text_size`, `feed_layout`, `pref_categories`.
Register them as custom dimensions in the Firebase console (Analytics,
Custom definitions) to use them in reports.

## Useful reports

- Activation: `sign_up` / `login`, and `onboarding_step` drop-off.
- Engagement: `confession_view_qualified` per user, likes and reactions per
  view, `confession_post` per active user.
- Retention: Firebase's retention cohorts on `sign_up`.
- Content: `confession_open` by `category` and `source`.

Use DebugView while developing:
`adb shell setprop debug.firebase.analytics.app com.letsspill.let_s_spill`
(Android) or the `-FIRDebugEnabled` launch argument (iOS).
