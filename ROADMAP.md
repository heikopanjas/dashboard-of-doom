# Roadmap

Planned work that has not started yet, newest first. An entry records what was decided and why, so the work can start from it without repeating the research. Once work starts, the decisions move to AGENTS.md and UPDATES.md and the entry is deleted.

## Notifications with warning values per sensor family

*Planned 2026-09-26. Depends on hazards, energy and fuel being on macOS.*

The app shows readings but never tells anyone when one gets bad. The README has long claimed native notifications, but there is no `UserNotifications` code, no background refresh and no threshold anywhere. The only limits are hard-coded chart lines on macOS.

### Decisions

- iOS and macOS both get notifications. macOS covers whatever families it has, so it needs hazards, energy and fuel before it has all of them.
- Families: weather (current weather and the next 24 hours of forecast), level, radiation, particles, hazards (NINA), COVID, energy and fuel. Polls are out.
- Every measurement has two limits, warning and critical, and the user can change both.
- Level does not take a number. A gauge on the Spree reads about 1.5 m and one on the Elbe about 3 m, so one number is only right for the gauge it was set for. Level compares each gauge against its own PEGELONLINE characteristic values instead.
- Every sensor a source fetches is checked, not only the nearest.
- iOS gets a `BGAppRefreshTask`, so notifications do not depend on the phone moving. Today background refreshes only happen after a location update of more than 100 m.

### Default limits

"Above" means notify at or above the limit, "below" at or below it.

| Family | Rule | Direction | Warning / critical | Basis |
|---|---|---|---|---|
| Weather | felt temperature, current and forecast | above | 32 / 38 °C | DWD heat stress levels |
| Weather | temperature, current and forecast | below | 0 / −10 °C | DWD frost and severe frost |
| Weather | wind gust, current and forecast | above | 65 / 90 km/h | DWD storm gusts and severe storm gusts |
| Weather | precipitation per hour | above | 15 / 25 mm/h | DWD heavy rain, notable and severe |
| Particles | PM10, PM2.5, NO2, O3 in µg/m³ | above | 50/100, 25/50, 100/200, 180/240 | UBA air quality index bands "poor" and "very poor". 180 and 240 for ozone are also the EU information and alert thresholds |
| Radiation | total dose rate | above | 0.5 / 1.0 µSv/h | Rain washout can briefly double the background to about 0.4, which should not wake anyone |
| COVID | incidence per 100k | above | 100 / 200 | |
| Energy | Brent, WTI, LNG | above | 100/130 $/bbl, 95/125 $/bbl, 60/100 €/MWh | |
| Fuel | cheapest open station for the chosen fuel within the radius | above | 2.00 / 2.20 €/l | Even the cheapest station is dear |
| Hazards | CAP severity | at or above | moderate / severe | `Hazard.Severity` |
| Level | gauge reading against the gauge's marks | above | warning at `M_I`, else `MHW`. Critical at the first of `M_II`, `HSW`, `HHW` above the warning mark | PEGELONLINE characteristic values |

Checked against the live API on 2026-09-26: 561 of 737 W series publish marks. MHW is on 375, HHW on 325, HSW on 127, and the official flood reporting stages `M_I` and `M_II` on about 55. `HSW` can sit below `MHW` (Celle: MHW 412 cm, HSW 310 cm), which is why critical takes the first mark above the warning mark rather than a fixed one. A gauge without marks raises no level notification, and the settings say so. The marks come from `stations/{uuid}.json?includeTimeseries=true&includeCharacteristicValues=true`, about 2 KB per gauge. The full station list with marks is 1.3 MB against 296 KB without, so it is fetched per gauge and not with the list.

The family switches start on for weather, level, radiation, particles and hazards, and off for COVID, energy and fuel, because watching prices is something to opt into. The master switch starts off, and turning it on asks for permission.

### Design

- `shared/Sources/Notifications/` holds four parts:
  - `WarningRule`: the rule catalogue above.
  - `WarningPreferences`: keys and defaults in the style of `SourcePreferences`. The master switch is read with `bool(forKey:)`. The limits are read as `object(forKey:) != nil ? double(forKey:) : default`, so a launch argument such as `-warning.radiation.total.warning 0.01` still parses.
  - `WarningEvaluator`: pure functions.
  - `WarningNotifier`: posts the notifications.
- The evaluator reads `ProcessReading.current`, which the transformer has already filtered by quality, so ARIMA placeholders and values of unknown quality never count. Forecast rules take the extreme of the next 24 hourly values and keep that hour for the message.
- Level marks travel in `customData["marks"]` as `[String: Double]` in metres, like any other value outside the standard interface.
- The notifier only notifies on escalation: normal to warning, warning to critical, or straight to critical. A reading that drops back to normal re-arms its key, but the same key and level stay quiet for 6 hours so a value hovering at a limit does not flap.
- Keys are `<rule>.<sensor.sourceID>`, just `<rule>` for sources with one sensor, and `hazard.<id>` for warnings. Current weather and the forecast share a key, so frost the forecast announced does not notify a second time when it arrives.
- The state lives in `UserDefaults`, because background launches have to see it. Keys not seen for 7 days are pruned.
- Nothing is sent while the location is still the Berlin fallback, so a cold background launch cannot warn about Berlin.
- Hooks:
  - `publish(readings:map:)` in `ProcessPresenter+Map.swift`. Fixtures go through `replace(readings:)` and never notify.
  - `HazardPresenter.refreshData` and `FuelPresenter.refreshData`, after their publish calls.
  - The new files also go into the `PointOfInterestTests` include list.
- DoomKitProcess gets an awaitable `refreshSubscriptionsAndWait()` for the background task. The task waits up to 10 seconds for a measured location first.
- Critical notifications use `.timeSensitive`, which needs the `com.apple.developer.usernotifications.time-sensitive` entitlement. That goes in a commit of its own, because AGENTS.md says to leave entitlements alone unless the change is explicit. Without the entitlement, critical notifications arrive as ordinary ones.
- Settings:
  - iOS: a Notifications section with the master switch and one row per family, each opening a page with two number fields per rule. Level shows the marks of the gauges it fetched instead of fields.
  - macOS: a Notifications tab with one section per family.
