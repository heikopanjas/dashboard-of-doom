# Agent Instructions for Dashboard of Doom (macOS and iOS)

*Last updated: September 20, 2026, 02:40 CEST (POI master switch reframed, label opacity follows the categories)*

## Project Overview

Dashboard of Doom is a sophisticated macOS menu bar application providing real-time environmental and public health data visualization for Germany. The application integrates with multiple German federal APIs to create an interactive, location-aware environmental monitoring system.

**Platforms**: This repository builds macOS 15+ and iOS 26+ apps. The original iOS develop history is imported under `ios/`. Root `project.yml` is the only Xcode project source of truth; see `ios/MIGRATION.md`.

### Current Implementation Status
- **Fully Functional**: Complete data pipeline from API integration to UI presentation
- **macOS Menu Bar App**: Lightweight menu bar extra with settings window
- **Production Ready**: Comprehensive error handling, retry mechanisms, and quality assessment
- **Modern Swift**: Uses async/await; app uses Swift 5 language mode, local packages use Swift 6 with Swift tools 6.2
- **State Management**: Full `@Observable` implementation for reactive UI updates
- **Mathematical Analysis**: Advanced forecasting and trend analysis capabilities

## Architecture & Code Patterns

### Repository Structure
- **App Roots**: `macos/DashboardOfDoom/` owns macOS entry point, menu, settings, and detail views; `ios/DashboardOfDoom/` owns iOS entry point, navigation, settings, detail views, and assets
- **Test Layout**: `macos/Tests` and `ios/Tests` hold platform tests; `ios/UITests` holds UI tests; `shared/Tests` is compiled by both app test targets. Each platform owns `BuildTests`; packages and their tests live under `shared/doom-kit-*`.
- **Shared App Code**: `shared/Sources/` owns controllers, models, presenters, transformers, extensions, and map/POI views
- **Platform-Specific**: Views and some Presenters contain macOS-specific implementations
- **XcodeGen**: `project.yml` defines both app targets, tests, settings, dependencies, and schemes; `DashboardOfDoom.xcodeproj` is generated

### Platform Architecture
- **macOS**: MVP (Model-View-Presenter) pattern optimized for menu bar applications
- **Menu Bar Interface**: Lightweight status bar extra with popover/window presentation
- **Settings Window**: Dedicated configuration interface for user preferences
- **Shared Business Logic**: Both apps compile `shared/Sources/` and use the same five local DoomKit packages

### Core Components

#### Data Flow Architecture
```
Controllers → Services → Transformers → Presenters → Views
```

1. **Controllers**: Orchestrate API communication and data parsing
2. **Services**: Handle HTTP requests to German federal APIs
3. **Transformers**: Process raw data into UI-ready formats with quality assessment
4. **Presenters**: Manage application state using `@Observable` macro
5. **Views**: SwiftUI interfaces with environment-based dependency injection

#### Key Design Patterns
- **Subscription System**: package-owned `ProcessCoordinator`, constructed by `AppProcess.shared`, supplies location/readiness to `DoomKitProcess.ProcessManager<Context>`
- **Observation**: typed per-consumer AsyncStream state for location/connectivity; `ProcessRefreshable` is a public package presenter contract
- **Transformer Pattern**: Clean separation of data processing from presentation logic
- **Quality Assessment**: Built-in measurement validation with `.good`, `.uncertain`, `.bad`, `.unknown` states
- **Mathematical Analysis**: Moving averages, exponential smoothing, and ARIMA forecasting
- **Unit Safety**: Custom `Dimension` subclasses with `@unchecked Sendable` conformance
- **Concurrent Processing**: All API calls and data transformations use structured concurrency

## Technology Stack

### Swift & SwiftUI
- **Swift Language Mode**: Swift 5 (`SWIFT_VERSION = 5.0`), with async/await and structured concurrency
- **SwiftUI**: Native UI framework for the macOS 15.0+ app target
- **WeatherKit**: Apple's native weather data framework for real-time conditions
- **@Observable**: Primary state management macro for reactive UI updates
- **async/await**: Modern concurrency patterns throughout all controllers and services
- **Sendable**: Proper concurrency safety with `@unchecked Sendable` for custom unit types

### Data Sources & APIs
- **WeatherKit**: Apple's weather service for real-time weather data
- **BfS (Bundesamt für Strahlenschutz)**: Radiation monitoring
- **UBA (Umweltbundesamt)**: Air quality data (PM10, PM2.5, O3, NO2)
- **Pegelonline**: Federal waterway and shipping administration; nearest-waterway matching uses a bundled GDWS VerkNet-BWaStr dataset, not Overpass/OSM
- **NINA API**: National warning system for civil protection
- **Corona-Zahlen.org**: COVID-19 statistics; district resolution uses BKG's VG250 WFS (`vg250:vg250_krs`), not Overpass/OSM
- **OpenStreetMap**: Points of interest via Overpass API (background POI discovery only)
- **DAWUM**: Political polling and survey data with categorical gradient visualization

