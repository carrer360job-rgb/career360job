# Career360 advertising deployment

The database migration is applied with the master switch and interstitials disabled. Deploy the backend and admin-web before enabling Settings > Advertising. Flutter ads require a new Android build; hot reload cannot add the native SDK.

## Registered AdMob Configuration

- **Android App ID:** `ca-app-pub-3678252568683447~5307483098`
- **Banner Ad Unit ID:** `ca-app-pub-3678252568683447/4579182791`
- **Native Ad Unit ID:** `ca-app-pub-3678252568683447/7176144717`
- **Interstitial Ad Unit ID:** `ca-app-pub-3678252568683447/6237421381`

The project has been pre-configured with these IDs as release defaults in `gradle.properties` and `advertising.dart`. In debug mode, Google sample test IDs continue to be used automatically.

## Configuration

1. In the client-owned AdMob account register Android package `com.career360.candidate`. Create banner, native and interstitial ad units. Configure Privacy & messaging and link the store listing when available. Complete account verification and payments in AdMob. Publish and verify app-ads.txt using the developer website shown in the store listing.
2. Supply Gradle property `ADMOB_APP_ID` (for example in the local Gradle user properties or CI Gradle configuration). It defaults to Google's sample app ID for development. Never ship a live ad unit with the sample app ID.
3. Build with `--dart-define=ADMOB_BANNER_ID=... --dart-define=ADMOB_NATIVE_ID=... --dart-define=ADMOB_INTERSTITIAL_ID=...`. Missing release IDs disable the respective format. Debug/profile builds use Google sample ad units. IDs are public identifiers, not API secrets.
4. Review the privacy policy and Play Console Ads, Data safety and audience declarations for the installed SDK. Configure production signing: the existing Android release configuration still uses the debug signing key.
5. Test on physical Android devices with test ads; inspect native attribution and AdChoices, small screen layout, consent choices, offline/no-fill, navigation, role changes and successful/failed applications. No live ad clicks during testing.
6. Enable the master and desired formats in admin Settings. Interstitials should remain off until physical device verification is complete.

## Operating rules

Only active adult candidate accounts are eligible. Missing age/configuration/consent fails closed. Home banner and native search cards are the only inline placements. At most three native ads are loaded in a list, with spacing controlled by admin. No application or employer placement exists. Interstitials require distinct job views, a preloaded ad, returning to search, minimum ten minutes between ads, and at most two per device/day. Completing an application skips the interstitial. Late transitions skip the ad instead of interrupting content. Device counters are local frequency controls, not billing/security counters.

Settings refresh at most once per minute while an eligible screen is open, and on resume. Turning ads off therefore takes up to approximately 60 seconds on already-open screens. Database failures disable ads. Audit records are written in the same transaction as settings updates. Revenue, fill rate and policy alerts are monitored in AdMob; the admin page does not invent revenue totals.

## Release validation

Run admin-web build, backend syntax checks, Flutter analysis and an Android build. Check ad-settings RLS denies direct client reads/writes and database constraints reject invalid frequency settings. Check saved admin settings survive refresh. Use the master switch to stop delivery without rebuilding the app. SDK/policy changes still need periodic maintenance; remote controls cannot replace future platform-required updates.
