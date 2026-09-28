# Roadmap

Planned work that has not started yet, newest first. An entry records what was decided and why, so the work can start from it without repeating the research. Once work starts, the decisions move to AGENTS.md and UPDATES.md and the entry is deleted.

## Sensor forecasts: steps 3 to 7

*Noted 2026-09-28. Steps 1 and 2 are done (see the Sensor Forecasts section of AGENTS.md); these are the steps left, one at a time.*

- **Which sources publish a forecast** (checked live on 2026-09-28):
  - PEGELONLINE publishes water level forecasts as the timeseries `WV`, at `stations/{id}/WV/measurements.json`, keyless, under DL-DE Zero. They exist on 43 gauges (Elbe, Rhine, Oder, Danube, Saale) and on none in Berlin.
  - Each value has `initialized`, `timestamp`, `value` in cm and `type`, where `type` is `forecast` for about the first 48 h and `estimate` after that. Only the Oder gauges fill `percentile10` and `percentile90`.
  - Adding `includeForecastTimeseries=true` to the station request the app already makes for the flood marks lists a `WV` entry when there is one, so detection costs no extra request.
  - UBA publishes air quality forecasts about 3 days ahead, hourly, for PM10, PM2.5, NO2 and O3; the app uses them since step 2.
  - BfS, the COVID feeds, DAWUM, EIA/ACER and Tankerkoenig publish none. For oil, EIA's monthly STEO outlook exists only as an Excel file.
- **Step 3, level WV:**
  - `LevelService.fetchCharacteristics(includeForecast:)`.
  - `LevelController` fetches `WV` only where the gauge lists it and the switch is on.
  - `parseForecast` converts cm to m, maps p10/p90 to the band and `initialized` to `issued`, and records where `type` turns `estimate` in the forecast's `customData["estimateFrom"]`.
- **Step 4, warnings:**
  - `WarningRule.providerForecast` for particle PM10, PM2.5, NO2 and O3.
  - `WarningEvaluator` takes the worst provider point within 24 h as the input "forecast", and the highest WV point against the gauge's marks on `level.marks.<sourceID>`.
  - Estimates never warn, and nothing warns while the switch is off.
- **Step 5, the engine:** a new `Forecasting/` folder in DoomKitTools.
  - `Forecaster` regularises by linear interpolation, applies a transform (identity, log or log1p), clamps to bounds, and keeps 80 % coverage.
  - Models:
    - `RandomWalkModel`: band ±z·σ·√h, with σ from 1.4826·MAD.
    - `DampedTrendModel`: ETS(A,Ad,N) fitted by grid search, with a variance that grows with the horizon.
    - `SeasonalModel(period:)`.
    - `HarmonicModel` for tides: M2 12.42 h and M4 6.21 h by least squares, with R² detection.
    - `BaselineModel`: the median with quantile bands.
  - `Backtest` uses rolling origins and reports MASE and coverage. Tests use seeded synthetic series.
- **Step 6, the app's own estimates**, through `SeriesEstimate`, fitted on the raw parsed series, never the gap-filled one. It has a staleness guard and falls back to the random walk when a model does worse than naive.
  - 6a radiation: usual range, 24 h.
  - 6b energy: last price in log space, 30 days.
  - 6c level without WV: the tide on tidal gauges, else a damped trend on hourly means, 12 h.
  - 6d polls: a damped trend fitted before smoothing, 0 to 100, 90 days. ARIMA goes, and current and trend read measurements only.
  - 6e COVID: a weekly pattern on cases, deaths and recovered, a damped trend on the incidence, both with log1p, 14 days. `nowCast` goes.
- **Step 7:** delete `ARIMAPredictor` and its three type files, trim `ToolsTests`, and update the ARIMA mentions in AGENTS.md.
- **Risks noted:**
  - A new shared file an included source uses must go into the `PointOfInterestTests` include list.
  - Long provider horizons squeeze the measured part of the small iOS charts, so the shown horizon may need a cap.
  - Tidal gauge detection by the `MThw`/`MTnw` marks is unverified.

## macOS: clean up the settings

*Noted 2026-09-26. Not started.*

The settings panel has grown tab by tab and should get a tidier structure.

- **Today:** `SettingsTab` has twelve tabs in an 840 pt panel: General, Weather, Warnings, COVID-19, Level, Radiation, Particles, Energy, Polls, Places, Notify and About. Several hold only an enable toggle and a refresh picker. The source switches now also decide which dashboard tabs exist.
- **To settle when it starts:**
  - Group the sources into fewer tabs, or keep one per source.
  - Collect the enable switches in one place, as the iOS Sources card does.
  - Where Notify and About go.