## Code Style Guidelines

### Swift Conventions
- Use modern Swift syntax compatible with Swift 5 language mode, including structured concurrency
- Prefer `async/await` over completion handlers throughout the application
- Use `@Observable` for state management in all presenters
- Implement `@unchecked Sendable` for custom `Dimension` unit types
- Follow Swift API Design Guidelines with clear, descriptive naming
- Use meaningful, descriptive variable and function names
- Ensure thread safety with proper `Sendable` conformance where needed

### SwiftUI Best Practices
- Environment-based dependency injection for presenters
- Prefer `@State` and `@Environment` for data flow
- Use macOS APIs; retain platform conditionals where needed in shared code
- Implement proper view hierarchies and modifiers

### Architecture Patterns
- Controllers should handle data orchestration only
- Services should be stateless and handle pure HTTP communication
- Transformers should process data without side effects
- Presenters should manage state and provide data to views
- Views should be passive and reactive to state changes

## Data Processing

### Quality Assessment System
- **Four-Tier Quality**: `.good`, `.uncertain`, `.bad`, `.unknown` quality states
- **Temporal Validation**: Data consistency checks across time series
- **Confidence Scoring**: Automatic quality assessment based on data freshness and source reliability
- **Graceful Degradation**: Handle missing or invalid data with appropriate fallbacks
- **Custom Data Fields**: Support for additional metadata in `ProcessValue` structures

### Mathematical Analysis Capabilities
- **Moving Averages**: Simple and exponential moving averages for trend smoothing
- **ARIMA Forecasting**: Autoregressive integrated moving average predictions
- **Interpolation**: Gap filling for missing data points in time series
- **Nowcasting**: Real-time current value estimation from recent trends
- **Statistical Processing**: Advanced statistical analysis for data validation

### Measurement Units
- Use Foundation's `Measurement` and `Unit` types
- Support automatic unit conversion and standardization
- Display units with proper formatting and localization

### Mathematical Symbols
- Use Unicode mathematical symbols for data presentation:
  - Ω (Omega) for COVID-19 data
  - Γ (Gamma) for radiation data
  - ρμ (Rho Mu) for particle data
  - τ (Tau) for temperature
  - η (Eta) for water levels
  - ν (Nu) for survey data

### Data Visualization Patterns
- **Gradient Color Coding**: Sophisticated gradient systems for categorical data representation
- **Political Data Visualization**: Custom gradient mappings for survey data with semantic color associations
- **Environmental Gradients**: Color-coded severity scales for air quality, radiation, and water levels
- **Temporal Visualization**: Trend indicators with mathematical forecasting display

## Network & Error Handling

### HTTP Communication Architecture
- **URLSession Extensions**: Custom `dataWithRetry` methods for resilient networking
- **Structured Concurrency**: All network calls use async/await patterns
- **Automatic Retries**: Exponential backoff retry mechanisms built into URLSession extension
- **Timeout Management**: Configurable timeouts for different data source types
- **Connection Monitoring**: Network availability detection via NetworkManager actor
- **HTTPS Enforcement**: All external API communications use secure protocols

### Error Management
- Comprehensive error handling throughout the data pipeline
- Graceful degradation when APIs are unavailable
- User-friendly error messages and recovery options
- Trace utility for structured logging and debugging

## Platform-Specific Considerations

### macOS Menu Bar Application
- Status item shows current temperature; clicking it opens a menu (Open Dashboard, Settings, About, Quit), not the dashboard itself
- Dashboard is a real `Window` scene (`AppDelegate.dashboardWindowID`), opened/focused/closed via `AppDelegate.showDashboard()`/`hideDashboard()`/`toggleDashboard()`
- User-configurable system-wide hotkey (default Cmd+Ctrl+D) toggles the dashboard window, built on the `KeyboardShortcuts` package; recorder lives in Settings > General
- Settings window for configuration; "About..." opens it on the About tab via `AppDelegate.showSettings(tab:)` and `SettingsSelection`
- Dark mode optimization
- Native macOS appearance integration
- App is `LSUIElement`; menu item key equivalents (Settings ⌘,, Quit ⌘Q) only fire while the status menu is open, the global hotkey is the only system-wide binding
- Dashboard window is freely resizable (minimum 700x500, no maximum) via `ContentView`'s `.frame(minWidth:minHeight:)` and `.windowResizability(.contentMinSize)`
- Content is tab-based (`DashboardTab`), not scrolling disclosure panels: a toolbar strip (`ToolbarTabButton`, shared with `SettingsView`) switches between Home (full-size map), Weather, COVID-19, Sensors, and Polls
- The Sensors tab (`SensorsView`) stacks Level, Radiation, and Particles in one scrolling view, each keeping its own placemark/last-update header since these sensors can each sit at a different location; `SettingsTab` keeps them as three separate tabs with independent toggles and refresh intervals — the two are unrelated
- Charts are bare, fixed 167-point cells in a two-column `LazyVGrid` with no card or container chrome; do not add fills, borders, or rounded corners, and do not make chart height depend on window size
- The Home map gets the same outer `.padding()` as the category tabs and nothing else

