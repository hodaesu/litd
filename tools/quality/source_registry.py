#!/usr/bin/env python3
"""Validation helpers for the Veilleur autonomous source registry.

The registry is deliberately conservative: only explicitly enabled, primary,
HTTPS sources with an exact host match can be fetched automatically.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

TRUSTED = {"TRUSTED_PRIMARY"}
SUPPORTED_FORMATS = {"rss", "atom"}


def load_registry(path: str | Path) -> dict[str, Any]:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def validate_registry(registry: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    if registry.get("kind") != "LITD_VEILLEUR_SOURCE_REGISTRY":
        errors.append("invalid_kind")
    if registry.get("version") != 1:
        errors.append("invalid_version")
    policy = registry.get("policy")
    if not isinstance(policy, dict):
        errors.append("missing_policy")
    else:
        if policy.get("core_write_allowed") is not False:
            errors.append("core_write_must_be_false")
        if policy.get("automatic_library_write_allowed") is not False:
            errors.append("automatic_library_write_must_be_false")
        if policy.get("unknown_source_action") != "QUARANTINE":
            errors.append("unknown_sources_must_quarantine")
        if policy.get("unverified_source_action") != "QUARANTINE":
            errors.append("unverified_sources_must_quarantine")

    sources = registry.get("sources")
    if not isinstance(sources, list) or not sources:
        return errors + ["sources_missing"]

    seen: set[str] = set()
    for index, source in enumerate(sources):
        prefix = f"source[{index}]"
        if not isinstance(source, dict):
            errors.append(f"{prefix}:not_object")
            continue
        source_id = source.get("source_id")
        if not isinstance(source_id, str) or not source_id.strip():
            errors.append(f"{prefix}:invalid_source_id")
        elif source_id in seen:
            errors.append(f"{prefix}:duplicate_source_id")
        else:
            seen.add(source_id)

        url = source.get("url")
        allowed_host = source.get("allowed_host")
        if not isinstance(url, str):
            errors.append(f"{prefix}:invalid_url")
            continue
        parsed = urlparse(url)
        if parsed.scheme != "https" or not parsed.hostname:
            errors.append(f"{prefix}:https_required")
        if not isinstance(allowed_host, str) or parsed.hostname != allowed_host:
            errors.append(f"{prefix}:host_mismatch")

        enabled = source.get("enabled") is True
        if enabled:
            if source.get("trust") not in TRUSTED:
                errors.append(f"{prefix}:enabled_source_not_trusted")
            if source.get("format") not in SUPPORTED_FORMATS:
                errors.append(f"{prefix}:unsupported_enabled_format")
            item_hosts = source.get("allowed_item_hosts")
            if (not isinstance(item_hosts, list) or not item_hosts
                    or not all(isinstance(x, str) and x.strip() for x in item_hosts)):
                errors.append(f"{prefix}:invalid_allowed_item_hosts")
            elif any(x != x.casefold() for x in item_hosts):
                errors.append(f"{prefix}:allowed_item_hosts_must_be_lowercase")
            hints = source.get("domain_hints")
            if not isinstance(hints, list) or not hints or not all(isinstance(x, str) and x.strip() for x in hints):
                errors.append(f"{prefix}:invalid_domain_hints")
            confidence = source.get("source_confidence")
            if isinstance(confidence, bool) or not isinstance(confidence, (int, float)) or not 0 <= float(confidence) <= 1:
                errors.append(f"{prefix}:invalid_source_confidence")
    return errors


def enabled_sources(registry: dict[str, Any]) -> list[dict[str, Any]]:
    errors = validate_registry(registry)
    if errors:
        raise ValueError("invalid source registry: " + ";".join(errors))
    return [s for s in registry["sources"] if s.get("enabled") is True]


def can_write_core() -> bool:
    return False
