# Health records and live Apple Watch heart rate

Pi Fit has two separate integrations: historical records from Apple Health / Health Connect and a genuine Apple Watch sensor stream during a watch workout. Historical reads are never labeled as a live sensor stream.

## Historical records and body imports

The app uses [`health` 13.3.2](https://pub.dev/packages/health/versions/13.3.2), maintained at [carp-dk/carp-health-flutter](https://github.com/carp-dk/carp-health-flutter). Opening the Health screen checks availability only; it does not read records or request health permissions. **Connect and choose access** explicitly requests read access to steps, active energy, workouts, heart rate, height and weight. Android also requests the plugin-recommended Activity Recognition permission for steps. Refreshing never opens new permission requests automatically.

Activity and historical heart-rate reads cover the latest seven local calendar days. Steps use the platform's aggregated daily query, with unavailable values left unknown. Energy uses actual kilocalorie samples from one selected source; overlapping totals from different apps are not silently added together. Source/UUID duplicates, invalid values, invalid intervals and future-ending records are excluded. Energy is assigned to its start day instead of being divided across midnight using an estimate.

Historical heart rate displays the latest accessible measurement with its real source and timestamp. A record from Apple Health can be delayed by Watch-to-iPhone synchronization. It is not an Apple Watch live stream.

Body records use a 30-day lookback on Health Connect, without requesting extra history access, and a 365-day lookback on Apple Health. Weight is normalized to kilograms and height to centimetres using the record's actual unit. Import is a separate explicit action on one selected record, followed by confirmation. Only that measurement enters the account-scoped body history/profile. Source record IDs make repeated imports idempotent. Older imported measurements do not replace newer profile values.

Imported body measurements follow normal profile backup/export and personalization behavior. Raw heart-rate, energy and external-workout records are not saved into the profile, backups, Firebase or AI requests. Account changes clear the Health screen and prevent an earlier pending read or import confirmation from affecting the new account. External workouts do not increase the Pi Fit streak or training score.

Apple Health deliberately does not disclose whether read access was refused. Completing its authorization sheet is not proof that every read category was granted; empty results can mean either missing data or denied access. The screen explains that uncertainty.

## Genuine live Apple Watch stream

`ios/PiFitWatch` is a native SwiftUI watch app with a real `PiFitWatch` target, three signing configurations, a shared Xcode scheme, HealthKit entitlement and workout background mode. Runner depends on the target and embeds `PiFitWatch.app` under its Watch content. Its bundle ID is `com.pifit.app.watchkitapp`, paired with `com.pifit.app`. The watch AppIcon asset copies the existing Pi Fit 1024×1024 brand PNG unchanged. Its single-image `universal` / `watchos` manifest follows Apple’s official [Backyard Birds watch sample](https://github.com/apple/sample-backyard-birds/blob/1843d5655bf884b501e2889ad9862ec58978fdbe/Watch/Assets.xcassets/AppIcon.appiconset/Contents.json); no Apple artwork is bundled. All watch build configurations select `AppIcon`, and the asset catalog is in the watch Resources phase.

The iPhone bridge uses `HKHealthStore.startWatchApp(with:)` to open the watch companion with an indoor strength-workout configuration. The watch's `WKApplicationDelegate` receives the configuration, or the user can open Pi Fit on Apple Watch and press **Start live heart rate**. On explicit Start, the watch requests heart-rate read access and workout-session authorization. Workout authorization is necessary to run the genuine background-capable `HKWorkoutSession`; the watch builder is discarded on Stop instead of saving a duplicate workout.

`HKWorkoutSession` and `HKLiveWorkoutBuilder` provide actual heart-rate samples. Each transmitted sample uses the most-recent HealthKit quantity and the measurement interval's real end timestamp. There is no timer-generated BPM and no fallback that relabels an old historical value as live. A running session without a sensor measurement stays in a waiting state.

WatchConnectivity sends transient messages only while the paired iPhone is reachable. Raw heart-rate messages are not queued with `transferUserInfo` or persisted in `applicationContext`. The iPhone bridge publishes them through a Flutter EventChannel; `LiveHeartRateService` keeps only transient in-memory state. The UI treats a sample as fresh only while the watch workout is running, the phone is reachable and the measurement is at most 15 seconds old. Disconnects, pauses, stopped sessions, old timestamps and delayed reconnect packets cannot become a fake live state. The watch session can continue measuring in its supported workout background mode; the phone must be reachable to display a live stream.

Stopping from the phone sends a real stop command. If the watch is unreachable, the app instructs the user to stop directly on Apple Watch rather than claiming the command succeeded. Ending the session on the watch clears the live state on the phone when the status can be delivered. Connection loss independently removes the live indication. Account changes and the end of a Pi Fit workout synchronously clear the local live reading, blacklist its watch-session ID and require an explicit fresh start; delayed samples or status packets from the previous session cannot reactivate it. Stopping an authorization-pending watch attempt cancels its generation, and callbacks from older sessions/builders cannot mutate a newer session.

Live Apple Watch support is iPhone-only. Android and web do not pretend to offer an Apple Watch connection. Android historical heart-rate records still work through Health Connect when permitted and available. A compatible paired Apple Watch, its Pi Fit companion, authorized sensor access and an actual physical device connection are required.

## Native permissions and deployment

Android requires API 26 or later for the `health` plugin, with Health Connect additionally requiring a compatible provider/device. The manifest declares `ACTIVITY_RECOGNITION` plus only these Health Connect reads: `READ_STEPS`, `READ_ACTIVE_CALORIES_BURNED`, `READ_EXERCISE`, `READ_HEART_RATE`, `READ_HEIGHT`, `READ_WEIGHT`. It requests no health write, route, location, historical-data or background-health permission.

`MainActivity` extends `FlutterFragmentActivity` for the plugin's Activity Result permission contract. The manifest includes Health Connect package visibility, its legacy rationale intent and Android 14 permission-usage alias. Initial and new rationale intents open an actual English data-use explanation. The Activity Recognition bridge requests access only after the visible Connect action.

The iPhone deployment target remains iOS 15 for historical HealthKit reads. The bundled modern watch companion targets watchOS 10, requiring an iPhone/Watch combination compatible with that watchOS version. Runner's HealthKit entitlement and purpose strings cover the read categories; the watch target separately declares its sensor-read and necessary workout-session purposes. No background-delivery entitlement or Android background health access is enabled.

## macOS/device validation still required

The Linux environment can analyze Dart, run its tests, validate native property lists/project structure, and compile Android. It cannot run `xcodebuild`, sign iPhone/Watch targets, exercise Apple authorization sheets or verify physical WatchConnectivity. Native watch/iOS code is implemented and integrated into the project, but is not claimed to have been compiled or device-tested here.

On a Mac with Xcode 15 or later, first regenerate Flutter's local iOS configuration (do not copy the cloud machine's ignored `Generated.xcconfig` or edit it manually):

```sh
flutter pub get
flutter build ios --config-only --no-codesign
```

Keep PiFitWatch's `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` aligned with the current `pubspec.yaml` version for each release; this revision uses `0.3.0` / `3`. The generated iPhone build settings must use the same version before archiving.

1. Open `ios/Runner.xcworkspace`. Select the same Apple development team for Runner and PiFitWatch, with HealthKit enabled for both app IDs and valid provisioning profiles. Build Runner for a paired iPhone and build/run the PiFitWatch scheme on its paired watch. Confirm the embedded companion is installed.
2. Open the Health screen without pressing Connect. Confirm no health prompt or data read occurs. Connect, grant selected read categories and compare real seven-day activity, timestamps and measurement units against the platform. Test denied/partial permissions and revoke access before refreshing.
3. Select one height or weight record, review its timestamp/source and import it. Verify only that selected measurement appears in the correct account's history. Cancel an import or change accounts while confirmation is open; no measurement should be added to the new account.
4. Start live heart rate from the iPhone. Allow workout-session and heart-rate access on the watch. Confirm BPM changes only when actual `HKLiveWorkoutBuilder` sensor samples arrive, with real timestamps and no live badge before the first sample.
5. Compare a real sensor session with the watch display. Background the watch UI while its workout remains active, disconnect/reconnect the phone, pause/stop the watch workout and deny read permission. Confirm fresh/stale/disconnected/stopped states remain truthful. A simulator cannot establish physical sensor correctness.
6. End the session and verify no duplicate workout was saved by Pi Fit's watch builder. Confirm raw pulse samples never appear in a Pi Fit backup or AI payload.

Automated tests cover seven-day boundaries, unit normalization, permission uncertainty, source separation, future/duplicate filtering, explicit single-record import/account guards and live-stream freshness/disconnection/stopped-session handling. Physical-device results remain a separate required validation step.