## Testing Guidelines

### Unit Testing
- Test core business logic in controllers and transformers
- Mock external API dependencies
- Validate data processing and quality assessment logic
- Test measurement calculations and unit conversions

### Integration Testing
- Validate API communication and response parsing
- Test data pipeline from service to presenter
- Verify error handling and retry mechanisms

### UI Testing
- Test SwiftUI interface behavior and user interactions
- Validate macOS menu bar and settings window behavior
- Test accessibility and localization features

## Security & Privacy

### Data Protection
- Process GPS data locally, never transmit location
- Implement secure HTTPS communication
- Minimal local data caching with automatic cleanup
- Respect user privacy settings and data source toggles

### API Security
- Use secure endpoints for government data sources
- Implement proper authentication where required
- Handle API rate limiting and usage quotas

## Performance Optimization

### Memory Management
- Efficient data processing and transformation
- Proper cleanup of network resources
- Memory-conscious caching strategies

### Data Updates & Subscription System
- **ProcessCoordinator**: package-owned stream observation, app-injected Berlin fallback, first-measurement refresh, and bounded startup readiness
- **DoomKitProcess.ProcessManager**: main-actor UUID registrations, cancellable 60-second scheduling, and cancel/restart refresh generations
- **ProcessRefreshable Protocol**: Standardized interface for reactive data consumers
- **ProcessManager registrations**: UUID subscription management with configurable intervals
- **Intelligent Refresh**: Different intervals based on data type and update frequency:
  - Weather: Real-time updates with 5-minute fallback
  - Air Quality: 30-minute intervals with immediate alerts
  - Water Levels: 15-minute intervals for hydrological data
  - COVID-19: 6-hour intervals for epidemiological data
  - Radiation: Continuous real-time monitoring
  - Civil Protection: 15-minute polling of the NINA list feeds; there is no push
  - Political Surveys: Daily updates with trend analysis

### Implemented Utilities
- **ARIMA**: Autoregressive integrated moving average forecasting
- **MovingAverage**: Simple and exponential moving average calculations
- **HaversineDistance**: Geographic distance calculations
- **PointInPolygon**: Spatial geometry operations
- **PolygonProximityCalculator**: Distance to polygon calculations
- **OSMUtilities**: OpenStreetMap data processing helpers
- **MathematicalSymbols**: Unicode symbols for data visualization
- **Trace**: Structured logging utility for debugging and monitoring

## Development Workflow

### XcodeGen Project Management

- Treat `project.yml` as the source of truth; edit it instead of generated project files
- Require XcodeGen 2.46.0+; install with `brew install xcodegen`
- Run `xcodegen generate` after cloning and before builds, including after spec changes
- Use `./macos/build.sh` for a signed Debug build and `./macos/build.sh --release` for Release; the script regenerates the project and fixes output paths under `.build/`
- For archives, override Xcode build-location preferences instead of passing `SYMROOT` or `OBJROOT`; Xcode must derive its own archive subdirectories or finalization fails with a missing `BuildProductsPath`.
- `./macos/build.sh --clean` only removes root `.build/`, `Build/`, and legacy `build/` outputs, including archives and exports; combine with `--release` or `--notarize` to clean before building
- `./macos/build.sh --notarize` archives Release, exports with `macos/exportOptions.plist`, submits to Apple, staples an accepted result, validates, and creates a distribution ZIP
- Notarization uses the `DashboardOfDoom-Notarize` Keychain profile, overridable with `NOTARIZE_PROFILE`
- For unsigned compilation checks, use the manual `xcodebuild` command in README.md with `CODE_SIGNING_ALLOWED=NO`
- Validate script changes with `bash -n macos/build.sh`, `shellcheck macos/build.sh`, and `python3 -m unittest discover -s macos/BuildTests -v` and `python3 -m unittest discover -s ios/BuildTests -v`; the Python tests mock builds and notarization
- Keep the existing signing configuration, app identity, and WeatherKit entitlement unless explicitly changing them; configure signing in the spec, including SDK-specific overrides
- Generated project files are ignored, except the tracked package lockfile at `DashboardOfDoom.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`
- Preserve locked dependency revisions during unrelated changes
- Local package tests: run `swift test --package-path shared/doom-kit-location`, then `doom-kit-network`, then `doom-kit-process`, `doom-kit-tools`, and `doom-kit-services`; repeat Process, Tools, and Services with `-c release`; tests use injected dependencies and no live network
- `PointOfInterestTests` is an unhosted macOS Swift Testing target. Run `xcodegen generate`, then `xcodebuild -project DashboardOfDoom.xcodeproj -scheme PointOfInterestTests -destination 'platform=macOS' -derivedDataPath .build/poi-tests test`. Its filtered synchronized source folder excludes the app entry point; tests inject fetching, location, time, and preferences.
- POIs use a single Canvas with one Core Graphics image pass beneath environmental labels, never the collision solver. Repeated SwiftUI symbol/image draws crashed the GPU encoder in the 10,000-point stress fixture; preserve the batched Core Graphics path. Preserve stable OSM identities, category toggles, all-point rendering, Apple POIs, and region fitting. Project only after geometry/camera changes, using the deferred MapReader registration safeguard.
- The app delegate owns the POI presenter lifecycle. Keep the 6,666.67-metre radius, one-hour cache within 1 km, minute expiry checks, five-minute failure cooldown, and two-request concurrency limit across cancelled generations. Never start or stop shared location tracking from the POI presenter.
- `PointOfInterestPresenter` publishes two lists: `points` is what the map shows, filtered by the master switch and the category switches; `allPoints` is every cached point near the user. iOS constructs it with `fetchesWhenHidden: true`, so all five categories keep loading while switched off and the settings switches only change the map; the nearest places row reads `allPoints`. macOS keeps the default, where a switched-off category is not fetched.

