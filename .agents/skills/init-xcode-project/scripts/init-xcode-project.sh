#!/usr/bin/env bash

set -euo pipefail

PROJECT_ROOT="$PWD"
ACTION="init"
JSON_OUTPUT=false

for ARG in "$@"; do
    if [[ "$ARG" == "--json" ]]; then
        JSON_OUTPUT=true
    fi
done

usage() {
    cat <<'EOF'
Usage: init-xcode-project.sh [--check | --install] [--project-root DIR] [--json]

Prepare an Xcode project using project.yml in the project root.
  --check   Check local prerequisites without generating the project.
  --install Install xcodegen with Homebrew if missing, then generate the project.
  --project-root DIR  Use DIR instead of the current directory as the project root.
  --json    Print one JSON result object for automation.
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
    local status="$1" action="$2" detail="$3"
    if [[ "$JSON_OUTPUT" == true ]]; then
        printf '{"status":"%s","action":"%s","detail":"%s"}\n' \
            "$status" "$action" "$(json_escape "$detail")"
    elif [[ "$status" == "error" ]]; then
        printf '%s: %s\n' "$status" "$detail" >&2
    else
        printf '%s: %s\n' "$status" "$detail"
    fi
}

fail() {
    report 'error' "$ACTION" "$1"
    exit "${2:-1}"
}

while (($#)); do
    case "$1" in
        --check)
            if [[ "$ACTION" != "init" ]]; then
                fail 'Options --check and --install cannot be used together' 2
            fi
            ACTION="check"
            shift
            ;;
        --install)
            if [[ "$ACTION" != "init" ]]; then
                fail 'Options --check and --install cannot be used together' 2
            fi
            ACTION="install"
            shift
            ;;
        --project-root)
            if (($# < 2)); then
                fail 'Option --project-root requires a directory' 2
            fi
            PROJECT_ROOT="$2"
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

install_xcodegen_if_needed() {
    if command -v xcodegen >/dev/null 2>&1; then
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        report 'error' 'install' 'Homebrew is required to install xcodegen'
        return 1
    fi

    if [[ "$JSON_OUTPUT" == true ]]; then
        if brew install xcodegen >&2; then
            return 0
        fi
    else
        report 'running' 'install' 'installing xcodegen with Homebrew'
        if brew install xcodegen; then
            return 0
        fi
    fi

    report 'error' 'install' 'Homebrew failed to install xcodegen'
    return 1
}

check_prerequisites() {
    if ! command -v xcodegen >/dev/null 2>&1; then
        report 'error' "$ACTION" 'xcodegen is missing; install it with brew install xcodegen'
        return 1
    fi

    if [[ ! -f "$PROJECT_ROOT/project.yml" ]]; then
        report 'error' "$ACTION" 'project.yml is missing from the project root'
        return 1
    fi

}

if [[ "$ACTION" == "install" ]]; then
    install_xcodegen_if_needed
fi

check_prerequisites

if [[ "$ACTION" == "check" ]]; then
    report 'ok' "$ACTION" 'xcodegen and project.yml are available'
    exit 0
fi

cd "$PROJECT_ROOT"
if [[ "$JSON_OUTPUT" == true ]]; then
    if xcodegen generate >&2; then
        report 'ok' "$ACTION" 'Xcode project generated'
    else
        report 'error' "$ACTION" 'xcodegen failed to generate the project'
        exit 1
    fi
elif xcodegen generate; then
    report 'ok' "$ACTION" 'Xcode project generated'
else
    report 'error' "$ACTION" 'xcodegen failed to generate the project'
    exit 1
fi
