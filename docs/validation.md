# Pi Fit 0.3.0 verification

Checks performed on 15 October 2026 in the Linux cloud environment.

| Check | Result |
| --- | --- |
| Repeatable setup | `bash scripts/setup_cloud.sh` re-ran successfully with frozen dependency lockfiles |
| Flutter analyzer | No issues |
| Full Flutter suite | 212 tests passed; 23 calendar/notification tests passed after the final route-name fix |
| Backend TypeScript / Node | Compilation and 17 tests passed; provider responses are simulated |
| Firebase configuration helper | 4 Python tests passed |
| Catalog reproducibility | All 876 upstream records reproduce 878 English movements with legacy IDs retained |
| Web release | Built with local renderer resources and a vendored, integrity-verified PDF.js library |
| Android release | ARM64, ARMv7 and x86_64 split APKs built |
| Android package | `com.pifit.app`, version 0.3.0, minSdk 26 / targetSdk 36; APK signature verified |
| Notification resources | `ic_notification` survives shrinking; action receiver and six Health read permissions are packaged |

## What the tests cover

The suite checks actual versus planned sets, invalid input, strength estimate
eligibility, score formulas, calendar boundaries, weekly streaks, chart periods,
workout exercise search/combined filters, persistence and bulk scheduling. New
coverage includes optional RPE serialization/clearing, effort-aware live advice,
shared elapsed/rest timing, notification actions and stale/replayed payloads,
measurement history and Health imports, and real PDF generation with inclusive
custom dates and themed sections.

Coach proposals are checked against real catalog IDs, equipment and user
preferences, current account and routine revisions, and idempotent application.
A preview does not write routines. Applying is serialized and account-bound;
active and historical sessions retain their recorded values. API requests bind
the captured account to both the current Firebase user and the token subject
after token retrieval; signature verification remains on the backend.

Account changes during sign-in, restore, measurement import, report creation,
coach requests, notifications and Watch events are covered by isolation tests.
The native Watch code also rejects callbacks from superseded sensor sessions.

## Browser and PDF checks

Chromium checks use a 390 × 844 viewport and the Europe/Bucharest time zone.
Dark/light home, English exercise search, profile, body history, progress charts,
workout logging, effort feedback and coach previews were reviewed against the
release web build. Applying a preview saved exactly three routines; changing a
set from RPE 10 to 7 persisted the new rating and immediately changed its
guidance. Body charts were additionally checked at 320 px. Screenshots whose names contain `demo` use a synthetic journal
in an isolated browser profile. These sessions and measurements are never
inserted into the shipped application's defaults.

PDF tests create actual PDF bytes. A three-page report was also rasterized with
Poppler for visual review. The web preview uses the locally shipped PDF.js
4.10.38 and its same-origin worker. Chromium rendered a real report with UNPKG
blocked and downloaded a valid 15,409-byte PDF after rendering; a runtime PDF CDN is not needed.
The bootstrap copies PDF input before worker transfer so previewing cannot detach
the original bytes needed for sharing. A synthetic [sample report](sample-report.pdf)
shows the actual browser-generated output. The upstream npm archive integrity,
license and source metadata are retained in `web/vendor/pdfjs/`.

## Firebase and online coaching

Public native client settings were compared with the supplied files. The Web app
ID is the owner's supplied ID; minimal Web options reuse the same project's
public Android API key until a complete official Web export is provided. No
service-account credentials or provider key are included.

Real Firebase REST signup, password sign-in, own-account lookup and deletion
returned HTTP 200 in the earlier verification. Temporary accounts were removed;
no verification or password-reset emails were sent by these REST checks.

Own Firestore backup read/write returned HTTP 403 `PERMISSION_DENIED`, with
“Missing or insufficient permissions.” No rules or administrative settings were
changed. The exact administrative cause is unconfirmed; backup service access
remains blocked pending authorized project configuration.

In this cloud browser the proxy blocks the Firebase SDK download at
`www.gstatic.com`. Startup falls back to local mode after 10 seconds and the
remaining UI works. SDK-based browser authentication is therefore unverified.
The network draft includes that domain; saving a draft does not change the live
network policy.

Online AI still needs a deployed HTTPS function, configured `AI_COACH_URL` and a
provider key in server Secret Manager. Backend tests use a simulated provider
and do not demonstrate a live OpenAI response. The current app labels its
profile-based, deterministic program builder and workout guidance as local.

## Device and Apple limitations

HealthKit and Health Connect code uses actual native APIs with explicit read
permission. Selected body measurements can be imported into the user's history;
raw activity and heart-rate samples stay outside backups and AI contexts.

The Watch target uses `HKWorkoutSession`, `HKLiveWorkoutBuilder` and
WatchConnectivity for actual sensor packets. “LIVE” requires a fresh timestamp,
a running watch workout and a reachable connection. Historical Health readings
are separately labelled. Account changes and ended phone workouts clear the
sensor state immediately and reject delayed old packets.

The Apple project, target/resource references, plist files and schemes were
checked statically. **iOS/watchOS compilation, signing, installation, permission
prompts, background transport and real sensor data have not been verified on
this Linux host.** macOS/Xcode and a paired physical iPhone/Watch are required.
See [Health and Watch setup](health.md).

Android notification actions/chronometers and iOS notification categories have
automated controller tests, but OS delivery, cold launches, device restarts,
permission refusals and time-zone changes still require real-device checks.
An Android APK cannot provide Apple Watch sensor access.

The APKs use the previous debug certificate for test-installation updates, not
store signing. Published files are listed in `downloads/SHA256SUMS.txt`; the
public download is checked against the local checksum after publication.