- COVID, water levels, radiation, particles, hazards, and polls own preference-observed conditional subscriptions; disabled sources retain values but cancel and remove refresh work. Weather and forecasts always refresh regardless of display visibility.

### iOS Lifecycle and Validation

- Use `feature/ios-modernization` for this migration. Preserve the imported iOS history; do not restore its obsolete standalone Xcode project or duplicate services.
- iOS 6.5.0 (180) uses the user-confirmed bundle `com.panjas.dashboard-of-doom`, automatic signing team `8J2G689FCZ`, WeatherKit entitlement, and background location plist mode. macOS is 6.5.4 (152) with unchanged identity/signing.
- `IOSAppDelegate` owns one runtime and all presenters, including `HazardPresenter`. Its lifecycle starts once and refreshes once after background return, without stopping background location. Never start location from a presenter or view; presenters receive their location only through `refreshData(location:)` from the coordinator.
- The iOS home screen below the map is, in order: `ForecastStripView` (next 24 hours from `ForecastPresenter`, joined by timestamp), `CurrentConditionsView` (feels-like, humidity, wind with gusts in km/h, pressure in hPa from `WeatherPresenter.current`), `NearestPlacesView` (the closest place of each of the five categories, read from `PointOfInterestPresenter.allPoints`; it draws its own leading divider and renders nothing until something is loaded), and `HazardCardView` behind the `showHazards` switch. Level and radiation charts live on the Environment tab only. `LazyVGrid` with adaptive columns packs as many minimum-width columns as fit, so on iPad cells are narrow; the conditions tiles stack the value under the title for that reason.
- Hazards (NINA) are live on iOS and unused on macOS; the old `HazardView` files on both platforms are deleted. `HazardService` uses the official host `warnung.bund.de/api31` (the `nina.api.proxy.bund.dev` proxy no longer resolves) and four list feeds: mowas, dwd, katwarn, biwapp. `HazardController` fetches all list feeds concurrently, then each alert's geojson (a multi-feature collection, one polygon per district, read through `GeoJSON.polygons(fromFeatureCollection:)`), keeps alerts that contain the user or lie within 50 km for DWD and 25 km for the civil feeds, and only then fetches CAP details for the survivors, choosing the German `info` entry that is not Leichte Sprache. Concurrency is capped at 4 regions and 2 details in flight. Relevance is by expiry, not a sent window (a MoWaS notice can stay active for weeks); a 30-day sent cap is only a stale-feed guard. Reverse geocoding runs only for alerts without an `areaDesc`. A failed list or detail fetch fails the refresh: the card then shows `.failed` with the last list, never a false all-clear. `HazardPresenter` is a small `ProcessRefreshable`, not a `ProcessPresenter`, with a 5-minute failure cooldown within 1 km like the POI presenter, a 15-minute interval under `hazardRefreshInterval`, and a `showHazards` toggle in the Home settings. Tapping a warning row opens `Hazard.sourceURL` in the system browser: the alert's page on NINA, `warnung.bund.de/meldungen/{list id}/{slug}/`, the form the NINA web app links to itself. The `/meldung/{id}/` redirect route shows "Meldung nicht mehr vorhanden" even for a live alert, and the CAP `web` field is a generic DWD page or empty, so neither is used.
- `LocationConfiguration.continuousBackground` is iOS-only: best accuracy, Always request, background updates enabled, automatic pauses disabled, background indicator enabled. Default macOS behavior remains kilometer accuracy and When In Use.
- Preserve the strictly-greater-than-100-metre movement filter. The iOS coordinator uses everyMovement; default macOS uses firstMeasurement. Keep immediate fallback startup and cancellation checks.
- iOS keeps showWater, enableElectionPolls default false, and showElectionPolls default true. Only enableElectionPolls controls poll fetching. Other conditional sources use their switches; weather and forecasts always fetch. Preserve successful values while disabled.
- Use `./ios/build.sh` for unsigned simulator Debug, `--release` for Release, `--device` for signed device compilation, and `--simulator UUID --run` to launch at HKW. The script never cleans or uploads.
- All simulator testing uses HKW, 52.51889, 13.36528. Start simulated movement there. Disable parallel test clones when testing location using `-parallel-testing-enabled NO`.
- `iOSTests` is an unhosted Swift Testing target; `iOSUITests` uses XCTest for navigation, gestures, orientations, appearances, Dynamic Type, and 2,000/10,000-POI screenshots. Debug-only `--ui-fixture` data never starts network/location work. Release omits this fixture.
- Package simulator tests run from each package directory using its package-name scheme. Release tests need `ENABLE_TESTABILITY=YES` for @testable imports; keep optimization enabled. Isolate derived data, SYMROOT, and OBJROOT for concurrent builds.
- Simulator tests do not establish real background delivery or WeatherKit authorization. Record physical-device results separately in ios/MIGRATION.md.
- iOS accents are orange, cyan and blue only (`ColorPresenter.accents`, default cyan, stored under `selectedColor`), and they apply in dark mode only. Light mode uses the system accent: `ColorPresenter.tint(for:)` returns nil, and the `AccentColor` asset supplies systemBlue (its dark entry is systemCyan). iOS has no user-set system accent, and `.tint(nil)` falls back to that asset, not to SwiftUI's built-in blue, so keep the asset at systemBlue. The Accent Color section in Settings is hidden in light mode, and the stored choice is kept for the next dark session. Retired names migrate on launch and the stored value is rewritten. Never index one accent array with a position from another; that lookup is what a shrunken palette would have crashed on.
- Every iOS settings section is a headline outside a `Color(.systemGray6)` card with `cornerRadius(10)`, content in a `VStack(spacing: 12)`, and each footnote wrapped in `HStack { Text.font(.footnote).foregroundColor(.gray); Spacer() }`. The `Spacer()` is what makes a card full width; without it the card shrinks to its text, which is what made `LocationSettingsView` look inset. `PointOfInterestSettingsView` draws only its card, so the iOS `SettingsView` wraps it to add the "Points of Interest" headline; every section now has one.
- Settings footnotes say what a switch does to both the map and the data. The COVID, water, radiation, particle and warnings switches in the Home section also cancel that source's refresh through `ConditionalSubscription`, so turning one off leaves its tab on stale values; weather and the `showElectionPolls` switch only hide the map label.
- iOS text labels that used the accent (the location row and the chart title in each sensor view) use `.accentLabel()` from `ios/DashboardOfDoom/Views/AccentLabel.swift`: the accent in dark mode, the system label color (`Color.primary`) in light mode. Icons, chart fills and tab icons are not labels and keep the accent in both modes. The vertical marker and dot in each chart (both the current value and the drag-selected value) use `ColorScheme.markerColor`, which is the secondary system label color in light mode (the same color as the default axis labels, so keep the charts on default axis styling) and the accent in dark mode; marks are not views, so they cannot use `accentLabel()` and read `@Environment(\.colorScheme)` instead. Use the modifier for new accent-colored text instead of `.foregroundColor(.accentColor)`.
- Apply the iOS `.tint()` on the `NavigationStack` in `ContentView`. Applied lower, on the `ScrollView` chain, it did not reach the charts or the bottom bar. To test accents in the simulator, launch with `-selectedColor <name>`; `simctl spawn defaults write` targets a different plist than the app reads.
- iOS light mode shows the title as bold text and dark mode shows `dashboard-of-doom-logo`, which is dark red and unreadable on white. Both branches give the row 34 points at standard text sizes so the content below does not shift; the text branch is a minimum height and can grow at accessibility sizes.
- The iOS bottom toolbar capsule is given an explicit width (`toolbarWidth` in `ContentView`): the measured container width minus horizontal safe area, minus a 21-point side margin, capped at 600 points. iOS 26 sizes the capsule to its content, so `Spacer()` and `.frame(maxWidth: .infinity)` inside the toolbar item do not widen it. The capsule draws about 5 points outside its content, so 21 leaves a 16-point gap to the screen edge; the width is nil until the first measurement.

