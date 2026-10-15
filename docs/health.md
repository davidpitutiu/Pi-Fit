# Apple Health and Health Connect

Pi Fit uses the official [`health` Flutter package, version 13.3.2](https://pub.dev/packages/health/versions/13.3.2), maintained at [carp-dk/carp-health-flutter](https://github.com/carp-dk/carp-health-flutter). `HealthScreen` is available from the account and progress screens. The integration reads real platform records; it does not provide simulated device readings.

## Current behavior

Opening the screen checks platform/service availability only. It does not read health records or request health permissions. The visible **Conectează și alege accesul** button requests read access to steps, active energy and workouts. Android also requests the Activity Recognition permission recommended by the plugin for steps. An existing Health Connect authorization is reused without reopening an unnecessary permission sheet. The refresh button reads again without requesting additional access.

The screen shows the last seven local calendar days, including today up to the current time. Steps use the platform's aggregated daily-step query. An inaccessible or failed step query stays unknown (`—`), rather than becoming a fabricated zero. Active-energy samples are actual kilocalorie records; the user selects one source instead of automatically adding overlapping totals from different apps. The sum is a source-record total, not a validated physiological measurement or a calorie estimate. Energy is grouped by each sample's start day; samples crossing midnight are not divided by an invented estimate. Duplicate source/UUID records, invalid/negative energy values, invalid intervals and future-ending records are excluded. Workout records retain their source and actual timestamps.

Apple Health intentionally does not reveal whether read access was denied. Its authorization result only indicates the permission sheet completed. The screen explains that empty results can mean missing records or denied access and never treats the sheet completing as proof that all read permissions were granted.

Health records remain in screen/service memory. They are not written to `AppStore`, preferences, Firebase, account backups or AI prompts. Changing the account clears visible health data and ignores an earlier account's pending result. External workouts are not imported into the Pi Fit journal and do not increase the workout score or streak. This version does not export workouts, write health records, read routes or location, request background access, or read history beyond seven days.

## Android configuration

The `health` package requires Android API 26 or later; `android/app/build.gradle.kts` sets `minSdk = 26`. Health Connect itself requires a compatible device/provider (normally Android 9 or later; integrated into Android 14 or later). Runtime SDK availability is checked before authorizing or querying. Devices requiring a Health Connect provider update get an explicit install/update action. Unsupported or missing native services show an unavailable state.

`AndroidManifest.xml` declares only these health/motion permissions:

- `android.permission.ACTIVITY_RECOGNITION`
- `android.permission.health.READ_STEPS`
- `android.permission.health.READ_ACTIVE_CALORIES_BURNED`
- `android.permission.health.READ_EXERCISE`

There are no health write, route, location, historical-access or background-health permissions. Existing internet/notification permissions belong to the other Pi Fit features.

The manifest includes Health Connect package visibility, the legacy permissions-rationale intent, and the Android 14 permission-usage activity alias. `MainActivity` extends `FlutterFragmentActivity`, as required by the plugin's Activity Result registration. A small `com.pifit.app/health` channel requests/checks Activity Recognition. Both initial and new rationale/permission-usage intents display an actual local explanation of data use, retention and permission withdrawal. The app does not route these intents to a blank launch screen.

## iOS configuration

The deployment target is iOS 15.0 or later. `Runner/Info.plist` includes `NSHealthShareUsageDescription` and the package-documented `NSHealthUpdateUsageDescription`; the app requests read access only. `Runner/Runner.entitlements` enables `com.apple.developer.healthkit`. The Runner target declares the HealthKit capability, with `CODE_SIGN_ENTITLEMENTS` configured for Debug, Profile and Release. No background-delivery entitlement is enabled.

An Apple development team/provisioning profile with HealthKit enabled is required to sign and test on iPhone. Linux cannot compile, sign or exercise HealthKit, so a successful Flutter analysis or Android build does not establish iOS device readiness.

## Validation and device checks

Automated coverage is in `test/health_test.dart`: opening the screen performs no read/permission request, seven-day boundaries are correct, denied/partial permissions remain honest, energy sources are separated, duplicate/future records are excluded, iOS read-status uncertainty is preserved, narrow-screen rendering works, and pending results do not cross account changes. The adapter calls the package's real `Health.configure`, `hasPermissions`, `requestAuthorization`, `getTotalStepsInInterval`, and `getHealthDataFromTypes` APIs.

Before considering device integration verified:

1. Install the new APK on a compatible Android phone with Health Connect available and at least one source contributing steps, active calories and workouts. Open the health screen and confirm no permission prompt appears until Connect is pressed.
2. Grant only some categories first. Verify missing categories stay unavailable and the app remains usable. Reconnect and grant the remaining desired categories; compare daily steps, selected-source energy and workout timestamps with Health Connect.
3. Revoke access in Health Connect and refresh. Confirm the screen does not reuse a stale success state. Open Pi Fit's privacy-policy/rationale link from Health Connect on both a legacy-provider device and Android 14+; verify the local policy dialog appears.
4. On a signed iOS build, compare the same seven-day data with Apple Health. Test both granted and denied read access, including an empty store. Confirm the uncertainty explanation remains visible and no write permission is requested.
5. Start a read, change accounts, and ensure the previous result does not become visible. Confirm health records never appear in a Pi Fit backup or the AI request.

Physical-device authorization and data-source behavior must be tested on the target devices; automated tests in this Linux environment do not claim those checks have been performed.
