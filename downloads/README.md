# Pi Fit — Android test builds

- [Download Android ARM64 (most phones, 25.4 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-arm64.apk)
- [Download Android ARMv7 (32-bit phones, 23.5 MB)](https://github.com/davidpitutiu/Pi-Fit/raw/refs/heads/main/downloads/Pi-Fit-Android-armv7.apk)

Version **0.3.1**, package `com.pifit.app`, Android 8.0/API 26 or newer.
Release-mode test builds, signed with the same debug key as the earlier Pi Fit
builds. They can update that installation and are not store-signed releases.

This version fixes the signup navigation crash and adds muscle-focus charts. It includes an English interface, exercise icons, per-set
RPE effort ratings and live advice, shared rest/workout timers, notification
shortcuts, coach proposals you can apply, height/weight history, and themed PDF
exports for custom dates or all time. The 878-exercise catalog and workout filters
remain available offline. Replacing bundled photos makes the download smaller.

Health Connect requires a compatible Android device, source data and explicit
permission. Notification delivery/actions still require physical-device testing.
Apple Watch live sensor support is in the iOS/watchOS source and requires a
separate signed iPhone/Watch build on macOS; it is not an Android APK feature.

Public Firebase client settings for `pi-fit-663f2` are included. Real email/password
authentication was verified separately through Firebase REST. Firestore backup
access is currently denied, and online AI still needs backend deployment and a
server-side provider key. Personalized local guidance and program previews work
without that deployment.

Check downloaded files against [SHA256SUMS.txt](SHA256SUMS.txt):

```bash
sha256sum -c SHA256SUMS.txt
```

Windows PowerShell:

```powershell
Get-FileHash .\Pi-Fit-Android-arm64.apk -Algorithm SHA256
```

See the [project instructions](../README.md) and [validation report](../docs/validation.md)
for build commands and the limits of cloud, Apple and device verification.
