# Agent Instructions for Dashboard of Doom (macOS and iOS)

*Last updated: September 26, 2026, 16:10 CEST (notifications with warning values per sensor family)*

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
- **Shared Business Logic**: Both apps compile `shared/Sources/` and use the same six local DoomKit packages

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
- **Tankerkoenig**: German filling station prices, redistributing the Bundeskartellamt's MTS-K data under CC BY 4.0. Needs a free API key. Crediting tankerkoenig.de and MTS-K is a licence condition, so the credit line under the list is not optional.
- **Energy prices**: Brent and WTI crude from the `datasets/oil-prices` GitHub mirror of the US EIA daily spot series (plain `Date,Price` CSV, public domain, keyless; the EIA API itself needs a key), and the EU LNG spot price from ACER, the EU energy regulator (`aegis.acer.europa.eu/terminal/price_assessments/historical_data`, quoted CSV in ISO 8859-1, newest first, weekdays). No free API exists for TTF or JKM; DBnomics' TTF dataset stopped in 2024 and the rest are paid or scrapes.

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
- **`customData` carries everything the standard interface does not.** A controller fulfils one contract, `ProcessController.refreshData(for:) -> [ProcessSensor]`, and a sensor models what every source has: name, location, placemark, measurements, timestamp, `sourceID`, `distance`. Anything else a source needs to hand the UI goes in `customData` on `ProcessSensor` or `ProcessValue` — never a typed field added to a shared model for one source, and never state parked on a presenter, a controller or a DoomKit type. That is what keeps the apps and the packages stateless: the data travels with the reading instead of living somewhere. Read it back with `as?` and a fallback, so a source that does not set a key simply does without it (`customData?["icon"] as? String ?? "questionmark.circle"`). Current keys: `icon` (every source), `waterway` (level), `marks` (level), `polygons` (COVID)
- One accepted asymmetry: `ProcessSelector` in `DoomKitProcess` enumerates all eight sources and embeds PEGELONLINE's codes, UBA's component ids and DAWUM's party ids. Selectors key `measurements` and route charts, so `customData` cannot absorb them without losing type safety. It is known, not an oversight, and not a precedent for putting other source knowledge in a package
- Presenters should manage state and provide data to views
- Views should be passive and reactive to state changes

## Data Processing

### Quality Assessment System
- **Four-Tier Quality**: `.good`, `.uncertain`, `.bad`, `.unknown` quality states
- **Temporal Validation**: Data consistency checks across time series
- **Confidence Scoring**: Automatic quality assessment based on data freshness and source reliability
- **Graceful Degradation**: Handle missing or invalid data with appropriate fallbacks
- **Custom Data Fields**: `customData` (`[String: Any]?`) on both `ProcessSensor` and `ProcessValue`, the channel for anything outside the standard interface; see the rule under Architecture Patterns

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
- Content is tab-based (`DashboardTab`), not scrolling disclosure panels: a toolbar strip (`ToolbarTabButton`, shared with `SettingsView`) switches between Home (full-size map), Weather, Warnings, COVID-19, Sensors, Energy, and Polls
- The Warnings tab (`WarningsView`, not `HazardView`, a name that was deleted) lists the NINA warnings with the rows of the iOS home card: severity bar and badge, headline, area, the full instruction or description (the tab has room the card does not, so it is not cut to three lines), and sent and expiry dates. Clicking a row opens `Hazard.sourceURL` through `openURL`. `HazardPresenter` stays in `.loading` for good while `showHazards` is off, so the view checks the switch first and says warnings are off rather than spinning forever. A failed refresh keeps the last list and adds a line, never a false all-clear, as on iOS
- The Energy tab (`EnergyView`, `EnergyChartView`) is the iOS tab in macOS form: the shared `FuelMapView` on top, then the macOS header row and the two-column grid of 167-point charts. Each cell has its chart and, under it, the explainer from `EnergyExplainers.text`, the texts both platforms share. The chart takes the macOS `.chartOverlay` drag, since the iOS `chartInteractiveOverlay` is UIKit, and keeps the `AreaMark` anchored at the range's lower bound. `hazardPresenter`, `energyPresenter` and `fuelPresenter` are created in `AppDelegate` like the others, so hazards and energy prices fetch from launch, both switches defaulting to on as on iOS; fuel sends nothing until a key is stored
- The Sensors tab (`SensorsView`) stacks Level, Radiation, and Particles in one scrolling view, each keeping its own placemark/last-update header since these sensors can each sit at a different location; `SettingsTab` keeps them as three separate tabs with independent toggles and refresh intervals — the two are unrelated
- `SettingsTab` has twelve tabs, Warnings after Weather, Energy after Particles and Notify after Places, and the panel is `SettingsView.width`, 840 points, so their buttons fit one row; it was 660 for nine. Warnings holds `showHazards` and `hazardRefreshInterval`. Energy holds `enableEnergy`, which governs prices and fuel as on iOS, then the Tankerkoenig `SecretField` and the fuel, order and radius pickers, which appear once a key is stored, and both refresh intervals. As on iOS only the radius refetches, fuel and order re-rank what is loaded, and the key field refreshes the fuel subscription by hand because a keychain write is not a `UserDefaults` change. The About tab credits tankerkoenig.de and MTS-K
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
- Local package tests: run `swift test --package-path shared/doom-kit-location`, then `doom-kit-network`, then `doom-kit-process`, `doom-kit-tools`, `doom-kit-services`, and `doom-kit-secrets`; repeat Process, Tools, and Services with `-c release`; tests use injected dependencies and no live network
- `PointOfInterestTests` is an unhosted macOS Swift Testing target. Run `xcodegen generate`, then `xcodebuild -project DashboardOfDoom.xcodeproj -scheme PointOfInterestTests -destination 'platform=macOS' -derivedDataPath .build/poi-tests test`. Its filtered synchronized source folder excludes the app entry point; tests inject fetching, location, time, and preferences. That folder is an explicit include list in `project.yml`, so a new shared file used by an included source must be added there or the target stops compiling (`iOSTests` compiles all of `shared/Sources` and needs no entry).
- POIs use a single Canvas with one Core Graphics image pass beneath environmental labels, never the collision solver. Repeated SwiftUI symbol/image draws crashed the GPU encoder in the 10,000-point stress fixture; preserve the batched Core Graphics path. Preserve stable OSM identities, category toggles, all-point rendering, Apple POIs, and region fitting. Project only after geometry/camera changes, using the deferred MapReader registration safeguard.
- The app delegate owns the POI presenter lifecycle. Keep the 6,666.67-metre radius, one-hour cache within 1 km, minute expiry checks, five-minute failure cooldown, and two-request concurrency limit across cancelled generations. Never start or stop shared location tracking from the POI presenter.
- `PointOfInterestPresenter` publishes two lists: `points` is what the map shows, filtered by the master switch and the category switches; `allPoints` is every cached point near the user. iOS constructs it with `fetchesWhenHidden: true`, so all five categories keep loading while switched off and the settings switches only change the map; the nearest places row reads `allPoints`. macOS keeps the default, where a switched-off category is not fetched.

