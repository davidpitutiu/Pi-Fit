# Pi Fit ⚡

Pi Fit is a Flutter workout journal for Android and iPhone, with an English interface, frosted surfaces, light/dark themes and an electric-lime accent. Current version: **0.3.1**.

**[Download the Android ARM64 test APK](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)** · [Other builds and checksums](downloads/README.md)

## What you can do

- Browse **878 exercises** from the pinned open Free Exercise DB plus two original movements. Search English names or retained Romanian aliases; combine muscle, equipment, level and category filters in the library, routine builder and active workout.
- Browse clear exercise and equipment icons throughout the library, workouts and routine cards. Follow the written exercise instructions for technique. No photos or anatomy illustrations are displayed. [Catalog source and license](docs/exercise-sources.md).
- Build custom routines, start a free workout, log/edit actual reps and loads, track checked versus planned sets, resume a saved workout and record optional **RPE effort from 1–10** for the last completed set.
- Follow live elapsed/rest timers and real set, rep, volume and record changes. On-device coaching reacts to each exercise's current sets and reported effort. Suggestions can adjust the next unchecked set or start a recommended rest when selected. Online feedback additionally requires a configured backend, signed-in account and consent.
- Enable **workout notification shortcuts** per account: **Check set** and **Skip rest** open Pi Fit and validate the current session. Android shows a system chronometer; iPhone notifications show a rest deadline. Shortcuts share the workout screen's timer. Stale/replayed actions cannot check a different set.
- Ask Pi Coach to **create a program or modify a saved custom routine**, add/replace/remove exercises, or adjust sets/reps/duration. Review the proposed routines and optional calendar dates, then apply them in the app. Plans validate actual catalog IDs and account/routine revisions before writing. The local builder works without a language model; online structured proposals require deployment. [Coach setup](firebase/README.md).
- Schedule individual workouts or bulk dates over 1–12 weeks, choose days/time, avoid duplicates and request local reminders on Android/iOS.
- See muscle focus over 7/28/90 days: a chart and per-group percentages from completed strength sets, including groups with zero sets. Open a group to inspect its actual exercise contributions; secondary involvement is shown separately without counting a set twice.
- Explore 7/28/90-day volume, sets, sessions and duration charts; per-exercise load/estimated-1RM history; muscle distribution; an **all-time completed-workout count**; a weekly streak relative to your own target; and a fully explained consistency score. Rest days do not interrupt a weekly streak.
- Record dated **height and weight**, update your profile, view actual measurement trends/history and explicitly import selected readings from Apple Health or Health Connect. Known Romanian profile values and old journal IDs migrate without deleting history.
- Connect Health for steps, active energy, workouts, height, weight and timestamped heart-rate readings. Saved body readings require explicit import. Raw Health activity and heart rate are not added to backups or AI prompts.
- On iPhone, start the included **Pi Fit Apple Watch companion** for actual sensor heart rate during a watch workout session. The phone receives live WatchConnectivity packets; fresh connected readings are labelled LIVE, stale/disconnected values are labelled accordingly. Historical Apple Health readings remain separate. This requires a signed iPhone/watch build, watch installation and device authorization. [Apple Watch and Health details](docs/health.md).
- Create a designed **PDF report** for 7/28/90 days, custom inclusive dates or all time. Customize the title, light/dark/app appearance and sections; include workout counts, charts, journal, records, rated-set effort and saved body measurements. Preview, download/share, or print/save.
- Use email/password signup/login, verification/reset, account-isolated local journals, explicit guest import, JSON recovery export and manual Firestore backups. Firebase public client files are included. Cloud backup access is currently denied by the project's administrative configuration; see below.

Version 0.3.1 fixes signup navigation that could pop the home screen after authentication. Registration setup is bounded so delayed profile/email operations cannot leave the form waiting indefinitely. Existing account journals are preserved.

## Run on Windows PowerShell

Install Flutter **3.47.7 / Dart 3.13.5**, add `flutter\bin` to PATH and reopen PowerShell. From this repository:

