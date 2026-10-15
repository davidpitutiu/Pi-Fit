# Pi Fit: Firebase and the coach

Pi Fit v0.3 includes public Firebase client configuration for the existing
`pi-fit-663f2` project. Normal startup needs no configuration edits:

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Use `flutter` directly in Windows PowerShell. The cloud Linux environment also
provides `scripts/flutterw`. Local workouts, profiles and the program builder
remain available when Firebase or the online coach cannot connect.

## Included configuration and verified status

The repository contains:

- [`../lib/firebase_options.dart`](../lib/firebase_options.dart): default options
  selected for Android, iOS or Web.
- [`../android/app/google-services.json`](../android/app/google-services.json)
  and [`../ios/Runner/GoogleService-Info.plist`](../ios/Runner/GoogleService-Info.plist):
  the supplied public native client files, for `com.pifit.app`.
- [`web-config.json`](web-config.json): minimal public Web options using the
  supplied app ID `1:942783822335:web:52e8ccf86e545c2ed28fca`, project metadata and
  the same project's Android public API key.

The Web options were assembled from these supplied identifiers; a complete Web
`firebaseConfig` export has not been provided. Public client keys identify a
project and may have different restrictions per platform. Replace the Web options
with the actual public Web export if its key or restrictions differ.

Checks performed on 15 October 2026:

| Component | Observed result | What remains |
| --- | --- | --- |
| Firebase Auth REST | Temporary account creation, email/password login, account lookup and deletion all returned HTTP 200. The test account was deleted and no emails were sent. | Verify the installed app's complete login, verification and password-reset flows. |
| Firebase Web SDK in this cloud environment | Fetching the SDK from `www.gstatic.com` was blocked with HTTP 403. | Apply the required environment network settings and retry browser startup. This does not establish a client-key failure. |
| Cloud Firestore | Authenticated access to the temporary account's own backup returned HTTP 403 `PERMISSION_DENIED`: “Missing or insufficient permissions.” | Inspect the project's published rules and database settings, publish the owner-only rules below, and repeat backup/restore checks. The exact administrative cause was not confirmed. |
| Online coach | No usable provider secret or deployed `AI_COACH_URL` is available in this environment. | Configure and deploy the backend, then verify it with a real registered account. |

Firebase initialization has an internal 10-second timeout. If the Web SDK cannot
load, startup continues in local mode. A late SDK completion does not silently
activate accounts after the app selected local mode. No administrative Firebase
settings were changed during these checks. The environment's ADC binding is
present but lacks the fields required for usable Google credentials; configure
administrative CLI authentication separately when deploying.

### Regenerating public client options

The defaults are already included. Run the helper only when replacing client
configuration or regenerating its generated files:

```sh
# Regenerate from the public native and Web files already in the repository:
python scripts/configure_firebase.py

# Replace native client files with new downloads for the same project:
python scripts/configure_firebase.py --android "path/google-services.json" --ios "path/GoogleService-Info.plist"

# Replace the minimal Web options with a public Web config saved as valid JSON:
python scripts/configure_firebase.py --web "path/firebase-web.json"
```

Run these commands from the repository root. On Windows, if the Python install
manager reports that no runtime is installed, run `py install default` first;
then use `py scripts/configure_firebase.py` with the same arguments.

The helper validates the project, sender and native bundle identifiers before
writing files. It rejects server credentials and regenerates the default Dart
options, native files, public Web config and optional
`firebase/client-config.local.json`. The local defines file is ignored by Git.

Complete Dart defines can override the bundled Firebase options for a build:

```sh
flutter run --dart-define-from-file=firebase/client-config.local.json
```

Explicit overrides must provide the public API key, project ID, sender ID and
app ID for the selected platform. Partial overrides and app IDs for the wrong
platform or sender are rejected. Platform-specific keys/app IDs take precedence
over `FIREBASE_API_KEY` and `FIREBASE_APP_ID`. The iOS bundle ID is
`com.pifit.app`. `FIREBASE_AUTH_DOMAIN` and `FIREBASE_STORAGE_BUCKET` are optional.
Keep provider secrets and service-account files out of every client config.

## Test data for progress and exports

A tested administrative helper can append 36 labelled synthetic workouts to an
existing account backup, preserving its current data. It requires authenticated
Google administrative access; public SDK config alone is insufficient. See
[the test-history import instructions](../docs/demo-data.md).

## Accounts and cloud backups

The app supports email/password signup and login, password reset, email
verification/resending, logout and account deletion with reauthentication.
Passwords are handled by Firebase Auth and are not stored in local preferences
or Firestore. Email/password authentication was verified through the REST smoke
test above. For Web, check **Authentication → Settings → Authorized domains** for
the frontend hostname when required.

