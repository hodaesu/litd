#!/usr/bin/env python3
"""Deterministic critical-context identity for governance receipts.

A receipt is stale when the critical governance context at consumption no longer
matches the context captured at registration. The context intentionally binds
Core state, canonical targets, Guardian rules, and the governance contract.
"""
from __future__ import annotations

import json
from hashlib import sha256
from typing import Any

PROJECT_ID = "LITD"
TARGET_ROUTE = "LITD_LIBRARY"
HEX64 = set("0123456789abcdef")
REQUIRED_COMPONENTS = (
    "core_state_hash",
    "target_registry_hash",
    "guardian_rules_hash",
    "governance_contract_hash",
)


def _hex64(value: Any) -> bool:
    return isinstance(value, str) and len(value) == 64 and all(ch in HEX64 for ch in value)


def compute_context_hash(
    components: dict[str, Any],
    *,
    project_id: str = PROJECT_ID,
    target_route: str = TARGET_ROUTE,
) -> str:
    if project_id != PROJECT_ID:
        raise ValueError("context project scope mismatch")
    if target_route != TARGET_ROUTE:
        raise ValueError("context route scope mismatch")
    if not isinstance(components, dict):
        raise ValueError("context components must be an object")
    missing = [key for key in REQUIRED_COMPONENTS if key not in components]
    if missing:
        raise ValueError("missing critical context components:" + ",".join(missing))
    unknown = sorted(set(components) - set(REQUIRED_COMPONENTS))
    if unknown:
        raise ValueError("unknown critical context components:" + ",".join(unknown))
    for key in REQUIRED_COMPONENTS:
        if not _hex64(components[key]):
            raise ValueError(f"{key} must be 64 lowercase hex")
    payload = {
        "project_id": project_id,
        "target_route": target_route,
        "components": {key: components[key] for key in REQUIRED_COMPONENTS},
    }
    raw = json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
    return sha256(raw.encode("utf-8")).hexdigest()