- COVID, water levels, radiation, particles, hazards, polls and energy prices own preference-observed conditional subscriptions; disabled sources retain values but cancel and remove refresh work. Weather and forecasts always refresh regardless of display visibility.

### iOS Lifecycle and Validation

- Use `feature/ios-modernization` for this migration. Preserve the imported iOS history; do not restore its obsolete standalone Xcode project or duplicate services.
- iOS 6.6.0 (181) uses the user-confirmed bundle `com.panjas.dashboard-of-doom`, automatic signing team `8J2G689FCZ`, WeatherKit entitlement, and background location plist mode. macOS is 6.7.0 (154) with unchanged identity/signing.
- `IOSAppDelegate` owns one runtime and all presenters, including `HazardPresenter`. Its lifecycle starts once and refreshes once after background return, without stopping background location. Never start location from a presenter or view; presenters receive their location only through `refreshData(location:)` from the coordinator.
- The iOS home screen below the map is, in order: `ForecastStripView` (next 24 hours from `ForecastPresenter`, joined by timestamp), `CurrentConditionsView` (feels-like, humidity, wind with gusts in km/h, pressure in hPa from `WeatherPresenter.current`), `NearestPlacesView` (the closest place of each of the five categories, read from `PointOfInterestPresenter.allPoints`; it draws its own leading divider and renders nothing until something is loaded), and `HazardCardView` behind the `showHazards` switch. Level and radiation charts live on the Environment tab only. `LazyVGrid` with adaptive columns packs as many minimum-width columns as fit, so on iPad cells are narrow; the conditions tiles stack the value under the title for that reason.
- Hazards (NINA) are live on both platforms: a card on the iOS home screen, the Warnings tab on macOS. The old `HazardView` files on both platforms are deleted. `HazardService` uses the official host `warnung.bund.de/api31` (the `nina.api.proxy.bund.dev` proxy no longer resolves) and four list feeds: mowas, dwd, katwarn, biwapp. `HazardController` fetches all list feeds concurrently, then each alert's geojson (a multi-feature collection, one polygon per district, read through `GeoJSON.polygons(fromFeatureCollection:)`), keeps alerts that contain the user or lie within 50 km for DWD and 25 km for the civil feeds, and only then fetches CAP details for the survivors, choosing the German `info` entry that is not Leichte Sprache. Concurrency is capped at 4 regions and 2 details in flight. Relevance is by expiry, not a sent window (a MoWaS notice can stay active for weeks); a 30-day sent cap is only a stale-feed guard. Reverse geocoding runs only for alerts without an `areaDesc`. A failed list or detail fetch fails the refresh: the card then shows `.failed` with the last list, never a false all-clear. `HazardPresenter` is a small `ProcessRefreshable`, not a `ProcessPresenter`, with a 5-minute failure cooldown within 1 km like the POI presenter, a 15-minute interval under `hazardRefreshInterval`, and a `showHazards` toggle in the Home settings. Tapping a warning row opens `Hazard.sourceURL` in the system browser: the alert's page on NINA, `warnung.bund.de/meldungen/{list id}/{slug}/`, the form the NINA web app links to itself. The `/meldung/{id}/` redirect route shows "Meldung nicht mehr vorhanden" even for a live alert, and the CAP `web` field is a generic DWD page or empty, so neither is used.
- The iOS Environment tab (`RadiationView` above `LevelView`) and Particles tab (`ParticleView`) show every reading of each source, nearest first, as its own section: `SensorHeaderView`, then one chart per available selector, with a `Divider` between sensors. The charts take a `ProcessReading` (`LevelChartView(selector:reading:)`), not the presenter, and the sections are keyed by `ProcessReading.id`, the source id, never `sensor.id`. Availability per sensor is `ProcessReading.isAvailable`; the presenter's version delegates to it for the nearest reading, which macOS still uses. The nearest section shows the address, then last update (on the Environment tab the address row is a colored pill, see the map bullet). The others have no address, since only the nearest is geocoded, so they show the station name, `sensor.name` for every source, and then `distance · last update`. `SensorHeaderView.displayName` re-cases only names written in capitals, which is how PEGELONLINE writes them, and keeps a short last word (`OP`, `UP`) as it is; mixed-case names pass through. Every chart in a level stack is still titled with the waterway, read from `customData["waterway"]` by `LevelChartView.waterway(of:)` on iOS and by the same lookup on macOS, so the header row, which names the gauge, is what tells them apart. The Environment tab does not hide a source when its switch is off. The `--ui-fixture` data gives level, radiation and particles three sensors each, and the UI test captures the middle and bottom of the Environment and Particles tabs, the Settings tab, and the Environment tab at the largest accessibility size. Its first launch turns the three switches on with launch arguments; the large-text launch leaves them off, so it shows the single-sensor path.
- The iOS Environment tab starts with `EnvironmentMapView`: one dot and label per level and radiation reading the tab lists below it, radiation before level, sensors and the reader's own marker only (no POI pins, weather label or header; see the user dot bullet below). It is not the home `MapView`, which hard-codes the six home categories and takes its camera from the `MapPresenter.shared` singleton, one point per presenter; the home camera must not change. It uses `CollisionMapView` directly, with its own camera, `MapCameraPosition.rect(EnvironmentMapView.rect(for:))`: the sensors' bounding box grown by half its size on each side for the labels and never below about 3 km, passed as a binding whose setter ignores writes, so it follows the data and never touches `MapPresenter`. Labels come from `MapAnnotationSnapshot(id:location:selector:icon:faceplate:)`, built from each `ProcessReading` (`customData["icon"]`, `faceplate[selector]`, `n/a` when missing). Ids are `radiation-<reading id>` and `water-<reading id>`: the source id keeps a placement across refreshes, the category keeps a station and a gauge with the same id apart, and an id used twice silently drops a label. The map reads `visibleReadings(multiSensor:)` with each source's switch, so it always matches the sections. It is not interactive, so it does not fight the scrolling, is 367 points high (667 on iPad, the home map's height), and renders nothing, together with its trailing `Divider`, until a sensor has loaded. Every sensor has a color from the six home label colors, `Color.sensor(selector:index:)`: radiation orange, pink, purple and level yellow, green, blue, nearest first, so the nearest of each keeps its home color and an index past the end wraps. The map draws label, dot and connector in it through `MapAnnotationSnapshot.color`, where nil, the default and what every home annotation has, means the selector's color, and `RadiationView` and `LevelView` pass the same index-derived color to `SensorHeaderView`, whose location row becomes a pill in it with the label's half-transparent fill and black text. In dark mode that pill is a dark brown or olive tint on the black page and the black text on it is hard to read; the label has the same weakness over a dark map. A full-opacity pill, or light text on it in dark mode, fixes it. The charts keep the accent fill by design, since `Gradient.linear` is shared by ten chart views, and a header without a color stays plain, although every caller passes one now. Color is the only link between a label and a chart, because the labels carry no station name. Six close labels are the solver's design limit; it never drops one.
- The Particles tab has the same map. The camera, the 367 point (667 on iPad) height, the trailing `Divider` and the empty state until data live in `SensorMapView`, which is in `shared/Sources/Views` together with `FuelMapView` so macOS can show the fuel map; its height is the only platform switch, 367 points on macOS, fixed like the charts; `EnvironmentMapView` and `ParticleMapView` only build the annotations. `ParticleMapView` gives every station a dot and label with the id `particles-<reading id>` and a color from `Color.particleSensors`, all six home label colors: green for the nearest, the home particle color, then pink, blue, orange, yellow and purple. The tab shows six stations and the palette has six entries, one each, so `Color.sensor` never wraps here; two stations in one color would break the only link there is between a label and its chart, and six is also exactly what the label placement solver was built for. The tab is separate from Environment, so colors are reused across tabs. A station reports up to a dozen pollutants and a label has room for one, so it shows the first pollutant in the tab's chart order that has a value: PM10, PM2.5, ozone, NO2 and so on, never the `.all` marker, and PM10 with `n/a` when there is none. `ParticleView` passes the same index-derived color to its headers, and the map and the sections read the same `visibleReadings`, so they agree. The home map's particle label still takes an arbitrary pollutant, `measurements.first?.key`, which is not touched here.
- Level, radiation and particles each have an iOS setting, `Multiple Sensors`, in that source's own settings section (Radiation got a section for it). The keys are `multiSensorLevel`, `multiSensorRadiation` and `multiSensorParticles`, and they default to **off**, so out of the box every source fetches and shows only its nearest sensor, as it did before multi-sensor. macOS has no such setting: it already fetches one sensor. The keys are only ever read with `bool(forKey:)`, so unset means off and launch arguments (`-multiSensorLevel YES`) reach them. Two things act on them. The controllers fetch `SourcePreferences.sensorLimit(forKey:)` sensors, which is 1 when off and the platform cap when on; each takes it as an injectable `sensorLimit` closure, like `nearestSensor`, and it is re-read on every refresh because controllers are built per refresh. The three views list `presenter.visibleReadings(multiSensor:)`. The views trim as well as the fetch because the presenter keeps its last readings until a refresh replaces them, so switching off would otherwise leave the extra sections on screen, possibly for good if that refresh fails. Level has a second switch, `Other Waterways` (`multiSensorLevelOtherWaterways`, default off), shown in the Water card only while its `Multiple Sensors` switch is on because without extra gauges it would change nothing; the controller reads it per refresh through an injectable `otherWaterways` closure. It is independent of `Nearest Sensor`, which decides the first gauge. Each toggle refreshes its source through `refreshSubscription`, so turning it on loads the extra sensors at once. The footnotes say what the switch does to the data and to the home map, which always shows the nearest sensor; the Environment map lists the same sensors as the sections below it.
- The iOS Energy tab (`EnergyView`, `EnergyChartView`, third in the bar with the `fuelpump` icon, where COVID was) shows `ProcessSelector.energy`: `.brent`, `.wti` in `UnitOilPrice.usDollarsPerBarrel` and `.lng` in `UnitGasPrice.eurosPerMegawattHour`, two single-unit dimensions because the prices do not convert into each other. `EnergyController` fetches the three CSVs with `async let`, a failed one drops its series only, and no series at all publishes nothing so the last prices stay. Its parsers are pure statics: dates are `yyyy-MM-dd` as UTC midnight, which is where `.lastDayChange` drag rounding lands; the series is the last year (`EnergyController.span`) with weekends and holidays carried forward as `.uncertain`; ACER's EU price column is used, its rows without one are skipped, and the LNG benchmark, a spread that goes negative, is not shown. One sensor named `Energy` with a nominal Berlin location and `placemark: "EIA · ACER"`, which the header row shows in place of an address, published with `map: .never`. `EnergyTransformer` writes `%.2f %@` with a space and a range of min×0.98 to max×1.02, so the axis never starts at zero and the year's movement fills the chart (the `--ui-fixture` data sets every chart to `0…max×1.5`, so screenshots do start at zero). Its `AreaMark` is anchored at the range's lower bound (`yStart`), as `ParticleChartView` does: an area from zero on an axis that starts near the prices is painted far below the plot, behind the explainer, which is what made the explainer look like part of the chart. A `Divider` separates the sections as well. Under each chart `EnergyView.explainers` puts a gray footnote saying what the price is and where it comes from, for a reader who does not follow the markets, inset with a card's padding but no card: the room around it is what keeps it apart from the axis labels, and a visible box was not wanted. Adding the selector case cost exactly two exhaustive switches, `ProcessSelector.rawValue` and `Color.faceplate` (`Color.energy`, brown, not one of the six sensor palette colors). The home map's label rendering tests lay out exactly six labels, and energy adds none. Refresh fallback is 360 minutes; the data is daily.
- The COVID tab is off by default on iOS and appears next to Polls when enabled; both are gated in `ContentView` by their enable key, with an `onChange` that returns to Home when a shown tab is switched off. The Home settings card shows the COVID map toggle only while COVID is enabled, and `MapView` gates the COVID label and its camera on both keys, like polls. The UI test enables COVID with `-enableCovid YES` so its screenshot survives.
- The Energy tab **starts** with `FuelMapView`: the six dearest (or cheapest) filling stations around the user on a map, from Tankerkoenig, the **first source that needs an API key**. A price list says how much but not where, and where is the useful half, so the map replaced the list. Six, not seven, because that is the label placement solver's documented limit. The rank rides in the **icon** slot as `1.circle.fill` and so on, which leaves the text slot for the price at full size; cramming `1 · 2,38\u{2079} €` into a 132-point label would have shrunk the price instead. Each rank takes one of the six home label colors from `Color.fuelStations`, warm first — orange, pink, yellow, green, blue, purple — which is the other reason the map shows exactly six: one color each, and a seventh would have to repeat. The color marks the rank, not the price level, so the dearest and the cheapest view use the same six in the same order. `Color.energy`, the tab's brown, is not one of them and still colors the charts below; it was every pin's color at first and read muddy over map terrain at half opacity. It reuses `SensorMapView`, so the camera fit, height and empty state are the Environment tab's. The CC BY credit line sits under the map, since attribution is a licence condition and had to move with the feature. `FuelStation` carries a `location` for this; a station the API sends without coordinates is skipped, because it cannot be shown. `FuelController.apiKeyName` is the `SecretKey` and the controller reads `AppSecrets.shared`; the service takes the key as a **parameter**, never reading a store itself, because `DoomKitServices` cannot see the app layer, the golden URL table needs a reproducible value (`apikey=fixture-key`), and unsigned test runners cannot read the keychain at all. **No key means no request.** The API rejects `sort=price` while `type=all`, so the request is always `sort=dist&type=all` and every ranking is local; that is why the fuel and order pickers re-sort instantly while only the radius picker refetches. The radius is capped at 25 km by the API (26 and 50 return the same stations), and `SourcePreferences.fuelRadius()` clamps it. Closed stations are dropped even though they still report a price, and equal prices are broken by distance, nearest first, so the set does not wobble between refreshes. Prices are written the way a German pump board writes them, `2,40\u{2079} €`: a comma, and the tenth of a cent raised, which is the digit the whole ranking turns on, so rounding it away would make stations the list ranks apart look identical. Station names are not shown at all any more: a map label holds one icon and one value, and position is what identifies a station now. `FuelPresenter` copies `HazardPresenter` (a `ProcessRefreshable` holding models, generation counter, 5 min / 1 km failure cooldown) and rides `SourcePreferences.energyEnableKey`, so the Energy switch governs the whole tab. `SecretField` takes an `onChange` because a keychain write is **not** a `UserDefaults` change and `ConditionalSubscription` would otherwise not notice a new key until the next hourly tick. A key cannot be seeded by a launch argument, so the UI fixture seeds the presenter directly through `publish(stations:timestamp:)`, as hazards do.
- All three `SensorMapView` maps (Environment, Particles, Energy) show the reader's own position as a black dot with the white halo the home map gives the user, and no label, built by `SensorMapView.userAnnotation(at:)` with the id `user`, `showsLabel: false` and `Color.user`. Its selector is inert: `displayColor` takes the explicit color, and an annotation without a label draws neither a label nor a connector, so it carries `.weather(.temperature)` only because that is what the home map's user marker carries. `Color.user` is black and deliberately outside the six label colors, since it marks where the reader is rather than what a sensor measures. The marker **joins the camera fit**, so it is always on screen; the cost is that a far sensor zooms the camera out until both fit, which is the right answer, because when the nearest gauge on a natural waterway is a hundred kilometres away that distance is the reading. The gate is the sensor array, not the fitted rectangle, so the marker can never make an empty map appear and the map still shows nothing until a sensor has loaded. It shows whatever the location origin, the Berlin fallback included, as the home map does; telling `.fallback` from `.measured` would be a behaviour the rest of the app does not have. `SensorMapView` reads `AppLocation.shared.updates()` in a `.task`, observing only, exactly as `NearestPlacesView` and `MapView` do — never start or stop tracking from a view. It lives in `SensorMapView` rather than the three `annotations(...)` builders, which still return exactly the sensor arrays their tests assert on. `MapAnnotationSnapshot`'s value init has a defaulted `user` parameter for it; `CollisionMapView` needed nothing, since it already drew the halo for `user == true` and already treated a label-less annotation as a dot that reserves 15 points of clearance. That clearance shifts labels near the reader by a few points and drops none.
- `LocationConfiguration.continuousBackground` is iOS-only: best accuracy, Always request, background updates enabled, automatic pauses disabled, background indicator enabled. Default macOS behavior remains kilometer accuracy and When In Use.
- Preserve the strictly-greater-than-100-metre movement filter. The iOS coordinator uses everyMovement; default macOS uses firstMeasurement. Keep immediate fallback startup and cancellation checks.
- iOS keeps showWater, enableElectionPolls default false, and showElectionPolls default true. Only enableElectionPolls controls poll fetching. COVID follows the same two-key shape on iOS: `SourcePreferences.covidEnableKey` (`enableCovid`, default **false**) controls fetching and the tab, and `showCovid` only the map label (`covidVisible()` needs both); on macOS the enable key is `showCovid`, default true, so the macOS COVID tab is unchanged. Energy prices have one key, `enableEnergy`, default true, and nothing on the map. Other conditional sources use their switches; weather and forecasts always fetch. Preserve successful values while disabled.
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

