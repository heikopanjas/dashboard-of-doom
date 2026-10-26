#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
CONFIGURATION=Debug
PLATFORM=simulator
SIMULATOR_ID=""
DEVICE_ID=""
RUN=false

usage() {
    cat <<'HELP'
Usage: ./ios/build.sh [--release] [--device [UDID] | --simulator UUID] [--run]

Build iOS with the root XcodeGen specification. No files are cleaned.
  --release         Use Release instead of Debug
  --device          Signed generic iOS device build, using automatic signing
  --device UDID     Signed build targeting one connected device (find its
                    UDID with `xcrun xctrace list devices`)
  --simulator UUID  Build for a specific simulator (unsigned)
  --run             Install and launch on that simulator or device
  -h, --help        Show this help

Default: unsigned generic iOS simulator Debug build.
Outputs: .build/ios/{simulator,device}/{Debug,Release}/Products/
--run with --simulator UUID: boots it, sets its location to HKW
(52.51889, 13.36528), installs, and launches, via simctl.
--run with --device UDID: installs and launches on the physical device via
devicectl. Uses the device's real location; no location spoofing there.
Location permission is still controlled by iOS in both cases.
Device builds require the existing team signing credentials and profile,
and (for --run) the device already paired and trusted over USB or Wi-Fi.
This script does not archive, export, upload, or change provisioning settings.
HELP
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release) CONFIGURATION=Release; shift ;;
        --device)
            PLATFORM=device
            if [[ $# -ge 2 && "$2" != --* ]]; then DEVICE_ID="$2"; shift 2; else shift; fi
            ;;
        --simulator)
            [[ $# -ge 2 && "$2" != --* ]] || { echo '--simulator requires a UUID' >&2; exit 2; }
            SIMULATOR_ID="$2"; shift 2 ;;
        --run) RUN=true; shift ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
done

if [[ "$PLATFORM" == device && -n "$SIMULATOR_ID" ]]; then
    echo '--device cannot be combined with --simulator' >&2
    exit 2
fi
if [[ "$RUN" == true && -z "$SIMULATOR_ID" && -z "$DEVICE_ID" ]]; then
    echo '--run requires --simulator UUID or --device UDID' >&2
    exit 2
fi
for tool in xcodegen xcodebuild xcrun; do
    command -v "$tool" >/dev/null || { echo "Required tool missing: $tool" >&2; exit 1; }
done

cd -- "$REPO_DIR"
xcodegen generate
BUILD_DIR="${REPO_DIR}/.build/ios/${PLATFORM}/${CONFIGURATION}"
ARGS=(
    -project DashboardOfDoom.xcodeproj -scheme DashboardOfDoom-iOS
    -configuration "$CONFIGURATION" -derivedDataPath "${BUILD_DIR}/DerivedData"
    -disableAutomaticPackageResolution
    "SYMROOT=${BUILD_DIR}/Products" "OBJROOT=${BUILD_DIR}/Intermediates"
)
if [[ "$PLATFORM" == device ]]; then
    DESTINATION='generic/platform=iOS'
    if [[ -n "$DEVICE_ID" ]]; then DESTINATION="id=${DEVICE_ID}"; fi
    ARGS+=(-destination "$DESTINATION")
else
    DESTINATION='generic/platform=iOS Simulator'
    if [[ -n "$SIMULATOR_ID" ]]; then DESTINATION="platform=iOS Simulator,id=${SIMULATOR_ID}"; fi
    ARGS+=(-destination "$DESTINATION" CODE_SIGNING_ALLOWED=NO)
fi
xcodebuild "${ARGS[@]}" build

if [[ "$RUN" == true && -n "$SIMULATOR_ID" ]]; then
    # bootstatus -b boots a shutdown device and waits for launch services.
    xcrun simctl bootstatus "$SIMULATOR_ID" -b
    xcrun simctl location "$SIMULATOR_ID" set 52.51889,13.36528
    xcrun simctl install "$SIMULATOR_ID" "${BUILD_DIR}/Products/${CONFIGURATION}-iphonesimulator/Dashboard of Doom.app"
    xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" com.panjas.dashboard-of-doom
elif [[ "$RUN" == true && -n "$DEVICE_ID" ]]; then
    xcrun devicectl device install app --device "$DEVICE_ID" "${BUILD_DIR}/Products/${CONFIGURATION}-iphoneos/Dashboard of Doom.app"
    xcrun devicectl device process launch --terminate-existing --device "$DEVICE_ID" com.panjas.dashboard-of-doom
fi