### Map Annotation Layout

- `MapView` creates one snapshot ordered weather, COVID, particles, water, radiation, surveys; category IDs survive measurement refreshes.
- `CollisionMapView` keeps native dots at geographic coordinates and projects with `MapReader` from camera callbacks and a geometry-keyed cancellable view task, never during body rendering.
- Labels and category-colored connectors use `MapAnnotationOverlay`; connector drawing clips around every native dot and is hidden from accessibility.
- Environmental label backgrounds use full opacity while pins will be drawn, meaning the POI master switch is on and at least one category is selected (`PointOfInterestPresenter.showsAnyPlaces`); otherwise they use 0.5 opacity. Read it from the switches, never from the loaded `points`, so loading and empty results do not flicker.
- The iOS master switch is labelled "Show on map" and only clears the map; macOS keeps "Show points of interest", where it still stops fetching. Both labels live in `PointOfInterestSettingsView.masterLabel`, beside the platform-split `explainer`.
- Launch arguments cannot drive `showPlaces` or the per-category keys: `PointOfInterestPresenter` reads them with `object(forKey:) as? Bool ?? true` to tell unset from false, and argument-domain values arrive as strings, so the cast fails and both default to on. `@AppStorage` switches such as `showHazards` use `bool(forKey:)` and do respond. Drive the POI switches through the UI, not `simctl launch`.
- `MapAnnotationLabel` shares its 131 × 33-point outer dimensions with `DoomKitTools.AnnotationLayout`; preserve colors, icons, text, and padding.
- After geometry changes, defer projection until MapReader registers its map; retry at most eight 16 ms passes, publish once, and cancel on replacement/disappearance.
- Cache by projected geometry, visibility, and size; text-only updates reuse placements. Publish geometry and placement together without animation.
- The pure Tools solver uses an 8-point inset, 6-point label separation, 4-point clearance for unrelated markers (attached labels meet their source dot), and a deterministic beam capped at 256 retained arrangements.
- Try previous relative placements and eight anchors, then 40–160-point outward offsets and a bounded viewport grid. After collision/clipping, minimize connector count and prefer direct above-right attachment; retain previous placement only as a final tie-breaker.
- Score clipping from nonnegative outside strips, never by subtracting nearly equal areas; ignore edge noise at or below 0.0000001 point before scoring, and keep the comparator strictly ordered.
- Preserve all labels in undersized viewports using the best bounded-search result; skip unprojectable coordinates until valid. Never change region fitting to accommodate labels.
- Keep the Weather dot when its label is disabled, preserve selectors and settings behavior, and retain platform label dimensions: macOS 131 × 33 points, iOS 132 × 36 points. iOS caps visual map-label Dynamic Type to fit fixed bounds; full values remain accessible.

