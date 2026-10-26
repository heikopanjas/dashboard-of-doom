#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
PROJECT="DashboardOfDoom.xcodeproj"
SCHEME="DashboardOfDoom"
APP_NAME="Dashboard of Doom"
BUILD_DIR="${REPO_DIR}/.build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
EXPORT_PLIST="${SCRIPT_DIR}/exportOptions.plist"
NOTARIZE_PROFILE="${NOTARIZE_PROFILE:-DashboardOfDoom-Notarize}"
ZIP_PATH="${BUILD_DIR}/${APP_NAME}.zip"
RESULT_PATH="${BUILD_DIR}/notarization-result.plist"

CLEAN=false
RELEASE=false
NOTARIZE=false

usage() {
    cat <<'HELP'
Usage: ./macos/build.sh [--clean] [--release] [--notarize]

No arguments builds a signed Debug app.

Options:
    --clean       Delete root .build/, Build/, and legacy build/ outputs
                  Without another build option, exit after cleaning
    --release     Build a signed Release app
    --notarize    Archive Release, export, notarize, staple, and verify
    -h, --help    Show this help message

Examples:
    ./macos/build.sh                       # Debug build
    ./macos/build.sh --clean                # Clean only
    ./macos/build.sh --release              # Release build
    ./macos/build.sh --clean --release      # Clean, then build Release
    ./macos/build.sh --notarize             # Notarized distribution archive
    ./macos/build.sh --clean --notarize     # Clean, then archive and notarize

Outputs: .build/Products/Debug or Release, .build/export, and .build/*.zip
Notarization credentials: Keychain profile DashboardOfDoom-Notarize
Override the profile with the NOTARIZE_PROFILE environment variable.
HELP
}

for arg in "$@"; do
    case "$arg" in
        --clean) CLEAN=true ;;
        --release) RELEASE=true ;;
        --notarize) NOTARIZE=true ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$arg" >&2; usage >&2; exit 2 ;;
    esac
done

cd -- "$REPO_DIR"

if [[ "$CLEAN" == true ]]; then
    echo "==> Removing build products, intermediates, archives, and exports..."
    # Fixed, repository-local paths. Do not remove package sources or lockfiles.
    rm -rf -- "$BUILD_DIR" "${REPO_DIR}/Build" "${REPO_DIR}/build"
    if [[ "$RELEASE" == false && "$NOTARIZE" == false ]]; then
        echo "==> Clean complete"
        exit 0
    fi
fi

for tool in xcodegen xcodebuild; do
    command -v "$tool" >/dev/null || { echo "Required tool missing: $tool" >&2; exit 1; }
done

if [[ "$NOTARIZE" == true ]]; then
    for tool in xcrun ditto plutil spctl; do
        command -v "$tool" >/dev/null || { echo "Required tool missing: $tool" >&2; exit 1; }
    done
    [[ -f "$EXPORT_PLIST" ]] || { echo "Missing export options: $EXPORT_PLIST" >&2; exit 1; }
fi

xcodegen generate
mkdir -p "$BUILD_DIR"

# Keep common arguments separate from action-specific build locations.
BUILD_ARGS=(
    -project "$PROJECT"
    -scheme "$SCHEME"
    -destination 'generic/platform=macOS'
    -derivedDataPath "${BUILD_DIR}/DerivedData"
    -disableAutomaticPackageResolution
)

if [[ "$NOTARIZE" == false ]]; then
    CONFIGURATION=Debug
    if [[ "$RELEASE" == true ]]; then
        CONFIGURATION=Release
    fi
    echo "==> Building ${CONFIGURATION}..."
    xcodebuild "${BUILD_ARGS[@]}" \
        "SYMROOT=${BUILD_DIR}/Products" \
        "OBJROOT=${BUILD_DIR}/Intermediates" \
        -configuration "$CONFIGURATION" build
    echo "==> Build complete: ${BUILD_DIR}/Products/${CONFIGURATION}/${APP_NAME}.app"
    exit 0
fi

echo "==> Archiving Release..."
rm -rf -- "$ARCHIVE_PATH"
# Override location preferences, not SYMROOT/OBJROOT: archive must derive its
# own BuildProductsPath and IntermediateBuildFilesPath beneath these roots.
xcodebuild "${BUILD_ARGS[@]}" \
    -IDECustomBuildLocationType=Absolute \
    "-IDECustomBuildProductsPath=${BUILD_DIR}/Products" \
    "-IDECustomBuildIntermediatesPath=${BUILD_DIR}/Intermediates" \
    -configuration Release -archivePath "$ARCHIVE_PATH" archive

echo "==> Exporting with Developer ID signing..."
rm -rf -- "$EXPORT_PATH"
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST"

EXPORTED_APP="${EXPORT_PATH}/${APP_NAME}.app"
echo "==> Creating ZIP for notarization..."
rm -f -- "$ZIP_PATH" "$RESULT_PATH"
ditto -c -k --keepParent "$EXPORTED_APP" "$ZIP_PATH"

echo "==> Submitting for notarization..."
if xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$NOTARIZE_PROFILE" \
    --wait --output-format plist > "$RESULT_PATH"; then
    STATUS=$(plutil -extract status raw -o - "$RESULT_PATH")
else
    cat "$RESULT_PATH" >&2
    echo "Notarization failed. Submission output: $RESULT_PATH" >&2
    exit 1
fi

if [[ "$STATUS" != Accepted ]]; then
    cat "$RESULT_PATH" >&2
    echo "Notarization was not accepted. Submission output: $RESULT_PATH" >&2
    exit 1
fi

echo "==> Stapling and verifying..."
xcrun stapler staple "$EXPORTED_APP"
xcrun stapler validate "$EXPORTED_APP"
spctl --assess --type execute --verbose "$EXPORTED_APP"

# Repackage after stapling so the distributable ZIP contains the ticket.
rm -f -- "$ZIP_PATH"
ditto -c -k --keepParent "$EXPORTED_APP" "$ZIP_PATH"
echo "==> Notarization complete: $EXPORTED_APP"
echo "==> Distribution ZIP: $ZIP_PATH"
