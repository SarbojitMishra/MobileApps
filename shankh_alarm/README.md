# Shankh Alarm (Flutter)

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

## Why you're getting a project, not a built APK

This session runs in a cloud sandbox that can reach `storage.googleapis.com`
(enough to download the Flutter SDK) but **cannot reach `dl.google.com`**
(egress policy denies it), which is where the Android SDK command-line
tools and build tools are distributed. Without those, Gradle can't compile
an APK here — the same limitation the original native project's README
called out for this environment.

Everything else is done and verified in this sandbox:
- `flutter pub get` — all dependencies resolve.
- `flutter analyze` — zero issues.
- `flutter test` — the smoke test passes.
- Launcher icons (adaptive, saffron background + gold conch-spiral
  foreground — regenerate via `design/make_icon.py` if you want to tweak
  the artwork) are already generated into `android/app/src/main/res/mipmap-*`.

## Build the APK

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
  screens/home_screen.dart   settings screen (toggles, permissions, today's times)
  screens/alarm_screen.dart  full-screen "alarm is ringing" UI
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
