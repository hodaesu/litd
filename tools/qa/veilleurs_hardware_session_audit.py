#!/usr/bin/env python3
from __future__ import annotations

import argparse
import importlib.util
import json
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/workstation/veilleurs_hardware_session.py"


def load_module():
    spec = importlib.util.spec_from_file_location("veilleurs_hardware_session", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load hardware session module")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_module()
    errors: list[str] = []

    with tempfile.TemporaryDirectory() as tmp:
        temp_root = Path(tmp)
        module.REPORT_DIR = temp_root

        init_args = argparse.Namespace(
            session="audit_ios",
            platform="ios",
            device="Audit iPhone",
            os_version="iOS audit",
            build="development",
            force=False,
        )
        if module.command_init(init_args) != 0:
            errors.append("session init failed")

        session_file = temp_root / "audit_ios.json"
        if not session_file.is_file():
            errors.append("session report was not created")
        else:
            report = json.loads(session_file.read_text(encoding="utf-8"))
            applicable = [row for row in report.get("gates", []) if row.get("applicable")]
            if len(applicable) != 8:
                errors.append(f"iOS must expose 8 applicable gates, got {len(applicable)}")

        incomplete_args = argparse.Namespace(
            session_file=str(session_file),
            gate="real_mobile_touch",
            status="pass",
            note="intentional incomplete audit",
            evidence=["device_model=Audit iPhone", "blocking_issue_count=0"],
        )
        if module.command_record(incomplete_args) == 0:
            errors.append("incomplete PASS was incorrectly accepted")
        report = json.loads(session_file.read_text(encoding="utf-8"))
        touch = next(row for row in report["gates"] if row["id"] == "real_mobile_touch")
        if touch.get("status") != "incomplete" or not touch.get("missing_required_evidence"):
            errors.append("incomplete PASS did not preserve missing evidence")

        complete_evidence = [
            "device_model=Audit iPhone",
            "os_version=iOS audit",
            "screen_size=phone",
            "tester_notes=ok",
            "misinput_count=0",
            "blocking_issue_count=0",
        ]
        complete_args = argparse.Namespace(
            session_file=str(session_file),
            gate="real_mobile_touch",
            status="pass",
            note="complete audit",
            evidence=complete_evidence,
        )
        if module.command_record(complete_args) != 0:
            errors.append("complete PASS was rejected")
        report = json.loads(session_file.read_text(encoding="utf-8"))
        touch = next(row for row in report["gates"] if row["id"] == "real_mobile_touch")
        if touch.get("status") != "pass" or touch.get("missing_required_evidence"):
            errors.append("complete PASS did not clear missing evidence")

        status_args = argparse.Namespace(session_file=str(session_file))
        if module.command_status(status_args) == 0:
            errors.append("whole iOS session passed while seven gates remain untested")

    if errors:
        print("VEILLEURS_HARDWARE_SESSION_AUDIT_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_HARDWARE_SESSION_AUDIT_OK")
    print("Incomplete PASS rejected; complete evidence accepted; unfinished session remains blocked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
