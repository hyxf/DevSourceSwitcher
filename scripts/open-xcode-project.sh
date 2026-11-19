#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/DevSourceSwitcher.xcodeproj"
JSON_OUTPUT=false
CHECK_ONLY=false
XCODE_APP=""

usage() {
    cat <<'EOF'
Usage: scripts/open-xcode-project.sh [--check] [--json]

Open this repository's Xcode project in the locally selected Xcode application.
  --check   Verify the .xcodeproj and selected Xcode installation without opening it.
  --json    Print a machine-readable result object.
  -h, --help  Show this help.
EOF
}

report() {
    local status="$1"
    local detail="$2"

    if [[ "$JSON_OUTPUT" == true ]]; then
        detail="${detail//\\/\\\\}"
        detail="${detail//\"/\\\"}"
        detail="${detail//$'\n'/\\n}"
        printf '{"status":"%s","action":"open-xcode-project","detail":"%s"}\n' \
            "$status" "$detail"
    else
        printf '%s: %s\n' "$status" "$detail"
    fi
}

fail() {
    report 'error' "$1" >&2
    exit 1
}

for ARG in "$@"; do
    case "$ARG" in
        --check)
            CHECK_ONLY=true
            ;;
        --json)
            JSON_OUTPUT=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$ARG" >&2
            usage >&2
            exit 2
            ;;
    esac
done

if [[ ! -d "$PROJECT_PATH" || ! -f "$PROJECT_PATH/project.pbxproj" ]]; then
    fail 'Xcode project is missing; run scripts/init-xcode-project.sh first'
fi

if ! command -v open >/dev/null 2>&1; then
    fail 'macOS open command is unavailable; run this script on macOS'
fi

if [[ -n "${DEVELOPER_DIR:-}" ]]; then
    DEVELOPER_PATH="$DEVELOPER_DIR"
else
    if ! command -v xcode-select >/dev/null 2>&1; then
        fail 'xcode-select is unavailable; install Xcode command line tools or Xcode'
    fi
    if ! DEVELOPER_PATH="$(xcode-select -p 2>/dev/null)"; then
        fail 'No active Xcode developer directory; install Xcode and select it with xcode-select'
    fi
fi

case "$DEVELOPER_PATH" in
    */Contents/Developer)
        XCODE_APP="${DEVELOPER_PATH%/Contents/Developer}"
        ;;
    *)
        fail 'The selected developer directory is not inside a full Xcode.app; select Xcode with xcode-select'
        ;;
esac

if [[ ! -d "$XCODE_APP" || ! -x "$XCODE_APP/Contents/MacOS/Xcode" ]]; then
    fail 'The selected Xcode.app is missing or incomplete; check xcode-select -p'
fi

if [[ "$CHECK_ONLY" == true ]]; then
    report 'ok' 'Xcode project and selected Xcode.app are available'
    exit 0
fi

if OPEN_ERROR="$(open -a "$XCODE_APP" "$PROJECT_PATH" 2>&1)"; then
    report 'ok' 'Open request sent to the selected Xcode.app'
else
    OPEN_ERROR="${OPEN_ERROR//$'\n'/; }"
    fail "Could not send the project to the selected Xcode.app: $OPEN_ERROR"
fi
