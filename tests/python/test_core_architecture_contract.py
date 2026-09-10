from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
CORE_DIR = ROOT / "scripts" / "core"
CONTRACT = ROOT / "docs" / "architecture" / "CORE_CONTRACT.md"


def test_core_contract_document_exists_and_declares_v1_invariants() -> None:
    text = CONTRACT.read_text(encoding="utf-8")
    for invariant in range(1, 11):
        marker = f"CORE-INV-{invariant:03d}"
        assert marker in text, f"missing {marker} from Core contract"


def test_core_does_not_depend_on_ui_layer() -> None:
    forbidden = (
        "res://scripts/ui/",
        '"scripts/ui/',
        "'scripts/ui/",
    )
    violations: list[str] = []

    for path in sorted(CORE_DIR.glob("*.gd")):
        text = path.read_text(encoding="utf-8")
        for needle in forbidden:
            if needle in text:
                violations.append(f"{path.relative_to(ROOT)} -> {needle}")

    assert not violations, (
        "scripts/core must not depend directly on scripts/ui; "
        "use a signal/interface/adapter or document an explicit ADR exception:\n"
        + "\n".join(violations)
    )
