#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<'EOF'
Usage: scripts/init-xcode-project.sh [--check | --install] [--json]

Prepare the Xcode project using the repository's project.yml.
  --check   Check local prerequisites without generating the project.
  --install Install xcodegen with Homebrew if missing, then generate the project.
  --json    Print one JSON result object for automation.
  -h, --help  Show this help.
EOF
}

ACTION="init"
JSON_OUTPUT=false

for ARG in "$@"; do
    case "$ARG" in
        --check)
            if [[ "$ACTION" != "init" ]]; then
                printf 'Options --check and --install cannot be used together.\n' >&2
                usage >&2
                exit 2
            fi
            ACTION="check"
            ;;
        --install)
            if [[ "$ACTION" != "init" ]]; then
                printf 'Options --check and --install cannot be used together.\n' >&2
                usage >&2
                exit 2
            fi
            ACTION="install"
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

report() {
    local status="$1"
    local action="$2"
    local detail="$3"

    if [[ "$JSON_OUTPUT" == true ]]; then
        printf '{"status":"%s","action":"%s","detail":"%s"}\n' \
            "$status" "$action" "$detail"
    else
        printf '%s: %s\n' "$status" "$detail"
    fi
}

install_xcodegen_if_needed() {
    if command -v xcodegen >/dev/null 2>&1; then
        return
    fi

    if ! command -v brew >/dev/null 2>&1; then
        report 'error' 'install' 'Homebrew is required to install xcodegen' >&2
        return 1
    fi

    if [[ "$JSON_OUTPUT" == true ]]; then
        brew install xcodegen >&2
    else
        report 'running' 'install' 'installing xcodegen with Homebrew'
        brew install xcodegen
    fi
}

check_prerequisites() {
    if ! command -v xcodegen >/dev/null 2>&1; then
        report 'error' "$ACTION" 'xcodegen is missing; install it with brew install xcodegen' >&2
        return 1
    fi

    if [[ ! -f "$ROOT_DIR/project.yml" ]]; then
        report 'error' "$ACTION" 'project.yml is missing from the repository root' >&2
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

cd "$ROOT_DIR"
if [[ "$JSON_OUTPUT" == true ]]; then
    if xcodegen generate >&2; then
        report 'ok' "$ACTION" 'Xcode project generated'
    else
        report 'error' "$ACTION" 'xcodegen failed to generate the project' >&2
        exit 1
    fi
elif xcodegen generate; then
    report 'ok' "$ACTION" 'Xcode project generated'
else
    report 'error' "$ACTION" 'xcodegen failed to generate the project' >&2
    exit 1
fi
