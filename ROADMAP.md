# Roadmap

Planned work that has not started yet, newest first. An entry records what was decided and why, so the work can start from it without repeating the research. Once work starts, the decisions move to AGENTS.md and UPDATES.md and the entry is deleted.

## macOS: clean up the settings

*Noted 2026-09-26. Not started.*

The settings panel has grown tab by tab and should get a tidier structure.

- **Today:** `SettingsTab` has twelve tabs in an 840 pt panel: General, Weather, Warnings, COVID-19, Level, Radiation, Particles, Energy, Polls, Places, Notify and About. Several hold only an enable toggle and a refresh picker. The source switches now also decide which dashboard tabs exist.
- **To settle when it starts:**
  - Group the sources into fewer tabs, or keep one per source.
  - Collect the enable switches in one place, as the iOS Sources card does.
  - Where Notify and About go.
