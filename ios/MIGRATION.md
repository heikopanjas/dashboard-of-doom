# iOS modernization record

Implementation branch: `feature/ios-modernization`.
Initial validation date: September 6, 2026. Xcode 26.2, Swift 6.2.4,
iOS 26.3 simulators on Apple Silicon.

## September 7, 2026: physical iPad launch

After the Apple account was reauthenticated, Xcode automatic provisioning signed
the Debug app successfully. Version 6.3.0 (178) was installed and launched on
the paired iPad Pro 13-inch (M5), running iPadOS 26.6.1. A subsequent device process
check confirmed the app remained running. Real background movement, permission transitions, and WeatherKit data
are still separate validation steps; this launch alone does not establish them.

Evidence: `/tmp/doom-ipad-install-build.log`, `/tmp/doom-ipad-launch.json`, and
`/tmp/doom-ipad-processes.json`.

## September 7, 2026: WeatherKit device diagnosis

Both WeatherPresenter and ForecastPresenter reach WeatherKit on the physical
iPad, but fail with `WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors`
code 2. The failure is in authentication before data publication. Other sources
fetch successfully at the measured Berlin location. Both the signed app and its
embedded provisioning profile contain `com.apple.developer.weatherkit = true`
for `8J2G689FCZ.com.panjas.DashboardOfDoom`.

The next account-side check is WeatherKit under **App Services** for that exact
App ID, in addition to App Capabilities. Apple requires both:
https://developer.apple.com/help/account/services/weatherkit/
The local entitlement/profile does not establish that the server-side service
registration is enabled. That portal setting has not yet been verified; if it
is already enabled, further Apple-side authentication investigation is needed.
Evidence: `/tmp/doom-ipad-weather-console.log`, especially lines 40–41. No source
code was changed for this diagnosis.

## September 7, 2026: user-confirmed App ID correction

The user confirmed `com.panjas.dashboard-of-doom` as the correct iOS App ID.
The earlier migration retained `com.panjas.DashboardOfDoom` from the imported
source; that identity was incorrect for the intended developer-account setup.
The root target, launch script, script test, and current documentation now use
the confirmed identifier. Historical evidence above refers to the initial ID.

The corrected Debug build signed and installed successfully on the physical
iPad. Its signature contains `8J2G689FCZ.com.panjas.dashboard-of-doom` and the
WeatherKit entitlement. The new startup log no longer shows the JWT authentication
errors seen with the previous identity. Display confirmation is pending.
The old differently identified installation was not removed, preserving its data; its obsolete background process was stopped.
The script's nine mocked tests, shell syntax, and ShellCheck pass. This correction
is part of the pending iOS 6.3.0 (178) migration, not a separate release.

Evidence: `/tmp/doom-ipad-correct-id-build.log` and
`/tmp/doom-ipad-correct-id-console.log`.

## Phases and outcome

| Phase | Action | Outcome |
| --- | --- | --- |
| 1. Preserve the baseline | Import the original iOS develop history without squashing; build and launch it before editing | Complete. Source `a534d8c6a3a80e75774ffa4688fd8380089836ed`, subtree import `56d6bd2` |
| 2. Consolidate source | Move app data code to `shared/Sources/`, reuse all five packages, remove iOS duplicate data layers and standalone project | Complete; both targets use root `project.yml` |
| 3. Preserve iOS policies | Integrate one app-owned runtime, background location, movement refreshes, legacy preferences, and foreground resume | Complete; injected lifecycle, location, scheduler, and preference tests pass |
| 4. Modernize presentation | Retain iOS navigation/charts; share collision layout and batched POIs; add POI/location settings | Complete; iPhone/iPad UI tests and visual checks pass |
| 5. Build and validate | Add iOS build script, app/package tests, simulator and macOS builds, device compilation | Complete for simulator and macOS; unsigned device Debug/Release compile |
| 6. Physical device validation | Sign, install, test Always authorization and actual background movement/delivery, and WeatherKit | Signed iPad installation and launch passed September 7; background/WeatherKit behavior checks remain pending |

## Preserved identities and boundaries

