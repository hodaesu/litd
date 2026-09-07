#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import importlib.util
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "tools/godot/veilleurs_content_intake.py"
CONTRACT_PATH = ROOT / "data/veilleurs/content_intake_contract.json"
EXPECTED_TYPES = {"watcher", "enemy", "boss", "dungeon", "ui_screen", "ultimate", "generic"}
CANONICAL_GUARDS = [
    ROOT / "data/veilleurs/v06/watchers.json",
    ROOT / "data/veilleurs/v06/enemies_24_definitions.json",
    ROOT / "data/veilleurs/v07/bosses_5_definitions.json",
    ROOT / "data/veilleurs/v09/wave3_contract.json",
    ROOT / "data/veilleurs/v08/canonical_watcher_ultimates_12.json",
]


def load_module():
    spec = importlib.util.spec_from_file_location("veilleurs_content_intake", MODULE_PATH)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load content intake generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expect_failure(errors: list[str], label: str, fn) -> None:
    try:
        fn()
    except ValueError:
        return
    errors.append(f"{label}: expected ValueError")


def main() -> int:
    module = load_module()
    errors: list[str] = []
    contract = module.load_contract(CONTRACT_PATH)
    types = set(contract.get("supported_types", {}))
    if types != EXPECTED_TYPES:
        errors.append(f"supported types mismatch: {sorted(types)}")

    rules = contract.get("rules", {})
    required_rules = {
        "presentation_never_decides_gameplay",
        "reservation_never_mutates_canonical_gameplay",
        "work_order_presence_reserves_id",
        "duplicate_canonical_ids_forbidden",
        "duplicate_reserved_ids_forbidden",
        "path_traversal_forbidden",
    }
    if not required_rules.issubset(rules):
        errors.append("intake safety rules incomplete")

    before = {path: digest(path) for path in CANONICAL_GUARDS if path.exists()}
    previews = {}
    for index, content_type in enumerate(sorted(EXPECTED_TYPES)):
        display = f"Audit Intake Unique {content_type} {index}"
        try:
            order = module.build_work_order(content_type, display, contract=contract)
        except Exception as exc:  # audit should report, not crash
            errors.append(f"preview failed for {content_type}: {exc}")
            continue
        previews[content_type] = order
        prefix = contract["supported_types"][content_type]["id_prefix"]
        if not order.get("canonical_id", "").startswith(prefix):
            errors.append(f"wrong prefix for {content_type}: {order.get('canonical_id')}")
        if order.get("state") != "intake_reserved":
            errors.append(f"wrong initial state for {content_type}")
        if order.get("constraints", {}).get("canonical_gameplay_mutated_by_intake") is not False:
            errors.append(f"intake mutation guard absent for {content_type}")
        if not order.get("validation", {}).get("required_tests"):
            errors.append(f"no tests planned for {content_type}")
        if not order.get("validation", {}).get("required_gates"):
            errors.append(f"no gates planned for {content_type}")

    generic = previews.get("generic", {})
    if generic.get("constraints", {}).get("cannot_canonicalize") is not True:
        errors.append("generic intake must require type refinement")

    expect_failure(
        errors,
        "existing canonical watcher collision",
        lambda: module.build_work_order(
            "watcher", "Nayra collision", explicit_id="ENT_WATCHER_NAYRA", contract=contract
        ),
    )
    expect_failure(
        errors,
        "wrong prefix",
        lambda: module.build_work_order(
            "enemy", "Wrong Prefix", explicit_id="ENT_BOSS_WRONG_PREFIX", contract=contract
        ),
    )
    expect_failure(
        errors,
        "path traversal / unsafe id",
        lambda: module.build_work_order(
            "boss", "Unsafe", explicit_id="ENT_BOSS_../../UNSAFE", contract=contract
        ),
    )

    with tempfile.TemporaryDirectory(prefix="veilleurs-intake-") as tmp:
        work_root = Path(tmp) / "work_orders"
        order = module.build_work_order(
            "enemy",
            "Audit Reservation Collision Unique",
            contract=contract,
            work_order_root=work_root,
        )
        path = module.reserve_work_order(order, work_root)
        if not path.exists():
            errors.append("reservation did not create work order")
        expect_failure(errors, "double reservation", lambda: module.reserve_work_order(order, work_root))
        expect_failure(
            errors,
            "reserved id collision",
            lambda: module.build_work_order(
                "enemy",
                "Audit Reservation Collision Unique",
                explicit_id=order["canonical_id"],
                contract=contract,
                work_order_root=work_root,
            ),
        )

    after = {path: digest(path) for path in before}
    if before != after:
        errors.append("content intake modified canonical gameplay files")

    if errors:
        print("VEILLEURS_CONTENT_INTAKE_AUDIT_FAILED")
        for error in errors:
            print("ERROR:", error)
        return 1

    print("VEILLEURS_CONTENT_INTAKE_AUDIT_OK")
    print("7 types; deterministic IDs; canonical collision and reservation guards verified.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
