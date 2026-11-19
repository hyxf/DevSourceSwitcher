#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$PWD"
PROJECT_ARGUMENT=""
JSON_OUTPUT=false
CHECK_ONLY=false
XCODE_APP=""

for ARG in "$@"; do
    if [[ "$ARG" == "--json" ]]; then
        JSON_OUTPUT=true
    fi
done

usage() {
    cat <<'EOF'
Usage: open-xcode-project.sh [--check] [--project-root DIR] [--project PATH] [--json]

Open an Xcode project in the locally selected Xcode application.
  --check   Verify the .xcodeproj and selected Xcode installation without opening it.
  --project-root DIR  Use DIR instead of the current directory as the project root.
  --project PATH  Select a project when the root contains multiple .xcodeproj files.
  --json    Print a machine-readable result object.
  -h, --help  Show this help.
EOF
}

json_escape() {
    local LC_ALL=C input="$1" output="" char code escaped i
    for ((i = 0; i < ${#input}; i++)); do
        char="${input:i:1}"
        case "$char" in
            '"') output+='\"' ;;
            '\') output+='\\' ;;
            *)
                printf -v code '%d' "'$char"
                if ((code < 32)); then
                    printf -v escaped '\\u%04x' "$code"
                    output+="$escaped"
                else
                    output+="$char"
                fi
                ;;
        esac
    done
    printf '%s' "$output"
}

report() {
    local status="$1" detail="$2"
    if [[ "$JSON_OUTPUT" == true ]]; then
        printf '{"status":"%s","action":"open-xcode-project","detail":"%s"}\n' \
            "$status" "$(json_escape "$detail")"
    elif [[ "$status" == "error" ]]; then
        printf '%s: %s\n' "$status" "$detail" >&2
    else
        printf '%s: %s\n' "$status" "$detail"
    fi
}

fail() {
    report 'error' "$1"
    exit "${2:-1}"
}

while (($#)); do
    case "$1" in
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --project-root)
            if (($# < 2)); then
                fail 'Option --project-root requires a directory' 2
            fi
            PROJECT_ROOT="$2"
            shift 2
            ;;
        --project)
            if (($# < 2)); then
                fail 'Option --project requires a path' 2
            fi
            PROJECT_ARGUMENT="$2"
            shift 2
            ;;
        --json)
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown option: $1" 2
            ;;
    esac
done

if [[ ! -d "$PROJECT_ROOT" ]]; then
    fail "Project root does not exist: $PROJECT_ROOT"
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"

if [[ -n "$PROJECT_ARGUMENT" ]]; then
    if [[ "$PROJECT_ARGUMENT" == /* ]]; then
        PROJECT_PATH="$PROJECT_ARGUMENT"
    else
        PROJECT_PATH="$PROJECT_ROOT/$PROJECT_ARGUMENT"
    fi
else
    shopt -s nullglob
    PROJECTS=("$PROJECT_ROOT"/*.xcodeproj)
    shopt -u nullglob
    if ((${#PROJECTS[@]} == 0)); then
        fail 'No .xcodeproj found in the project root; run init-xcode-project.sh first'
    fi
    if ((${#PROJECTS[@]} > 1)); then
        fail 'Multiple .xcodeproj files found; select one with --project PATH'
    fi
    PROJECT_PATH="${PROJECTS[0]}"
fi

if [[ ! -d "$PROJECT_PATH" || ! -f "$PROJECT_PATH/project.pbxproj" ]]; then
    fail "Xcode project is missing or incomplete: $PROJECT_PATH"
fi

if ! command -v open >/dev/null 2>&1; then
    fail 'macOS open command is unavailable; run this script on macOS'
fi

if ! command -v xcode-select >/dev/null 2>&1; then
    fail 'xcode-select is unavailable; install Xcode command line tools or Xcode'
fi
if ! DEVELOPER_PATH="$(DEVELOPER_DIR= xcode-select -p 2>/dev/null)"; then
    fail 'No active Xcode developer directory; install Xcode and select it with xcode-select'
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