### Local Package Boundaries

- `doom-kit-location` / `DoomKitLocation`: location values, provider-independent state streams and movement filtering, separate async geocoding
- `doom-kit-network` / `DoomKitNetwork`: network actor, typed state streams, injectable monitoring/transport/timing, shared request execution
- `doom-kit-process` / `DoomKitProcess`: process models, custom units, geographic helpers, open observable presenter and transformer bases, coordinator, generic main-actor scheduler and injected clock; local dependencies on DoomKitLocation and DoomKitNetwork
- `doom-kit-tools` / `DoomKitTools`: generic Measurement smoothing, ARIMA, polygon/bounding-box helpers, symbols, and mutex-protected synchronous Sendable Trace; depends only on DoomKitLocation
- `doom-kit-services` / `DoomKitServices`: seven public static API services with trailing injectable NetworkManager defaults; depends on Location, Network, and Tools
- Keep smoothing independent of ProcessValue; app callers rebuild values in order with original metadata, timestamps, quality, units, and new UUIDs
- Preserve original unit coefficients and base units, numeric algorithms, service URL/date behavior, and failure-to-nil cancellation contract during extraction work
- All packages use Swift tools 6.2 and Swift 6 language mode; keep the app in Swift 5 mode
- Packages declare macOS 15 and iOS 26; both app targets integrate them. See ios/MIGRATION.md for simulator and device validation limits.
- Each state consumer owns a separate latest-value stream and explicitly cancelled task; stop finishes all streams and restart requires new subscriptions
- Location initialization does not request permission or track; the private Core Location provider starts explicitly with kilometer accuracy
- Native `CLLocationUpdate.liveUpdates()` is a planned provider replacement; validate accuracy, authorization, delivery, cancellation, and background behavior separately
- Refresh closures must check cancellation after awaits and immediately before synchronous publication; use per-refresh transformer state
- Keep concrete presenters, Berlin fallback configuration, settings, and the starting `AppProcess.shared` factory in the app; shared process models and coordinator lifecycle policy belong to DoomKitProcess
- Preserve the unrelated theme notification observer

