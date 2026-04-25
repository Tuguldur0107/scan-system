# Handoff: Chainway C5 UHF Integration

This file captures the latest state so a new agent can continue immediately.

## What Was Implemented

- Integrated Chainway DeviceAPI AAR into the Flutter Android app:
  - `app/android/app/libs/DeviceAPI_ver20250209_release.aar`
- Added Gradle config for AAR + ABI targeting:
  - `app/android/build.gradle.kts` (adds `flatDir` repo for `app/libs`)
  - `app/android/app/build.gradle.kts`:
    - `minSdk = 26`
    - `abiFilters = armeabi-v7a, arm64-v8a`
    - `packaging.jniLibs.useLegacyPackaging = true`
    - dependency `DeviceAPI_ver20250209_release` as `.aar`

- Added native Android plugin for UHF:
  - `app/android/app/src/main/kotlin/com/scansystem/scan_system_app/ChainwayUhfPlugin.kt`
  - Exposes:
    - MethodChannel: `chainway_uhf/method`
      - `isSupported`, `init`, `free`, `startInventory`, `stopInventory`, `singleRead`, `setPower`, `getPower`, `getVersion`
    - EventChannel: `chainway_uhf/events`
      - emits tag events and hardware scan-key events
  - Key codes forwarded: `139, 280, 291, 293, 294, 311, 312, 313, 315`

- Updated `MainActivity`:
  - `app/android/app/src/main/kotlin/com/scansystem/scan_system_app/MainActivity.kt`
  - Registers `ChainwayUhfPlugin`
  - Intercepts scan key events and forwards to plugin

- Added Flutter service wrapper:
  - `app/lib/services/chainway_uhf_service.dart`
  - Handles native method calls + streams:
    - `tagStream` (`UhfTag`)
    - `keyStream` (`UhfKeyEvent`)

- Added new UHF live screen:
  - `app/lib/features/scan/uhf_scan_screen.dart`
  - Features:
    - start/stop inventory
    - live EPC list with count + RSSI
    - hardware key toggling
    - power slider
    - push to existing pending queue
    - optional EPC -> barcode convert before queueing

- Navigation updates:
  - `app/lib/core/router.dart`: added route `/uhf`
  - `app/lib/widgets/app_shell.dart`: mobile nav index 1 now points to `/uhf`


## Bug Fixes Applied After Initial Integration

- Fixed slider assertion crash:
  - was failing when power value became `-1`
  - now power is clamped to `[5..33]`
  - invalid `getPower()` values are ignored and safe default retained

- Reduced UI freezing while reading:
  - incoming tag events are now batched and UI refresh is throttled (timer-based)
  - avoids `setState()` per tag callback
  - start/stop inventory native calls moved to background executor


## Important Runtime Notes

- This works on real Chainway C5 hardware only (ARM ABIs). Emulator is not supported.
- Chainway App Center/UHF demo must be fully closed while this app reads UHF:
  - both apps cannot own UART reader simultaneously.


## What To Verify Next (for new agent)

1. Build/install on C5 and confirm no Gradle/native packaging error.
2. Validate:
   - init success
   - start/stop via button
   - start/stop via hardware trigger keys
   - tag stream updates smoothly without major UI jank
3. If still laggy under high tag rate:
   - move dedupe/aggregation into native layer before emitting events
   - reduce event payload to only `epc`, `count`, `rssi`
4. Optional UX enhancement:
   - make trigger behavior configurable:
     - press-hold to scan / release to stop
     - or toggle mode


## Quick Run Command

From `scan-system`:

```powershell
.\scripts\run_android.cmd
```