### Notifications

- Both apps send local notifications when a reading reaches its warning or critical limit. Nothing is pushed from a server; the checks run on the device after each refresh. The master switch, `notificationsEnabled`, starts **off**, and turning it on asks for permission; so does launching with it already on, for launch arguments and restored backups.
- Eight families, `WarningFamily`, each with a switch `notify.<family>`: weather, hazards, level, radiation, particles, covid, energy, fuel. Weather, hazards, level, radiation and particles start on; covid, energy and fuel start off, since watching prices is opt-in. Polls are not warned about. A family only sees data while its source is enabled, so the family pages say which source switch they need.
- `WarningRule.catalogue` holds every rule with a number: id, selectors, direction (`above` or `below`), the unit the limits are stored in, defaults, clamp range and the footnote naming where the default comes from (DWD for heat, frost, gusts and rain; the UBA index bands for PM10, PM2.5 and NO2; the EU thresholds for ozone). Limits are `warning.<rule id>.warning` and `.critical`, read by `WarningPreferences` so that unset is the default and a launch-argument string parses (`-warning.radiation.total.warning 0.01`). `limits(for:)` returns them ordered: a critical value entered on the wrong side acts as the warning value, and the settings say so in red. Hazards take two severities instead, `warning.hazards.warning` and `.critical`, default moderate and severe.
- Level has no numbers. Each gauge is compared against its own PEGELONLINE characteristic values, because one number is only right for the gauge it was set for. `LevelService.fetchCharacteristics` fetches `stations/{id}.json?includeTimeseries=true&includeCharacteristicValues=true` (about 2 KB; the full list with values is 1.3 MB) beside each gauge's measurements, and `LevelController.parseMarks` puts the W series' values into `customData["marks"]` in metres. A failure leaves the key out and never costs the gauge its readings. `WarningEvaluator.levelMarks` takes the warning at `M_I`, else `MHW`, and critical at the first of `M_II`, `HSW`, `HHW` above it, since `HSW` can sit below `MHW` (Celle). About a quarter of all gauges, many on canals, publish no marks and raise nothing.
- `WarningEvaluator` is pure. It reads `ProcessReading.current`, which the transformer already filtered by quality, so ARIMA placeholders never count, and converts into the rule's unit; the one hand conversion is WeatherKit's current rain intensity, a `UnitSpeed`, into mm/h. Forecast rules take the worst hour of the next 24 and name it in the notice. Every judgeable measurement yields a `WarningAssessment`, the normal ones included, because normal is what re-arms. Keys are `<rule id>.<sourceID>` (every fetched sensor is checked, not only the nearest), `<rule id>` for single-sensor sources, `level.marks.<sourceID>` and `hazard.<NINA id>`. Current weather and the forecast share a key as separate inputs: the worst input counts, so a frost the forecast announced does not notify again when it arrives, and a mild afternoon does not re-arm a frost still forecast for the night. Fuel is the cheapest open station for the chosen fuel and radius.
- `WarningNotifier.shared` notifies **only on escalation**: normal to warning, warning to critical, or straight to critical. Easing re-arms the levels above, and one key and level never notify twice within 6 hours, so a value hovering at a limit stays quiet. Its state is JSON in `UserDefaults` under `warningState`, because background launches must see it, and keys unseen for 7 days are pruned. It does nothing while `AppLocation.shared` reports the fallback origin, so a cold background launch cannot warn about Berlin. The notice identifier is the key, so a newer notice about a sensor replaces the older one. `NotificationCenterPoster` wraps `UNUserNotificationCenter`, is its delegate from launch, and shows banners in the foreground. Critical notices set `.timeSensitive`, which degrades to an ordinary alert because the app lacks the `com.apple.developer.usernotifications.time-sensitive` entitlement; adding it is a signing change and waits for an explicit decision.
- Hooks: `ProcessPresenter.publish(readings:map:)` (every ProcessPresenter refresh, all sensors), and `HazardPresenter.refreshData` and `FuelPresenter.refreshData` after their publish calls, not inside `publish`, which the UI fixture calls. `replace(readings:)` never notifies, so fixtures stay silent. The notification files are in the `PointOfInterestTests` include list, since `ProcessPresenter+Map.swift` is.
- iOS wakes itself with a `BGAppRefreshTask`, `BackgroundRefresh.identifier` (`com.panjas.dashboard-of-doom.refresh`, also in Info.plist under `BGTaskSchedulerPermittedIdentifiers`, with `fetch` in `UIBackgroundModes`). It is registered in `didFinishLaunching` and scheduled, 15 minutes at the earliest, on entering the background and on the master switch, only while notifications are on. The task waits up to 10 seconds for a measured position, then awaits `AppProcess.shared.refreshSubscriptionsAndWait()` (`ProcessManager.refreshAllAndWait()` in DoomKitProcess awaits the tasks `refresh(id:)` returns). The simulator refuses to schedule it; test it on a device, or with `_simulateLaunchForTaskWithIdentifier:` from the debugger.
- Settings: iOS has a Notifications card after Home with the master switch, the permission state with a button to iOS Settings, and a row per family that pushes `NotificationFamilySettingsView`: the family switch, a card per rule with warning and critical fields and Restore Defaults, severity pickers for hazards, and the loaded gauges' marks for level. macOS has the Notify settings tab with a section per family. The simulator cannot grant notification permission from the command line (`simctl privacy` has no such service), so an unattended run gets as far as `Posting notification …` in the log and the system's "not authorized"; delivery was not verified there.

