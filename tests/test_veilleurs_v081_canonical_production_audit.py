from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIT = ROOT / "tools" / "qa" / "veilleurs_v081_canonical_production_audit.py"


def test_v081_canonical_production_audit() -> None:
    result = subprocess.run(
        [sys.executable, str(AUDIT)],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert "VEILLEURS_V081_CANONICAL_AUDIT_OK" in result.stdout
