#!/usr/bin/env python3

"""Check XcodeGen prerequisites and generate a project from project.yml."""

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


class ArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        raise ValueError(message)


def report(status, action, detail, json_output):
    if json_output:
        print(json.dumps({"status": status, "action": action, "detail": detail}))
    else:
        stream = sys.stderr if status == "error" else sys.stdout
        print(f"{status}: {detail}", file=stream)


def run_command(command, project_root, json_output):
    try:
        result = subprocess.run(
            command,
            cwd=project_root,
            stdout=sys.stderr if json_output else None,
            check=False,
        )
    except OSError as error:
        print(error, file=sys.stderr)
        return False
    return result.returncode == 0


def main(argv):
    json_output = "--json" in argv
    parser = ArgumentParser(description=__doc__, allow_abbrev=False)
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--check", action="store_true", help="Check without generating a project.")
    actions.add_argument(
        "--install", action="store_true", help="Install xcodegen with Homebrew if missing."
    )
    parser.add_argument(
        "--project-root", default=os.getcwd(), metavar="DIR",
        help="Project root containing project.yml (default: current directory).",
    )
    parser.add_argument("--json", action="store_true", help="Print one JSON result on stdout.")

    try:
        args = parser.parse_args(argv)
    except ValueError as error:
        requested_action = next(
            ("check" if arg == "--check" else "install"
             for arg in argv if arg in ("--check", "--install")),
            "init",
        )
        report("error", requested_action, str(error), json_output)
        return 2

    action = "check" if args.check else "install" if args.install else "init"
    project_root = Path(args.project_root).expanduser().resolve()
    if not project_root.is_dir():
        report("error", action, f"Project root does not exist: {project_root}", args.json)
        return 1
    if not (project_root / "project.yml").is_file():
        report("error", action, "project.yml is missing from the project root", args.json)
        return 1

    if shutil.which("xcodegen") is None and args.install:
        if shutil.which("brew") is None:
            report("error", action, "Homebrew is required to install xcodegen", args.json)
            return 1
        if not args.json:
            report("running", action, "installing xcodegen with Homebrew", False)
        if not run_command(["brew", "install", "xcodegen"], project_root, args.json):
            report("error", action, "Homebrew failed to install xcodegen", args.json)
            return 1

    if shutil.which("xcodegen") is None:
        report("error", action, "xcodegen is missing; install it with brew install xcodegen", args.json)
        return 1
    if args.check:
        report("ok", action, "xcodegen and project.yml are available", args.json)
        return 0

    if not run_command(["xcodegen", "generate"], project_root, args.json):
        report("error", action, "xcodegen failed to generate the project", args.json)
        return 1
    report("ok", action, "Xcode project generated", args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