### Local Package Boundaries

- `doom-kit-location` / `DoomKitLocation`: location values, provider-independent state streams and movement filtering, separate async geocoding
- `doom-kit-network` / `DoomKitNetwork`: network actor, typed state streams, injectable monitoring/transport/timing, shared request execution
- `doom-kit-process` / `DoomKitProcess`: process models, custom units, geographic helpers, open observable presenter and transformer bases, coordinator, generic main-actor scheduler and injected clock; local dependencies on DoomKitLocation and DoomKitNetwork
- `doom-kit-tools` / `DoomKitTools`: generic Measurement smoothing, ARIMA, polygon/bounding-box helpers, symbols, and mutex-protected synchronous Sendable Trace; depends only on DoomKitLocation
- `doom-kit-services` / `DoomKitServices`: eight public static API services with trailing injectable NetworkManager defaults; depends on Location, Network, and Tools
- `doom-kit-secrets` / `DoomKitSecrets`: API keys and tokens, one string per `SecretKey` name, behind the `SecretStore` protocol (`read`, `write`, `delete`, `contains`; writing an empty value deletes). `KeychainSecretStore` files them as generic passwords under one service name, `kSecAttrSynchronizable` so iCloud Keychain carries a key to the user's other devices, `kSecUseDataProtectionKeychain` because that is the keychain that syncs and the one the sandboxed macOS app has, readable after first unlock so background refreshes can use them. `MemorySecretStore` is the double for tests and previews. No dependencies. The app's instance is `AppSecrets.shared` (service `com.panjas.dashboard-of-doom.secrets`), and `SecretField` is the settings row for pasting or removing a named key; nothing consumes a key yet. A source that needs one declares its `SecretKey` beside its service and reads it there. The keychain works only in an entitled process, so the unsigned test runners (`iOSTests`, `PointOfInterestTests`, and the unsigned simulator app) get `errSecMissingEntitlement` (-34018); the package tests cover the memory store and the item query, and `--keychain-check` (Debug, `IOSAppRuntime`) runs a write, replace and remove of a probe key in the app itself, which passed on the signed device build and on the signed macOS Debug build, where the Developer ID profile's application identifier is what the data protection keychain needs, so no entitlement was added. The same run found a Tankerkoenig key stored from iOS and fetched stations with it, so iCloud Keychain carries keys between the two apps. Never put a key in the repo, `project.yml` or `UserDefaults`.
- Keep smoothing independent of ProcessValue; app callers rebuild values in order with original metadata, timestamps, quality, units, and new UUIDs
- Preserve original unit coefficients and base units, numeric algorithms, service URL/date behavior, and failure-to-nil cancellation contract during extraction work
- All packages use Swift tools 6.2 and Swift 6 language mode; keep the app in Swift 5 mode
- Packages declare macOS 15 and iOS 26; both app targets integrate them. See ios/MIGRATION.md for simulator and device validation limits.
- Each state consumer owns a separate latest-value stream and explicitly cancelled task; stop finishes all streams and restart requires new subscriptions
- Location initialization does not request permission or track; the private Core Location provider starts explicitly with kilometer accuracy
- Native `CLLocationUpdate.liveUpdates()` is a planned provider replacement; validate accuracy, authorization, delivery, cancellation, and background behavior separately
- Refresh closures must check cancellation after awaits and immediately before synchronous publication; use per-refresh transformer state
- Keep concrete presenters, Berlin fallback configuration, settings, and the starting `AppProcess.shared` factory in the app; shared process models and coordinator lifecycle policy belong to DoomKitProcess
- A source reports up to `SourcePreferences.sensorMaximum(forKey:)` sensors, nearest first. That is `ProcessSensor.maximumPerSource`, 3 on iOS, which lists them, and 1 on macOS, which shows only the nearest and so fetches only that, except particles, which report `SourcePreferences.particlesSensorMaximum`, 6, on iOS: the Particles tab is its own tab, so its six stations can have all six label colors and six is the placement solver's limit. macOS keeps the platform cap whatever the source. The cap is decided in one place, `sensorLimit(forKey:)`, so the controllers did not change; the cost is one request per station, so particles make twice as many as before. Tests must pass an explicit limit rather than rely on the default, which is the platform cap. `ProcessPresenter` stores `readings: [ProcessReading]` (a sensor plus everything its transformer rendered); `sensor`, `measurements`, `current`, `faceplate`, `range`, `trend` and `timestamp` are get-only forwards to `readings.first`, so views keep reading the nearest sensor. Do not add setters: write-through would reintroduce the single-sensor assumption. Level, radiation and particles return several sensors; the other four sources return one and everything reads the first. Only the iOS Environment tab (its charts and its own map) and Particles tab (its charts and its own map) show sensors 2 and 3, and only while that source's Multiple Sensors switch is on (below); the home map, macOS and any picker still show the nearest one.
- Publish with `publish(readings:)`, which ignores an empty array so a failed refresh keeps the last good values and never moves the map camera. The app-side `publish(readings:map:)` in `ProcessPresenter+Map.swift` also drives `MapPresenter` from the nearest sensor through `ProcessMapVisibility`: `.never` for forecast, `.always` for weather, `.conditional` for the sources with a switch. Keep each presenter's own `isEnabled` guard in `refreshData`, not in `publish`: weather and forecast have none on purpose, and `ConditionalSubscriptionTests` publishes sensors with empty measurements. `replace(readings:)` is for fixtures and tests only.
- `ProcessSensor.sourceID` is the provider's stable id (PEGELONLINE uuid, BfS kenn) and `distance` is metres from the user; `id` changes on every refresh, so never key anything that must survive a refresh on it.
- Level and radiation fetch station series two at a time with `concurrentCompactMap` (order preserved, nil dropped) and assemble sensors with `SensorCandidate.sensors`: candidates are geocoded in order until one succeeds, only that one is geocoded, and the rest carry no placemark. The first sensor is emitted even without data so an outage shows an empty chart rather than moving the pin; later stations without data are dropped. Level takes the gauges on the nearest natural waterway (never padded with other rivers), else the nearest gauges overall, and ignores gauges beyond 1000 km. With the `Other Waterways` setting on, only the first gauge follows that rule; the rest are the nearest remaining gauges on any waterway, listed after the first, so one of them can be nearer than it and the distances down the stack do not always increase. `LevelController.Station` has `waterway` and `gauge`, and the sensor is named after the **gauge**, as every source is named after its station; the waterway travels in `customData["waterway"]`, since it is what the charts are titled with and does not fit the standard interface. Only the waterway is re-cased in the controller by `capitalizeGerman`, which splits on whitespace and would mangle a gauge into `Berlin-mühlendamm Up`; gauges are re-cased for display by `SensorHeaderView.displayName`, which keeps the hyphen and the `OP`/`UP` suffix. `selectStations` matches on `waterway` against the bundled network and runs before that re-casing, on the raw PEGELONLINE spelling.
- Particles use the same plumbing: `SensorCandidate` holds a dictionary of series per station, since a station reports up to 12 pollutants, and `SensorCandidate.sensors` takes an injectable `geocode`. `ParticleController.selectStations` picks the stations. By default the first sensor is the nearest station that reports PM10, PM2.5, NO2 and O3, found by probing stations in order and stopping at the first (the probe is sequential and unbounded, as it always was), and the others are the stations that follow it by distance, whatever they report, so the order by distance holds. With `nearestParticleSensor` they are the nearest stations, and when none qualifies the nearest are used. A station with no data is dropped, a failure drops only that station, and if the first station has no data nothing is published, as before, so the last values stay. Each station costs a forecast request and, unless probing already fetched it, a measurement request: 7 requests best case on iOS, 3 on macOS.
- Preserve the unrelated theme notification observer

