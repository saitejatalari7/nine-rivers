# Play Data Safety form - answer sheet

For Nine Rivers, `com.ninerivers.mahjong`, version 1.0.1.

Two columns of truth run through this document:

- **NOW** - the build being submitted. No ad SDK is bundled, the `AD_ID` permission is not in
  the manifest, and nothing reads an advertising identifier.
- **WITH ADS** - the state after the planned AdMob update.

Answers that change between the two are marked **CHANGES WITH ADS**. Nothing else on this form
needs revisiting for the ad update.

Play's definitions used throughout: *collected* means transmitted off the device;
*shared* means transferred to a third party; data that never leaves the phone is
neither, and processing done entirely on-device is not collection.

---

## Section 1: Data collection and security

### Does your app collect or share any of the required user data types?

- **NOW: No.**
  Justification: the save file stays in the app's private storage and no code uploads it. Play
  Billing purchase handling and Play Games sign-in are Google's own collection under Google's
  policy, not the app's, and Play excludes them from the developer's declaration.
- **WITH ADS: Yes.** **CHANGES WITH ADS**
  Justification: the AdMob SDK reads the advertising ID and sends it and ad-interaction data to
  Google. That is collection and sharing by an SDK the app bundles, so it must be declared.

> If you answer No now, Play skips the rest of the data-type questions. The answers below are
> written out anyway, because they are what the form will ask once the answer becomes Yes.

### Is all of the user data collected by your app encrypted in transit?

- **NOW: not asked** (no collection declared).
- **WITH ADS: Yes.**
  Justification: AdMob transmits over HTTPS. The app itself makes no network calls of its own.

### Do you provide a way for users to request that their data is deleted?

- **NOW: not asked.**
- **WITH ADS: No** (and explain in the URL/notes: there is no account and nothing stored
  developer-side to delete; the advertising ID is reset or deleted by the user in Android
  Settings).
  Justification: answering Yes would imply a deletion endpoint that does not exist.

### Privacy policy URL

The GitHub Pages URL of `release/privacy-policy.md`.
`<VERIFY: the exact published URL. It depends on the GitHub repository name and Pages settings,
which are not recorded anywhere in this repository.>`

---

## Section 2: Data types

### Location (approximate, precise)

- **No**, both, NOW and WITH ADS.
  Justification: no location permission is requested and no location API is called. AdMob may
  infer coarse location from IP at Google's end, which is Google's processing, not a data type
  the app collects.

### Personal info (name, email, user IDs, address, phone, race, political or religious beliefs, sexual orientation, other)

- **No** to every item, NOW and WITH ADS.
  Justification: there are no accounts, no registration and no name or email field anywhere in
  the game. Google Play Games sign-in uses an account the player already has; the app never
  receives or stores the identity.

### Financial info (payment info, purchase history, credit score, other)

- **No**, NOW and WITH ADS.
  Justification: purchases go through Google Play Billing. The app is told which product IDs
  the player owns and stores that locally; it never sees or transmits payment details. Play's
  guidance is that billing handled by Play is not declared here.

### Health and fitness

- **No.** Not touched in any way.

### Messages, photos and videos, audio files, music

- **No.** No such permission, no such API, no microphone or gallery access. The game's own
  sound is generated and bundled, never recorded.

### Files and docs

- **No.** The save file is in the app's private directory, not shared storage, and is not
  transmitted.

### Calendar, contacts

- **No.** No permission requested.

### App activity - app interactions

- **NOW: No.**
  Justification: stage progress, stars and scores are written to the local save file only.
  There is no analytics SDK.
- **WITH ADS: Yes; collected and shared; not required (advertising or marketing);**
  **CHANGES WITH ADS**
  Justification: AdMob reports ad impressions, clicks and similar interaction events to Google.

### App activity - in-app search history, installed apps, other user-generated content, other actions

- **No** to all, NOW and WITH ADS.
  Justification: there is no search, no query of installed packages, and no place for a player
  to author content.

### Web browsing history

- **No.** Never read.

### App info and performance - crash logs, diagnostics, other performance data

- **No**, NOW and WITH ADS.
  Justification: no crash reporter and no analytics SDK is bundled. Play's own
  Android-vitals collection is not a developer declaration.
  `<VERIFY: if a crash or diagnostics SDK is ever added alongside AdMob, this becomes Yes.>`

### Device or other IDs

- **NOW: No.**
  Justification: no advertising ID, no ANDROID_ID, no IMEI and no device fingerprint is read.
  `AD_ID` is absent from the manifest, which Play cross-checks against this answer.
- **WITH ADS: Yes; collected and shared; not required (advertising or marketing);**
  **CHANGES WITH ADS**
  Justification: the advertising ID is exactly what AdMob reads and sends to Google.

---

## Section 3: Related declarations elsewhere in the Console

These are not on the Data Safety form itself but are checked against it. Getting them out of
step is a common rejection.

| Declaration | NOW | WITH ADS |
|---|---|---|
| Store listing "Contains ads" | No | **Yes** - **CHANGES WITH ADS** |
| `AD_ID` permission in the manifest | Absent | Present - **CHANGES WITH ADS** |
| Advertising ID declaration in the app content section | "Does not use advertising ID" | "Uses advertising ID" - **CHANGES WITH ADS** |
| Target audience | 13 and over | unchanged |
| Designed for Families | Not enrolled | unchanged |
| In-app purchases | Yes | unchanged |
| Data deletion URL | Not provided | Not provided |
| Government app | No | unchanged |
| Financial features | None | unchanged |

Note on `AD_ID`: Play rejects an app that declares the advertising ID but omits the permission,
and it rejects one that ships the permission while declaring no ID collection. The permission
and the three declarations above must move in the same release as the SDK.

---

## Section 4: Things a reviewer may ask about

- **Google Play Games cloud save.** Optional, off until the player enables it in Settings. When
  on, it writes the player's progress to Google Play Games saved games under the player's own
  Google account. This is not declared as collection by the app: the data goes to Google under
  the player's account, through Google's own service, and the developer has no access to it.
  It is described in the privacy policy regardless, because a player deserves to know their
  progress leaves the phone.
  `<VERIFY: if a reviewer takes the opposite view and treats the uploaded profile as the app
  collecting "app activity", the answer becomes Yes, collected, not shared, optional rather
  than required, purpose app functionality. Nothing in Play's published guidance settles which
  reading applies to Play Games Saved Games, so be ready to switch to that answer if asked.>`
- **Network permission.** The app itself never opens a socket. INTERNET arrives through the
  Play Billing and Play Games libraries.
- **Encryption of the local save.** The save file is encrypted on disk. This is anti-tamper,
  not a privacy control, and should not be described to Play as protecting personal data,
  because there is no personal data in it.

---

## Checklist for the ad release

Do all of these in the same release that adds the AdMob SDK:

1. Update the Data Safety form: Device or other IDs -> Yes, and App interactions -> Yes, both
   collected and shared, purpose advertising or marketing.
2. Answer Yes to "does your app collect or share user data", and Yes to encrypted in transit.
3. Switch the store listing to "Contains ads".
4. Declare use of the advertising ID in the app content section.
5. Confirm `AD_ID` is in the merged manifest.
6. Publish the updated privacy policy with the advertising section rewritten from planned to
   in use, dated, before the release goes live.
7. Configure the AdMob consent flow. Indian users are outside the GDPR, but the app will have
   users elsewhere and Google requires a consent message for EEA and UK traffic.
