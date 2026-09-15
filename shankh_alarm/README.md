# Shankh Alarm (Flutter)

[![Build Shankh Alarm APK](https://github.com/SarbojitMishra/MobileApps/actions/workflows/build-apk.yml/badge.svg)](https://github.com/SarbojitMishra/MobileApps/actions/workflows/build-apk.yml)

A Flutter/Android port of the original native "Shankh Alarm" project — a
sunrise/sunset conch-shell alarm clock. It:

- Computes **local sunrise and sunset offline** (NOAA solar-position
  formulas — no internet, no API key), using the device's GPS location when
  granted, and **defaults to Bhubaneswar, Odisha (20.2961° N, 85.8245° E)**
  otherwise.
- Fires an **exact, Doze-exempt alarm** at each sunrise and sunset using
  Android's `AlarmManager.setAlarmClock()` (via `android_alarm_manager_plus`)
  — the same mechanism real alarm-clock apps use.
- Plays the **shankh (conch) recording** (`assets/audio/shankh_alarm.ogg`,
  also bundled as `android/app/src/main/res/raw/shankh_alarm.ogg` for the
  notification channel) on loop over the dedicated Alarm audio stream, with
  a full-screen ringing UI, Stop and Snooze.
- Survives reboots (`rescheduleOnReboot: true` restores the alarm chain
  after `BOOT_COMPLETED` / VIVO's `QUICKBOOT_POWERON`).
- Reschedules itself the moment each alarm fires, so a self-sustaining
  chain runs indefinitely without the app needing to stay open.

## v2 changes (against the PRD/SRS/TDS spec)

Implemented in this pass, mapped to the spec's requirement IDs:

- **Snooze cap** (ALM-FR-010): capped at 3 snoozes per alarm instance,
  shown on the ringing screen ("Snooze 5 min (n/3 used)"); a 4th attempt is
  refused with an in-app message and the alarm keeps ringing.
- **Auto-stop, logged** (ALM-FR-011): ringing still auto-stops after 10
  minutes unattended, now explicitly logged as `auto_stopped` instead of a
  silent safety cap.
- **Alarm History** (ALM-FR-012, fixes G3/G5): a local, capped (30-entry)
  log of every fired/missed/auto-stopped alarm, viewable from Home →
  "Alarm History". A firing more than 3 minutes late (device was off/killed
  through the instant) is logged as `missed` instead of ringing at the
  wrong time.
- **Manual location override** (ALM-FR-006): Home → "Set location
  manually" — latitude/longitude entry only (no geocoding — Section 42
  OQ-02's offline-first-preserving default), with range validation and a
  "Reset to Bhubaneswar default" action.
- **Reliability Checklist** (UI-FR-002): consolidates battery-optimization
  and exact-alarm status (live, where Android exposes it) plus VIVO
  autostart / lock-in-Recents guidance (undetectable via any public API, so
  shown as "please verify manually" rather than a false green checkmark)
  into one screen, replacing v1's README-only guidance.
- **Test shankh sound** button on Home, so audibility can be checked
  without waiting for an actual sunrise/sunset.
- **Fail loud, not silent** (Design Principle 3): a scheduling failure
  (e.g. a revoked exact-alarm permission) now surfaces as a warning banner
  on Home instead of the alarm just quietly never firing again.
- **"No alarms active" state** (ALM-FR-005 edge case): shown explicitly on
  Home when both Sunrise and Sunset are switched off.

**Why no separate `TimeChangeReceiver`/G2 fix was needed:** the spec's G2
gap assumes a 365-day table of *pre-computed* UTC instants that can go
stale after a timezone/time change. This app never caches future instants
— `SunCalculator` computes the next sunrise/sunset fresh, from lat/lon and
the current date, every time it schedules an alarm. A UTC sunrise/sunset
instant is a function of latitude/longitude/date only, not of the device's
timezone setting, so an already-registered alarm remains astronomically
correct across a timezone change; the *displayed* next-alarm time
self-corrects the moment `scheduleAll()` next runs (already true on every
app resume). A dedicated broadcast receiver would be solving a problem
this architecture doesn't have.

**Audio (G1) — not resolved in this pass:** v1's `shankh_alarm.ogg` is
still the placeholder synthesized sound described in the spec's Section
3.3/13.1 — it must **not** ship in a real release. The spec's recommended
CC0 source (`freesound.org/people/RoofDog/sounds/78974/`) could not be
fetched from the sandbox this change was made in (`freesound.org` is
blocked by the same egress policy documented below for `dl.google.com`).
To finish Section 13: download that WAV (or another verified-licensed
source per Section 13.3), loop-edit it per Section 14, and replace both
`assets/audio/shankh_alarm.ogg` and
`android/app/src/main/res/raw/shankh_alarm.ogg` before any real-world
release.

## Why Flutter instead of a 1:1 Kotlin port

The uploaded project was a native Android/Kotlin app. You asked for a
Flutter app, so this rebuilds the same behavior on Flutter using:

| Original (Kotlin)                         | Flutter equivalent                                   |
|--------------------------------------------|-------------------------------------------------------|
| `SunCalculator.kt` (NOAA formulas)          | `lib/sun_calculator.dart` — same math, ported to Dart |
| `Prefs.kt` (SharedPreferences)              | `lib/prefs.dart` (`shared_preferences`)               |
| `LocationHelper.kt` / `SunTimesRepository.kt` | `lib/location_service.dart` (`geolocator`)          |
| `AlarmScheduler.kt` + `AlarmManager.setAlarmClock` | `lib/alarm_scheduler.dart` (`android_alarm_manager_plus`, `alarmClock: true`) |
| `AlarmReceiver.kt` / `BootReceiver.kt`      | Background isolate callback in `alarm_scheduler.dart` (`rescheduleOnReboot: true`) |
| `AlarmService.kt` (foreground service, MediaPlayer, vibration, full-screen notification) | `lib/notification_service.dart` (full-screen alarm notification) + `lib/screens/alarm_screen.dart` (`audioplayers` loop, `vibration`) |
| `AlarmActivity.kt` / `activity_alarm.xml`   | `lib/screens/alarm_screen.dart`                       |
| `MainActivity.kt` / `activity_main.xml`     | `lib/screens/home_screen.dart`                        |
| Room DB of 365 pre-computed days            | Not needed — the NOAA calculation is cheap enough to run on demand for "next occurrence", so there's no local database. |

One intentional simplification: `geolocator` (a well-maintained, widely
used Flutter plugin) is used for device location instead of hand-rolling a
`LocationManager` wrapper. On most devices (VIVO/FunTouch included) this
works the same way; devices with no Google Play Services at all fall back
automatically to the Bhubaneswar default, same as the original app.

## Get a built APK from GitHub Actions

This repo builds the APK automatically via
[`.github/workflows/build-apk.yml`](../.github/workflows/build-apk.yml) on
every push to `main` and every pull request that touches `shankh_alarm/`.

### Straight to your phone (recommended)

**[Download app-release.apk](https://github.com/SarbojitMishra/MobileApps/releases/download/apk-latest/app-release.apk)**
— open this link in your Android phone's browser and it downloads the APK
directly (no GitHub login, no zip). Tap the downloaded file to install
(allow "install from this source" once, since it isn't from the Play
Store). This link always points at the newest build from `main`; see the
[apk-latest release](https://github.com/SarbojitMishra/MobileApps/releases/tag/apk-latest)
page for `app-debug.apk` too.

A manual "Run workflow" dispatch on a non-`main` branch (or via the API)
publishes the same way under `apk-preview-<branch-name>` instead, so a
branch can be tried on a phone before it's merged, without touching the
`apk-latest` release `main` owns.

### From a specific commit/PR build

1. Open the [Actions tab](https://github.com/SarbojitMishra/MobileApps/actions/workflows/build-apk.yml)
   (or the badge above) and pick the run for the commit you want.
2. Download the `shankh-alarm-apk` artifact — it contains both
   `app-debug.apk` and `app-release.apk` (release is debug-signed for now;
   see below to add real signing). Note: this requires being signed in to
   GitHub and comes as a `.zip`, unlike the direct link above.
3. Copy the APK to your phone and install it (allow "install from this
   source" once, since it isn't from the Play Store).

You can also trigger a build on demand from the Actions tab's "Run
workflow" button (the `workflow_dispatch` trigger).

### Why CI instead of building here

The development sandbox this app was built in runs in a cloud environment
whose egress policy allows `storage.googleapis.com` (enough to download the
Flutter SDK) but blocks `dl.google.com` — which is where the Android SDK
command-line tools **and** Gradle's `google()` Maven repository (needed to
resolve AGP's own build tooling and AndroidX/Play Services dependencies)
are served from. That made compiling an APK impossible in that sandbox,
which is exactly why this workflow exists: GitHub's own runners have normal
internet access, so the build just works there.

Everything else was verified directly in that sandbox before this workflow
was added:
- `flutter pub get` — all dependencies resolve.
- `flutter analyze` — zero issues.
- `flutter test` — the smoke test passes.
- Launcher icons (adaptive, saffron background + gold conch-spiral
  foreground — regenerate via `design/make_icon.py` if you want to tweak
  the artwork) are already generated into `android/app/src/main/res/mipmap-*`.

## Build the APK locally

1. Install [Android Studio](https://developer.android.com/studio) (which
   bundles the Android SDK) if you haven't already, and make sure
   `flutter doctor` reports the Android toolchain as ✅.
2. From this directory: `flutter pub get`.
3. `flutter build apk --debug` (or `--release` once you've set up a signing
   config in `android/app/build.gradle.kts`).
4. The APK lands at `build/app/outputs/flutter-apk/app-debug.apk`. Copy it
   to your phone and install it (allow "install from this source" once).

## First run on the phone

On first launch the app asks for:
- **Location** — grant it to use the phone's actual GPS position; toggle
  off "Use my current location" in the app to stay on the Bhubaneswar
  default.
- **Notifications** (Android 13+) — needed to show the full-screen alarm
  reliably.
- It may also prompt to **allow exact alarms** — tap the in-app "Allow
  exact alarms" button if the toggle in Android's alarm settings isn't on.

## VIVO / FunTouch OS — do this or the alarm may get silently killed

VIVO's FunTouch/OriginOS is aggressive about killing background apps. The
alarm is scheduled with `AlarmManager.setAlarmClock()`, which is designed
to survive this, but FunTouch still needs a few manual switches flipped:

1. **Battery optimization**: tap "Ignore battery optimization" in the app
   (or *Settings → Battery → Background power consumption management →
   Shankh Alarm* → "Allow"/"No restrictions").
2. **Autostart**: *Settings → More settings → Permission manager →
   Autostart* — enable it for Shankh Alarm, so the boot-time reschedule can
   run.
3. **High background power usage**: some FunTouch versions have a separate
   toggle under *i Manager → Battery* — allow it for this app.
4. **Lock the app in Recents**: long-press the app card in the recent-apps
   switcher and tap the lock icon.
5. Check **Do Not Disturb** exceptions — the alarm plays on the dedicated
   Alarm stream so it should sound even in DND, but some FunTouch DND modes
   silence everything.

## Project layout

```
lib/
  sun_calculator.dart     offline NOAA sunrise/sunset math
  prefs.dart              typed SharedPreferences wrapper
  location_service.dart   GPS location via geolocator, Bhubaneswar fallback
  alarm_scheduler.dart    schedules/reschedules the next sunrise+sunset alarms
  notification_service.dart  full-screen alarm notification (Stop/Snooze actions)
  alarm_port.dart         wakes the live app instantly when an alarm fires
  alarm_history.dart      local, capped fired/missed/auto-stopped alarm log
  screens/home_screen.dart   settings screen (toggles, permissions, today's times)
  screens/alarm_screen.dart  full-screen "alarm is ringing" UI (snooze cap, auto-stop)
  screens/reliability_checklist_screen.dart  battery/exact-alarm/autostart status
  screens/location_override_screen.dart      manual lat/lon reference location
  screens/alarm_history_screen.dart          last 30 fired/missed/auto-stopped events
  main.dart               wiring + cold-start / background-wake routing
assets/audio/shankh_alarm.ogg          the conch alarm sound (loops in-app)
android/app/src/main/res/raw/shankh_alarm.ogg   same sound, as the notification's own cue
design/make_icon.py       regenerates the launcher icon artwork
```

## Customizing

- **Default location**: edit `defaultLat` / `defaultLon` / `defaultLocationName`
  in `lib/prefs.dart`.
- **Sound**: replace `assets/audio/shankh_alarm.ogg` **and**
  `android/app/src/main/res/raw/shankh_alarm.ogg` with your own recording
  (keep both in sync — one is the looped in-app sound, the other is the
  notification channel's cue).
- **Snooze duration**: `Duration(minutes: 5)` in `AlarmScheduler.snooze()`.