```powershell
flutter doctor
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter run -d chrome
```

Use `flutter` directly on Windows. `scripts/flutterw` is the Bash wrapper for the Linux cloud environment; opening it from PowerShell produces the file-association dialog.

For Android, install the Android toolchain and use a device/emulator. The minimum is **Android 8.0/API 26**, with API 36 for builds. The cloud setup uses JDK 21. iPhone/watch builds require macOS, Xcode and Apple signing; iOS minimum 15 and watchOS minimum 10.

```powershell
flutter run -d <device-id>
flutter build apk --release --split-per-abi
# On macOS, refresh Flutter's generated Apple build settings before Xcode:
flutter build ios --config-only --release
```

Open `ios/Runner.xcworkspace` on macOS, select the same signing team for Runner and PiFitWatch, enable HealthKit in the provisioning profiles and install both targets on a paired iPhone/Watch. Native Apple compilation and real-device behavior have **not** been verified on this Linux host.

## Firebase and online AI

Public defaults for `pi-fit-663f2` are committed in `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` and `firebase/web-config.json`. Normal startup needs no copied local config or Dart defines. `scripts/configure_firebase.py` can regenerate them from replacement public exports; complete Dart defines remain optional overrides.

The Web app ID is the one provided by the project owner; its minimal options currently reuse the same project's public Android API key until the full Web export is provided. Real email/password signup, login, lookup and cleanup were verified through Firebase REST. Browser SDK login remains unverified in this cloud instance because the network proxy blocks the Firebase Web SDK at `www.gstatic.com`; startup falls back to local mode after 10 seconds.

Firestore own-backup reads/writes returned `403 PERMISSION_DENIED`. No rules or administrative settings were changed, and their exact cause was not confirmed. Publish/check the included per-user rules from an authorized Firebase account before relying on backups.

Online AI needs the authenticated Firebase function, its HTTPS URL in `AI_COACH_URL`, and the provider key in server Secret Manager. Never put service-account credentials or an AI provider key in Flutter. Without that deployment, the app labels its personalized suggestions and program builder as local. [Deployment and privacy details](firebase/README.md).

## Verification and cloud development

```bash
cd /workspace/Pi-Fit
bash scripts/setup_cloud.sh
./scripts/flutterw analyze
./scripts/flutterw test
python3 -m unittest discover -s test -p 'test_configure_firebase.py' -v
python3 scripts/import_exercise_catalog.py --check
PATH=/workspace/node22/bin:$PATH npm --prefix firebase/functions test
./scripts/flutterw build web --release --no-wasm-dry-run --no-web-resources-cdn
./scripts/flutterw build apk --release --split-per-abi
```

The setup script pins the SDK and verifies official toolchain downloads. Use the existing checkout; every cloud task is already isolated and does not need another Git worktree. Version-specific results and remaining device/cloud limitations are in [docs/validation.md](docs/validation.md).

Android downloads are release-mode **test builds signed with the previous debug key**, so they can update the previous installation. Store signing and distribution are separate. Notification delivery/actions, Apple authorization, sensor freshness and signing must be checked on actual target devices.

Screenshots: [Dark home](docs/screenshots/home-dark.png), [Light home](docs/screenshots/home-light.png), [Exercises](docs/screenshots/exercises-dark.png), [Workout](docs/screenshots/workout-demo-dark.png), [Charts](docs/screenshots/charts-demo-dark.png), [Muscle focus](docs/screenshots/muscle-focus-demo-dark.png), [Effort feedback](docs/screenshots/live-advice-demo-dark.png), [Body history](docs/screenshots/body-measurements-demo-dark.png), [Program preview](docs/screenshots/coach-plan-demo-dark.png), [PDF example](docs/sample-report.pdf). Report/workout examples use an explicitly isolated synthetic browser journal; the app does not populate fake training data.

Inter is distributed under the [SIL Open Font License](assets/fonts/OFL.txt).