- Overpass requests share one cancellation-aware transport queue in DoomKitNetwork; never rotate endpoints on HTTP 429. Availability fallback uses overpass.private.coffee. As of the waterway change below, Overpass is used only by the background POI system — no controller depends on it for sensor resolution anymore.
- Water-level gauge resolution (`LevelController`) no longer queries OSM/Overpass at all. It uses a bundled, offline-converted federal waterway network (GDWS VerkNet-BWaStr, `Shared/Sources/Resources/BundeswasserstrassenNetz.json.zlib`, zlib-compressed JSON keyed by PEGELONLINE `waterBodyName`) with a hand-curated natural/artificial flag per waterway. For the default (non-`nearestLevelSensor`) path, it finds the nearest point among all `isNatural == true` polylines within `waterwaySearchRadius` (10km) using `PolygonProximityCalculator.nearestPointOnPolyline`, then matches that waterway's name exactly against PEGELONLINE stations. Missing/unmatched waterway data falls back to the nearest official gauge, same as before. The `nearestLevelSensor` toggle still bypasses this entirely (pure nearest gauge).
- The natural/artificial flag is a name-based heuristic (a waterway is artificial if its PEGELONLINE name contains "KANAL"), audited once against WasserBLIcK/WRRL's own `ARTIFICIAL` field (WKSB_3BWP, 3. Bewirtschaftungsplan, May 2025 — the EU Water Framework Directive classification dataset flagged as inaccessible in the earlier COVID-fix research pass; it became reachable once the user downloaded the current export directly). WRRL cannot replace the heuristic wholesale: its names are ecological water bodies, not PEGELONLINE's shipping-route names (only 47 of 103 join exactly), and its flag is origin-based rather than behavioural, so a canal dug along an old river course reads as "not artificial" (e.g. Elbe-Lübeck-Kanal, Oranienburger Kanal) — wrong for our purpose, which cares whether the level is naturally variable or lock-controlled. One real correction came out of the audit: `MÜRITZ-ELDE-WASSERSTRASSE` has no "KANAL" in its name but is a heavily locked system: WRRL's constituent water bodies agree it's artificial 5-to-1, so it's now hard-overridden in the curation script (`ARTIFICIAL_OVERRIDES` in the offline `build_waterways.py` pipeline, not shipped in the app). Every other disagreement between the heuristic and WRRL was a KANAL-named waterway where WRRL's origin-based flag was the wrong signal, so the heuristic stands as-is for those. Do not re-attempt a full WRRL-based replacement without new evidence — this was investigated concretely, not assumed.
- COVID district resolution queries BKG's VG250 WFS (`vg250:vg250_krs`) directly, not Overpass; it resolves the containing Kreis by real point-in-polygon containment (falling back to nearest polygon edge), reusing `isPointInPolygon`/`PolygonProximityCalculator` from `DoomKitProcess`/`DoomKitTools`. No fallback to Overpass if BKG is unreachable — same graceful no-data-this-cycle behavior as any other source failure.
- Berlin is a special case: RKI/corona-zahlen.org reports COVID data per Bezirk (12 boroughs, ids 11001-11012), not city-wide, because Berlin's Bezirke are not independent Gemeinden and never appear in BKG's VG250 layers. When BKG resolves a location to Berlin's whole-city Kreis ("11000", not itself a valid RKI id), `CovidController` falls through to a bundled Bezirk boundary dataset (`Shared/Sources/Resources/BerlinBezirke.geojson`, CC-BY, Amt für Statistik Berlin-Brandenburg) and re-resolves by the same point-in-polygon logic. Verified this is the only such nationwide exception — Hamburg and every other city currently report as a single district like the rest of Germany.
- The COVID sensor's displayed location (map pin, reverse-geocoded placemark) is a district's polygon centroid, not the user's location or a real physical sensor site — there is none, since the underlying data is district-wide. `CovidController.centroid(of:)` computes this as an area-weighted centroid (shoelace formula per ring, combined across a MultiPolygon's rings by ring area), used identically for BKG's nationwide Kreis polygons and Berlin's bundled Bezirk polygons. It deliberately does not average the polygon's boundary vertices directly — that's biased toward wherever a boundary happens to be traced with more points (a winding riverbank, a jagged administrative edge) and can land far from the district's actual visual center, confirmed for Berlin Mitte: it moved the resolved address from Seydlitzstraße to Heidestraße, both still within the correct postal district.

### Git Conventions

**Branch Strategy:**
- Main development branch: `develop`
- Feature branches: `feature/<description>`
- Fix branches: `fix/<description>`
- Create pull requests for review before merging to `develop`

**Commit Message Format (Conventional Commits):**

Follow these rules strictly to prevent terminal crashes and maintain clean git history:

