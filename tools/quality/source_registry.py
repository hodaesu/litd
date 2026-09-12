#!/usr/bin/env python3
"""Validation helpers for the Veilleur autonomous source registry."""
from __future__ import annotations
import json
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
TRUSTED={"TRUSTED_PRIMARY"}
SUPPORTED_FORMATS={"rss","atom"}
def load_registry(path:str|Path)->dict[str,Any]: return json.loads(Path(path).read_text(encoding="utf-8"))
def validate_registry(registry:dict[str,Any])->list[str]:
    errors=[]
    if registry.get("kind")!="LITD_VEILLEUR_SOURCE_REGISTRY": errors.append("invalid_kind")
    if registry.get("version")!=1: errors.append("invalid_version")
    policy=registry.get("policy")
    if not isinstance(policy,dict): errors.append("missing_policy")
    else:
        if policy.get("core_write_allowed") is not False: errors.append("core_write_must_be_false")
        if policy.get("automatic_library_write_allowed") is not False: errors.append("automatic_library_write_must_be_false")
        if policy.get("unknown_source_action")!="QUARANTINE": errors.append("unknown_sources_must_quarantine")
        if policy.get("unverified_source_action")!="QUARANTINE": errors.append("unverified_sources_must_quarantine")
    sources=registry.get("sources")
    if not isinstance(sources,list) or not sources: return errors+["sources_missing"]
    seen=set()
    for i,source in enumerate(sources):
        p=f"source[{i}]"
        if not isinstance(source,dict): errors.append(f"{p}:not_object"); continue
        sid=source.get("source_id")
        if not isinstance(sid,str) or not sid.strip(): errors.append(f"{p}:invalid_source_id")
        elif sid in seen: errors.append(f"{p}:duplicate_source_id")
        else: seen.add(sid)
        url=source.get("url"); host=source.get("allowed_host")
        if not isinstance(url,str): errors.append(f"{p}:invalid_url"); continue
        parsed=urlparse(url)
        if parsed.scheme!="https" or not parsed.hostname: errors.append(f"{p}:https_required")
        if not isinstance(host,str) or parsed.hostname!=host: errors.append(f"{p}:host_mismatch")
        if source.get("enabled") is True:
            if source.get("trust") not in TRUSTED: errors.append(f"{p}:enabled_source_not_trusted")
            if source.get("format") not in SUPPORTED_FORMATS: errors.append(f"{p}:unsupported_enabled_format")
            hints=source.get("domain_hints")
            if not isinstance(hints,list) or not hints or not all(isinstance(x,str) and x.strip() for x in hints): errors.append(f"{p}:invalid_domain_hints")
            conf=source.get("source_confidence")
            if isinstance(conf,bool) or not isinstance(conf,(int,float)) or not 0<=float(conf)<=1: errors.append(f"{p}:invalid_source_confidence")
    return errors
def enabled_sources(registry:dict[str,Any])->list[dict[str,Any]]:
    errors=validate_registry(registry)
    if errors: raise ValueError("invalid source registry: "+";".join(errors))
    return [s for s in registry["sources"] if s.get("enabled") is True]
def can_write_core()->bool: return False