- Overpass requests share one cancellation-aware transport queue in DoomKitNetwork; never rotate endpoints on HTTP 429. Availability fallback uses overpass.private.coffee. As of the waterway change below, Overpass is used only by the background POI system — no controller depends on it for sensor resolution anymore.
- Water-level gauge resolution (`LevelController`) no longer queries OSM/Overpass at all. It uses a bundled, offline-converted federal waterway network (GDWS VerkNet-BWaStr, `shared/Sources/Resources/BundeswasserstrassenNetz.json.zlib`, zlib-compressed JSON keyed by PEGELONLINE `waterBodyName`) with a hand-curated natural/artificial flag per waterway. For the default (non-`nearestLevelSensor`) path, it finds the nearest point among all `isNatural == true` polylines within `waterwaySearchRadius` (10km) using `PolygonProximityCalculator.nearestPointOnPolyline`, then matches that waterway's name exactly against PEGELONLINE stations. Missing/unmatched waterway data falls back to the nearest official gauge, same as before. The `nearestLevelSensor` toggle still bypasses this entirely (pure nearest gauge).
- The natural/artificial flag is a name-based heuristic (a waterway is artificial if its PEGELONLINE name contains "KANAL"), audited once against WasserBLIcK/WRRL's own `ARTIFICIAL` field (WKSB_3BWP, 3. Bewirtschaftungsplan, May 2025 — the EU Water Framework Directive classification dataset flagged as inaccessible in the earlier COVID-fix research pass; it became reachable once the user downloaded the current export directly). WRRL cannot replace the heuristic wholesale: its names are ecological water bodies, not PEGELONLINE's shipping-route names (only 47 of 103 join exactly), and its flag is origin-based rather than behavioural, so a canal dug along an old river course reads as "not artificial" (e.g. Elbe-Lübeck-Kanal, Oranienburger Kanal) — wrong for our purpose, which cares whether the level is naturally variable or lock-controlled. One real correction came out of the audit: `MÜRITZ-ELDE-WASSERSTRASSE` has no "KANAL" in its name but is a heavily locked system: WRRL's constituent water bodies agree it's artificial 5-to-1, so it's now hard-overridden in the curation script (`ARTIFICIAL_OVERRIDES` in the offline `build_waterways.py` pipeline, not shipped in the app). Every other disagreement between the heuristic and WRRL was a KANAL-named waterway where WRRL's origin-based flag was the wrong signal, so the heuristic stands as-is for those. Do not re-attempt a full WRRL-based replacement without new evidence — this was investigated concretely, not assumed.
- COVID district resolution queries BKG's VG250 WFS (`vg250:vg250_krs`) directly, not Overpass; it resolves the containing Kreis by real point-in-polygon containment (falling back to nearest polygon edge), reusing `isPointInPolygon`/`PolygonProximityCalculator` from `DoomKitProcess`/`DoomKitTools`. No fallback to Overpass if BKG is unreachable — same graceful no-data-this-cycle behavior as any other source failure.
- Berlin is a special case: RKI/corona-zahlen.org reports COVID data per Bezirk (12 boroughs, ids 11001-11012), not city-wide, because Berlin's Bezirke are not independent Gemeinden and never appear in BKG's VG250 layers. When BKG resolves a location to Berlin's whole-city Kreis ("11000", not itself a valid RKI id), `CovidController` falls through to a bundled Bezirk boundary dataset (`shared/Sources/Resources/BerlinBezirke.geojson`, CC-BY, Amt für Statistik Berlin-Brandenburg) and re-resolves by the same point-in-polygon logic. Verified this is the only such nationwide exception — Hamburg and every other city currently report as a single district like the rest of Germany.
- The COVID sensor's displayed location (map pin, reverse-geocoded placemark) is a district's polygon centroid, not the user's location or a real physical sensor site — there is none, since the underlying data is district-wide. `CovidController.centroid(of:)` computes this as an area-weighted centroid (shoelace formula per ring, combined across a MultiPolygon's rings by ring area), used identically for BKG's nationwide Kreis polygons and Berlin's bundled Bezirk polygons. The iOS COVID tab **starts** with `CovidMapView`, which draws that district: the boundary shaded in `Color.covid` at 0.18 opacity with a 2-point stroke, one label at the centroid with the incidence, and the reader's black dot. It is the only thing that says what area the numbers cover, and the dot the only thing that says whether the reader is inside it, which the centroid address cannot. The ring reaches the view through `customData["polygons"]` as `[[Location]]` — `customData` is `[String: Any]?` and exists for exactly this, so neither `ProcessSensor` nor `doom-kit-process` changed; `CovidMapView.polygons(covid:)` casts it back with `as?` and draws nothing when it is absent, as any other source would be. `CollisionMapView` gained `polygons` and `polygonColor` (defaulting to `Color.covid`, so the next area source passes its own rather than editing that view) and renders them with `MapPolygon` **first** in the `Map` builder, under the dots; this is the repo's first use of `MapPolygon`. A polygon is map content and needs no projection, so it stays out of `GeometryInput`, `Trigger` and the `AnnotationLayout` request, and label placement is unaffected. `SensorMapView` gained `polygons` and `padding`, and `rect(for:padding:)` replaced the hardcoded doubling: the default `2` is the room six labels need and keeps the other three maps framed exactly as before, while the COVID map passes `1.15`, because a district fills its own frame and needs room for one label. The annotation id is the fixed string `covid`, not `covid-<reading id>`, because COVID reports exactly one district and `ProcessReading.id` changes on every refresh (the sensor carries no `sourceID`), which would move the label's placement with it. A Berlin Bezirk outer ring is 734 to 2,124 vertices, so no decimation is needed. `CovidView` keeps its own placemark header; the map must not duplicate it. `CovidController` sets neither `sourceID` nor `distance` on the COVID sensor, and there is no district cache at all: a new controller per refresh re-hits the VG250 WFS and re-parses up to 20 Kreis polygons, which on iOS happens on every movement update rather than every six hours. `CovidController.centroid(of:)` deliberately does not average the polygon's boundary vertices directly — that's biased toward wherever a boundary happens to be traced with more points (a winding riverbank, a jagged administrative edge) and can land far from the district's actual visual center, confirmed for Berlin Mitte: it moved the resolved address from Seydlitzstraße to Heidestraße, both still within the correct postal district.

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
3. **Implement Controller**: Add data orchestration with quality assessment. Name the sensor after its station, and put anything else the UI needs in `customData` rather than adding a field to a shared model or holding it somewhere
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

Planned work that has not started is in [ROADMAP.md](ROADMAP.md).