Local data is separated by account. Signing in leaves the guest journal intact;
importing it is an explicit action. Account transitions cover the previous
profile until the new account's local data is ready. Delayed authentication and
coach results are checked against the account that started the operation.

Cloud backup is an explicit JSON snapshot at
`users/{uid}/backups/current`, with a server timestamp and schema version.
Firestore documents are limited to 1 MiB. Restore fetches the server version and
reports an error if it cannot reach the server. This is snapshot backup/restore,
not continuous multi-device synchronization.

Review and publish [`firestore.rules`](firestore.rules) for the selected project.
They limit profile/backup access to the authenticated owner and keep internal
coach rate-limit documents inaccessible to clients. Do not replace them with
public read/write access. A rules deployment from an authenticated owner shell is:

```sh
cd firebase
firebase deploy --only firestore:rules --project pi-fit-663f2
```

The current Firestore permission failure still needs resolution before cloud
backup/restore or full account deletion can be considered working. Deletion
reauthenticates first, removes the account's cloud backup/profile, then removes
the Auth account. If cloud cleanup fails, the account remains available for a
retry. Local device data is preserved.

## Program proposals and local coaching

Pi Coach can prepare new programs, edit a selected custom routine, add or remove
an exercise, replace an exercise and propose an optional bulk schedule. For
example:

- “Create a 3-day workout program for my equipment.”
- “Add an exercise to this routine.”
- “Replace push up with dead bug in my routine.”
- “Modify this routine to fit 30 minutes.”
- “Create a 3-day program and schedule bulk for 4 weeks at 18:30.”

The conversation returns a reviewable proposal. **Review & apply → Apply program**
performs the client-side save. Review the routine, exercises, loads and any dates
before applying. A bulk schedule targets the selected routine; the other routines
can be scheduled from Calendar.

Proposals contain typed routine and schedule data. Both the server and client
validate exercise IDs, numeric limits and schema fields. Editing requires an
existing custom routine ID and its exact reviewed revision. The client binds the
proposal to the captured account and planning revision, checks them again on
apply, and persists applied proposal IDs to prevent duplicate application. Routine
and calendar changes are saved together. Built-in templates and recorded workout
history are preserved. Arbitrary commands embedded in AI text are not executed.

The local builder is deterministic software, not an offline language model. It
uses the profile's availability, equipment, experience, goal and supported literal
movement exclusions. With no equipment selected, it starts conservatively with
bodyweight movements. It marks unknown starting loads as zero for the user to
choose and record. It cannot medically evaluate free-text limitations.

General questions, nutrition questions and pain-related questions remain advice
without program actions. Local suggestions compare actual completed sets when
available and state when there is insufficient history. They do not invent
records, calorie requirements, heart rate or a safe personal lifting weight.

Effort ratings are optional, user-reported **RPE from 1–10**. They describe a
particular completed set, separately from an exercise's library difficulty. The
coach uses reported effort and explicit active-exercise focus; it does not infer
missing RPE or the latest edit from list order. Live on-device guidance updates
from logged sets. Online feedback additionally requires an enabled backend,
an authenticated account and the user's sharing preference.

## Deploying the online coach

The TypeScript backend uses second-generation Firebase Functions, Node.js 22 and
the OpenAI Responses API. Deployment requires authenticated Firebase CLI access,
an appropriate Firebase billing plan and a valid provider key. Configure project
budgets and cost alerts before enabling a paid service.

For local preparation and validation in the cloud Linux environment:

```sh
bash scripts/setup_node.sh
export PATH="/workspace/node22/bin:$PATH"
npm --prefix firebase/functions ci --cache /workspace/.npm-cache --no-audit --no-fund
npm --prefix firebase/functions test
```

The setup helper installs the pinned official Node distribution outside the
checkout after verifying its SHA-256 checksum. On another machine, use Node 22
as pinned in `functions/.nvmrc` and run `npm ci`.

From the repository root, using a Firebase CLI session authenticated as the project owner:

```sh
cd firebase
firebase functions:secrets:set OPENAI_API_KEY --project pi-fit-663f2
firebase deploy --only "firestore:rules,functions:pi-fit-coach" --project pi-fit-663f2
```

The CLI prompts securely for the key and stores it in Secret Manager. Never put
the provider key in chat, source code, Dart defines or the shipped app. These
commands publish external services; they were not executed during local setup.

| Server parameter | Default | Purpose |
| --- | --- | --- |
| `AI_MODEL` | `gpt-4.1` | Server-selected model supporting structured Responses API output. |
| `ALLOWED_ORIGINS` | empty | Exact allowed Web origins, comma-separated, without trailing slashes. |
| `REQUIRE_APP_CHECK` | `false` | Requires and verifies a Firebase App Check token when enabled. |