```text
<type>(<scope>): <subject>

<body>

<footer>
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code formatting (no functional changes)
- `refactor`: Code restructuring (no functional changes)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks
- `build`: Build system changes
- `ci`: CI/CD configuration changes
- `perf`: Performance improvements

**Character Limits (CRITICAL):**
- Subject line: Maximum 50 characters (strict limit)
- Body lines: Wrap at 72 characters per line
- Total message: Keep under 500 characters
- Always add blank line between subject and body

**Subject Line Rules:**
- Scope is optional but recommended: `feat(api):`, `fix(build):`, `docs(readme):`
- Use imperative mood: "add feature" not "added feature"
- No period at end of subject line
- Keep concise and descriptive

**Body Guidelines:**
- Explain what and why, not how
- Use bullet points (`-`) for multiple items
- Start bullet items with lowercase
- Keep concise and focused

**Special Character Safety:**
- Avoid nested quotes or complex quoting
- Avoid shell characters: `$`, `` ` ``, `!`, `\`, `|`, `&`, `;`
- Use simple punctuation only
- No emoji or unicode characters

**Best Practices:**
- Break up large commits into smaller, focused commits
- One concern per commit
- Test before committing
- Reference issues with `#123` format in footer if applicable

**Good Examples:**

```text
feat(settings): add sensor selection toggle

- allow users to select the nearest sensor
- refresh measurements when the setting changes
```

```text
fix(refresh): schedule timer on main run loop
```

**Bad Examples:**

```text
feat(settings): add comprehensive sensor selection controls with immediate data refresh for all environmental monitoring services
```
*Problem: Subject line exceeds 50 characters*

```text
fix: update `ProcessManager` with "nested 'quotes'" & $special chars!
```
*Problem: Contains special shell characters and complex quoting*


### Code Organization
- **Platform Roots**: Keep platform navigation, settings, app lifecycle, charts, and assets separate; share data orchestration and map/POI code
- **Shared Architecture Patterns**: Business logic patterns similar to the iOS repository
- **Platform-Specific Code**: macOS-specific UI and menu bar functionality
- **Custom Unit Types**: Implement `@unchecked Sendable` conformance for measurement units
- **Consistent Naming**: Use clear, descriptive file naming
- **Folder Hierarchy**: Keep Controllers/, Presenters/, and Transformers/ in shared/Sources/; place services under DoomKitServices and utilities under DoomKitTools.

## Common Tasks & Patterns

### Adding New Data Sources
1. **Create Service Class**: Implement async API communication methods
2. **Define Data Models**: Create parsing structures with proper error handling
3. **Implement Controller**: Add data orchestration with quality assessment
4. **Create Transformer**: Build UI-ready data processing with mathematical analysis
5. **Develop Presenter**: Implement `@Observable` presenter with `ProcessRefreshable` conformance
6. **Update Views**: Add environment injection and platform-specific UI code
7. **Configure Subscription**: Register presenters with `AppProcess.shared` using appropriate refresh intervals
8. **Add Custom Units**: Implement `Dimension` subclasses with `@unchecked Sendable` if needed

### Implementing New Views
1. **Environment Injection**: Use `@Environment` for presenter dependencies
2. **Platform Conditionals**: Implement platform-specific layouts with `#if os()` directives
3. **State Management**: Follow `@Observable` patterns for reactive UI updates
4. **Accessibility**: Add proper accessibility labels and navigation support
5. **Localization**: Implement string localization for German market focus
6. **Error States**: Handle loading, error, and empty states gracefully

### Data Processing Workflow
1. **Service Layer**: Fetch raw data using async URLSession methods with retry logic
2. **Controller Layer**: Parse and validate data with comprehensive error handling
3. **Transformer Layer**: Process data with quality scoring and mathematical analysis
4. **Presenter Layer**: Publish processed data through `@Observable` properties
5. **View Layer**: Update UI reactively through environment injection and state binding
6. **Subscription Management**: Coordinate updates through `ProcessCoordinator` with location awareness

Remember: This application focuses specifically on German environmental data and should maintain its regional focus while providing comprehensive, reliable monitoring capabilities.

## Current Development Notes

### Technology Status (Updated September 5, 2026)
- **Swift Language Mode**: Swift 5 (`SWIFT_VERSION = 5.0`); this setting does not identify the compiler version
- **Deployment Target**: macOS 15.0+ (app target overrides the project-level macOS 15.2 setting); iOS app target requires iOS 26.0+
- **Architecture Maturity**: Production-ready implementation with full feature set
- **Code Quality**: Comprehensive error handling, quality assessment, and mathematical analysis
- **Concurrency**: Full async/await adoption throughout the application stack
- **State Management**: Complete `@Observable` implementation for reactive programming
- **Network Resilience**: Advanced retry mechanisms via URLSession extensions with reachability monitoring

### Maintenance Guidelines
- Follow macOS Human Interface Guidelines for menu bar applications
- Maintain consistent API patterns across all service implementations
- Ensure proper `Sendable` conformance for new custom types
- Follow the established subscription pattern for new data sources
- Preserve the mathematical analysis capabilities when extending functionality
- Test menu bar functionality and system integration when implementing new features

---

## Recent Updates & Decisions

See [UPDATES.md](UPDATES.md) for the project decisions and change history.
