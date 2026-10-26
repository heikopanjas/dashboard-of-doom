# macOS application instructions

Follow [the root AGENTS.md](../AGENTS.md) and root skills.

- Use the root project.yml and generated project for builds.
- Run ./macos/build.sh from the repository root; outputs remain in root .build/.
- Keep macOS rendering tests in Tests and script tests in BuildTests.
- Common sources, tests, and packages live under ../shared/.
- Preserve macOS signing, WeatherKit entitlement, and menu bar behavior.