| Setting | macOS | iOS |
| --- | --- | --- |
| Version | 6.4.3 (147), from 6.4.2 (146) | 6.3.0 (178), from 6.2.0 (177) |
| Bundle identifier | `com.panjas.dashboard-of-doom` | `com.panjas.dashboard-of-doom` (user-confirmed September 7) |
| Minimum OS | macOS 15 | iOS 26 |
| App language | Swift 5 | Swift 5 |
| Signing | Existing Developer ID/profile configuration | Automatic, team `8J2G689FCZ`, Apple Development |
| Location | Foreground, kilometer accuracy, When In Use | Best accuracy, Always request, continuous background updates, no auto pauses, visible indicator |
| Movement refresh | First measurement immediately; later context updates | Every accepted movement immediately |
| Water preference | `showLevels` | `showWater` |
| Poll fetching | `showElectionPolls`, default true | `enableElectionPolls`, default false |
| Poll map visibility | `showElectionPolls` | Enable switch AND `showElectionPolls` (default true) |
| Map label dimensions | 131 × 33 points | 132 × 36 points |

The five packages retain Swift tools 6.2 and Swift 6 language mode. Services keep
static APIs and failure-to-nil cancellation behavior; Tools stays independent of
Process. No locked external dependency revision changed. WeatherKit entitlements,
iOS background-location plist mode, assets, and chart interaction code are retained.

Controllers, presenters, transformers, models, extensions, and map/POI views
are shared. Navigation, app entry points, settings screens, charts, and assets
remain platform-owned. The old iOS process/location/network singletons and
service/unit/tool copies are removed. Their originals remain in Git history.
The combined data pipeline uses the current macOS implementations, including
station suitability/caching, Overpass priority/fallback, and cancelled-result
suppression. One numeric difference from the imported iOS baseline is the
removal of its additional 13-sample moving-average pass after concatenating
particle measurements and forecasts; the shared current pipeline retains the
existing Gaussian interpolation smoothing. Unit coefficients, timestamps,
metadata, and the shared numerical algorithms were not modified by migration.

## Lifecycle and presentation

`IOSAppDelegate` owns one `IOSAppRuntime`. Startup is idempotent, including when
multiple scenes use the same runtime. Only the coordinator starts the shared
location manager. Location settings and POIs consume independent streams.
Backgrounding does not stop tracking; returning to active refreshes once.
The accepted-movement threshold remains strictly greater than 100 metres.
Initialization itself requests no permission. Authorization scope exposes
Always versus When In Use without changing existing broad authorization values.

Weather and forecasts refresh regardless of display settings. Disabling other
sources unregisters and cancels them, retains successful values, and blocks
refresh attempts from timers, movement, bulk refresh, or sensor/scope settings.
Re-enabling refreshes using the latest coordinator location. Poll map visibility
does not change iOS poll fetching.

The iOS map can render the HKW fallback and other sources while WeatherKit is
unavailable. POIs retain a 6,666.67-metre radius, one-hour cache within 1 km,
minute expiry checks, five-minute failure cooldown, and two-request limit across
cancelled generations. UIKit symbols are rasterized before the single Core
Graphics Canvas pass. POIs never enter the collision solver or change fitting.
Labels are opaque whenever the POI master switch is on, including loading/empty
results, and half-opacity when off. Their fixed visual size is capped at normal
Dynamic Type on iOS; VoiceOver retains full values. Map headers and chart heights
adapt to larger text. The original bottom toolbar and chart drag gestures remain.
Accent selection now persists under `selectedColor`; the theme follows the system
unless Always Use Dark Theme is enabled.

## Verification evidence

All simulator testing used **HKW: 52.51889, 13.36528**. Movement-policy tests start
there. Other existing package tests use injected coordinates and never request
native location or live network access. Location-configuration tests inject the
settings boundary rather than requiring a background-capable XCTest host.