The function runs in `europe-west1`. Copy its actual deployed HTTPS URL into the
`AI_COACH_URL` Dart define and rebuild; bundled Firebase defaults remain usable:

```sh
flutter run -d chrome --web-port=7357 --dart-define=AI_COACH_URL=https://YOUR_DEPLOYED_COACH_URL
```

For a mobile build, use the same deployed HTTPS endpoint:

```powershell
flutter build apk --release --split-per-abi --dart-define=AI_COACH_URL=https://YOUR_DEPLOYED_COACH_URL
# On macOS with Apple signing configured:
flutter build ios --release --dart-define=AI_COACH_URL=https://YOUR_DEPLOYED_COACH_URL
```

The Android/iPhone app calls the Firebase backend directly. A previously built
APK has no new endpoint until it is rebuilt; Chrome is only an optional test
frontend. On Windows use `npm.cmd` / `firebase.cmd` if PowerShell blocks `.ps1`
command shims. Store server parameters in `firebase/functions/.env.pi-fit-663f2`.

For that local frontend, include `http://localhost:7357` in `ALLOWED_ORIGINS`.
Production previews need their exact origin. Native mobile requests do not send
an `Origin` header. Firebase Auth authorized domains use hostnames, whereas this
backend allowlist uses the full origin, including a development port.

### Request boundaries and privacy

Remote sharing requires the profile's explicit consent and a registered account.
Before sending, the client also checks that the captured user, current Auth user
and Firebase token subject still match. This is a privacy check; the server
verifies authentication cryptographically. Requests can include training preferences, statistics for 28 days, up to eight
recent sessions, upcoming workouts, recent conversation and an active-exercise
snapshot. Program requests also include a bounded catalog selection and the
selected custom routine's revision. Private limitations and notes stay local
when remote sharing is disabled. `localContext` is never put in an HTTP body.

The backend verifies Firebase ID tokens and rejects anonymous accounts. It uses
Firestore transactions to limit each account to 10 requests per minute and
100 per 24-hour window. The request body is limited to 64 KiB; context to 24,000
characters; history to 12 user/assistant turns, 3,000 characters each and 18,000
total. Client-supplied `system` roles and unexpected top-level fields are rejected.

OpenAI output uses a strict JSON schema with `reply` and nullable `proposal`.
Program validation permits 1–7 routines, 1–12 unique exercises per routine,
1–8 sets, 1–50 reps and finite loads from 0–1,000 kg. Schedule previews validate
the selected routine, 1–12 weeks, unique weekdays, a real date and valid time.
Unknown exercise IDs, unsupported targets, stale routine revisions and malformed
provider output are rejected before a proposal reaches the app. The client checks
the complete current catalog and account/planning revision again before applying.

Profile data and previous messages are treated as untrusted data in the prompt.
The model cannot choose an arbitrary provider model or invoke write tools. The
server does not log credentials, profile text or workout messages; its OpenAI
request uses `store: false`. The selected context is still transmitted to the
provider to generate a response. Explain this in the app's privacy policy before
public release. Per-account rate limiting is not a global spending cap.

App Check validation is implemented on the server but disabled by default. Before
enabling it, register the apps with Firebase App Check, integrate
`firebase_app_check` in the client and attach its token as `X-Firebase-AppCheck`.
The current client sends an Auth ID token only; enabling enforcement prematurely
would reject its requests.

## Mobile reminders and integration checks

Calendar reminders use the device's timezone and local notification permissions;
they do not require Firebase. Android uses inexact scheduling, so battery settings
can delay delivery. The iOS implementation caps pending notifications
conservatively at 60. Notification actions and the shared workout/rest timer
require the installed Android or iOS app. Test reminders, permission denial,
background/resume behavior, Android restart and timezone changes on real devices.

Local validation currently passes **17 backend tests** and **26 coach service/
planning tests**. These cover request authentication boundaries, history,
structured proposals, invalid exercises/revisions, consent, RPE, account changes
and reviewed application/idempotency without contacting the provider. Separate
Firebase-options tests verify bundled defaults and startup timeout behavior.

Integration checks still required after configuration changes:

- Complete signup, verification, login, logout, password reset and deletion on
  the actual Android/iOS apps and Web SDK.
- Backup/restore with two accounts, including cross-account access denial.
- A deployed coach request with a valid registered user's ID token, rejected
  unauthorized origins, rate limiting and a reviewed program applied once.
- Mobile reminder and workout-shortcut actions on physical devices.

A successful local test suite does not establish that Firestore permissions,
provider billing, the deployed endpoint or platform notification delivery works.
