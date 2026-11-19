#!/usr/bin/env python3

"""Open a generated Xcode project in the selected Xcode application."""

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


def report(status, detail, json_output):
    if json_output:
        print(json.dumps({"status": status, "action": "open-xcode-project", "detail": detail}))
    else:
        stream = sys.stderr if status == "error" else sys.stdout
        print(f"{status}: {detail}", file=stream)


def main(argv):
    json_output = "--json" in argv
    parser = ArgumentParser(description=__doc__, allow_abbrev=False)
    parser.add_argument("--check", action="store_true", help="Check without opening Xcode.")
    parser.add_argument(
        "--project-root", default=os.getcwd(), metavar="DIR",
        help="Project root (default: current directory).",
    )
    parser.add_argument(
        "--project", metavar="PATH", help="Project path when the root contains multiple projects."
    )
    parser.add_argument("--json", action="store_true", help="Print one JSON result on stdout.")

    try:
        args = parser.parse_args(argv)
    except ValueError as error:
        report("error", str(error), json_output)
        return 2

    project_root = Path(args.project_root).expanduser().resolve()
    if not project_root.is_dir():
        report("error", f"Project root does not exist: {project_root}", args.json)
        return 1

    if args.project:
        project_path = Path(args.project).expanduser()
        if not project_path.is_absolute():
            project_path = project_root / project_path
    else:
        projects = [path for path in project_root.glob("*.xcodeproj") if path.is_dir()]
        if not projects:
            report("error", "No .xcodeproj found in the project root; run init-xcode-project.py first", args.json)
            return 1
        if len(projects) > 1:
            report("error", "Multiple .xcodeproj files found; select one with --project PATH", args.json)
            return 1
        project_path = projects[0]

    if not project_path.is_dir() or not (project_path / "project.pbxproj").is_file():
        report("error", f"Xcode project is missing or incomplete: {project_path}", args.json)
        return 1
    if shutil.which("open") is None:
        report("error", "macOS open command is unavailable; run this script on macOS", args.json)
        return 1
    if shutil.which("xcode-select") is None:
        report("error", "xcode-select is unavailable; install Xcode command line tools or Xcode", args.json)
        return 1

    environment = os.environ.copy()
    environment.pop("DEVELOPER_DIR", None)
    try:
        selected = subprocess.run(
            ["xcode-select", "-p"], env=environment, capture_output=True, text=True,
            errors="replace", check=False,
        )
    except OSError:
        selected = None
    if selected is None or selected.returncode != 0:
        report("error", "No active Xcode developer directory; install Xcode and select it with xcode-select", args.json)
        return 1

    developer_path = Path(selected.stdout.strip())
    if developer_path.name != "Developer" or developer_path.parent.name != "Contents":
        report("error", "The selected developer directory is not inside a full Xcode.app; select Xcode with xcode-select", args.json)
        return 1
    xcode_app = developer_path.parent.parent
    if not xcode_app.is_dir() or not os.access(xcode_app / "Contents/MacOS/Xcode", os.X_OK):
        report("error", "The selected Xcode.app is missing or incomplete; check xcode-select -p", args.json)
        return 1

    if args.check:
        report("ok", "Xcode project and selected Xcode.app are available", args.json)
        return 0

    try:
        opened = subprocess.run(
            ["open", "-a", str(xcode_app), str(project_path)],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            errors="replace", check=False,
        )
    except OSError as error:
        report("error", f"Could not send the project to the selected Xcode.app: {error}", args.json)
        return 1
    if opened.returncode != 0:
        detail = "; ".join(opened.stdout.splitlines())
        report("error", f"Could not send the project to the selected Xcode.app: {detail}", args.json)
        return 1

    report("ok", "Open request sent to the selected Xcode.app", args.json)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
