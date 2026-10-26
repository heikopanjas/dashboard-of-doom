# Roadmap

Planned work that has not started yet, newest first. An entry records what was decided and why, so the work can start from it without repeating the research. Once work starts, the decisions move to AGENTS.md and UPDATES.md and the entry is deleted.

## Sparkle automatic updates

*Noted 2026-10-26. Not started; the CI and release workflows were built without it, by choice.*

- **What it takes**, from Senor Particle, which has it (`/Users/heiko/_devel/_me/senor-particle`, its AGENTS.md and `release.yml`):
  - Sparkle 2 as a package and one long-lived `SPUStandardUpdaterController` owned by `AppDelegate`, with Check for Updates in Settings > About.
  - `SUFeedURL`, `SUPublicEDKey`, `SUEnableInstallerLauncherService`, `SUVerifyUpdateBeforeExtraction` and `SURequireSignedFeed` in the Info.plist. The app generates its Info.plist from `project.yml`, so they become `INFOPLIST_KEY_` settings or a small plist.
  - The app is sandboxed, so it needs the `-spks`/`-spki` mach-lookup temporary exceptions. Do not enable Sparkle's Downloader service.
  - In `release.yml`: an app-only update archive, `generate_appcast` from the package artifacts with the `SPARKLE_ED_PRIVATE_KEY` secret, a `sparkle-updates` prerelease for the archives, and `appcast.xml` on GitHub Pages, which is not enabled for the repository yet.
- **Already in place:** `CFBundleVersion` is `GITHUB_RUN_ID`, which only ever grows across both workflows, as Sparkle requires.
- **To settle when it starts:** whether develop prereleases get their own feed channel; the bootstrap release, since installs from before Sparkle need one manual update.

## Sensor forecasts: step 7

*Noted 2026-09-28. Steps 1 to 6 are done (see the Sensor Forecasts section of AGENTS.md); these are the steps left, one at a time.*

- **Which sources publish a forecast** (checked live on 2026-09-28):
  - PEGELONLINE publishes water level forecasts as the timeseries `WV`, at `stations/{id}/WV/measurements.json`, keyless, under DL-DE Zero. They exist on 43 gauges (Elbe, Rhine, Oder, Danube, Saale) and on none in Berlin.
  - Each value has `initialized`, `timestamp`, `value` in cm and `type`, where `type` is `forecast` for about the first 48 h and `estimate` after that. Only the Oder gauges fill `percentile10` and `percentile90`.
  - Adding `includeForecastTimeseries=true` to the station request the app already makes for the flood marks lists a `WV` entry when there is one, so detection costs no extra request.
  - UBA publishes air quality forecasts about 3 days ahead, hourly, for PM10, PM2.5, NO2 and O3; the app uses them since step 2.
  - BfS, the COVID feeds, DAWUM, EIA/ACER and Tankerkoenig publish none. For oil, EIA's monthly STEO outlook exists only as an Excel file.
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