| Check | Result |
| --- | --- |
| Imported iOS baseline Debug compilation and iPhone/iPad launch | Passed; initial live screenshots showed loading placeholders |
| macOS app Swift Testing | 14 tests passed |
| iOS app Swift Testing | 17 tests passed, including legacy flags, cancellation, lifecycle, accent persistence, and rendered large-text labels |
| Location package Debug | macOS 8 tests; iOS 9 tests passed |
| Network package Debug | 18 tests passed on each platform |
| Process package Debug and Release | 17 tests passed per platform/configuration |
| Tools package Debug and Release | 22 tests passed per platform/configuration |
| Services package Debug and Release | 2 parameterized tests passed per platform/configuration |
| iPhone 17 Pro and iPad Pro 13-inch (M5) UI | Navigation/drag tests passed; inspected portrait/landscape, light/dark, accessibility text, 2,000 and 10,000 POIs |
| Build scripts | bash syntax, ShellCheck, and 9 mocked Python tests passed |
| Signed macOS Debug and Release | Builds passed; both signatures verified with strict/deep checks; both launched |
| iOS simulator Debug and Release | Builds passed; Release launched at HKW using `build-ios.sh --release --simulator UUID --run` |
| iOS device Debug and Release, unsigned | Both compiled successfully |
| Live iOS simulator smoke | Release map and charts loaded COVID, water, radiation, particles, and POIs near HKW |

Unit tests use isolated preferences, callbacks, a controlled clock, and suspended
fetches. They cover disabled startup, missing defaults, all five conditional flag
mappings, repeated notifications, rapid toggles, cancelled-result suppression,
retained values, attempts while disabled, weather/forecast display-off refreshes,
and setting changes without an open view. The UI fixture is available only in
Debug with explicit `--ui-fixture`; it does not start coordinator/network/location
work. `--poi-10000` selects the larger fixture. Release contains neither fixture.

Local evidence (ignored build artifacts):

- `.build/ios-baseline/iphone-hkw.png` and `ipad-hkw.png`
- `.build/ios-ui/iphone-final/` and `ipad-final/` (screenshots and manifests)
- `.build/ios-tests/Logs/Test/` and `.build/poi-tests/Logs/Test/` (app xcresults)
- `.build/ios-packages/<package>/<configuration>/DerivedData/Logs/Test/`
- `.build/ios/simulator/Release/iphone-hkw-live.png`
- `.build/macos-migration-smoke.png`

Logs are in `/tmp/doom-*-migration-*.log`, `/tmp/doom-ios-*.log`, and
`/tmp/doom-build-script-tests.log`. The CLGeocoder deprecation warnings are known and
accepted for now; AGENTS.md records the decision to keep the provider and geocoder. Xcode UI tests also
record a UIKitToolbar hosting diagnostic; navigation and screenshots passed.

## Repeat the checks

Use [root iOS build instructions](../README.md#ios-development). For package tests,
run from the repository root, with a booted simulator UUID:

```bash
xcrun simctl location SIMULATOR_UUID set 52.51889,13.36528
cd doom-kit-process
xcodebuild -scheme doom-kit-process -configuration Release \
  -destination 'platform=iOS Simulator,id=SIMULATOR_UUID' \
  -parallel-testing-enabled NO ENABLE_TESTABILITY=YES CODE_SIGNING_ALLOWED=NO test
```

Repeat for Location and Network in Debug, and Process, Tools, and Services in
Debug and Release. Release testability is needed for `@testable` imports; it does
not disable optimization. When running builds concurrently, give each a distinct
`-derivedDataPath`, `SYMROOT`, and `OBJROOT` as the build scripts do.

## Remaining physical-device checks

These have not been recorded as done. Signing works: `./ios/build.sh --device UDID --run`
builds, installs and launches on a paired iPhone or iPad.

1. Verify WeatherKit returns conditions and forecasts on the device.
2. Test fresh, denied, While Using, and Always permissions. Confirm Settings
   reports the actual scope and fallback honestly; grant Precise Location.
3. With Always permission, lock/background the device and move more than 100 m.
   Confirm the background indicator, accepted-location changes, and enabled-source
   refreshes. Check the OS's actual suspension and battery behavior; timers alone
   do not establish background scheduling guarantees.
4. Disable sources, move again, return to the foreground, and confirm cancelled
   work cannot publish. Re-enable and confirm refresh at the current location.
5. Exercise background/foreground transitions and multiple scenes to confirm one
   runtime, one location manager, and one foreground refresh per return.

Simulator fixtures and tests verify policy and cancellation; they do not establish
real GPS delivery, OS background execution, or WeatherKit provisioning.
