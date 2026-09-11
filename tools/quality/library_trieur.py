#!/usr/bin/env python3
"""Deterministic first-pass router for the LITD living library.

The Trieur recommends a destination only. It never writes to the Core and it
quarantines ambiguous material instead of guessing.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Iterable


class Route(str, Enum):
    GENERAL = "GENERAL_LIBRARY"
    LITD = "LITD_LIBRARY"
    QUARANTINE = "QUARANTINED"


@dataclass(frozen=True)
class RoutingDecision:
    route: Route
    confidence: float
    reason: str
    cross_reference: bool = False
    core_write_allowed: bool = False


GENERAL_MARKERS = {
    "godot", "gdscript", "python", "algorithm", "architecture", "ux", "ui",
    "accessibility", "performance", "optimization", "blender", "shader",
    "audio", "ci", "testing", "cybersecurity", "game design", "procedural",
}

LITD_MARKERS = {
    "litd", "les veilleurs", "terre des cendres", "mathilde", "marec",
    "anouk", "aurélien", "ange", "rémanence", "expédition", "extraction",
    "lumière", "vertical slice", "guild", "sanctuaire",
}

DECISION_MARKERS = {
    "we decided", "decision", "approved", "validated", "retenu", "validé",
    "canonique", "implémenter dans litd", "apply to litd",
}


def _score(text: str, markers: Iterable[str]) -> int:
    lowered = text.casefold()
    return sum(1 for marker in markers if marker.casefold() in lowered)


def route_information(text: str, *, source_verified: bool) -> RoutingDecision:
    """Return a conservative routing recommendation.

    Rules:
    - unverified evidence is quarantined;
    - general-only information goes to a general library;
    - LITD-only information goes to the project library;
    - mixed material is routed to LITD only when it clearly describes an LITD
      application, with a cross-reference to the general canonical source;
    - ambiguous ties are quarantined;
    - the Trieur can never authorize Core writes.
    """
    if not text or not text.strip():
        return RoutingDecision(Route.QUARANTINE, 0.0, "empty_content")

    if not source_verified:
        return RoutingDecision(Route.QUARANTINE, 0.20, "source_not_verified")

    general = _score(text, GENERAL_MARKERS)
    litd = _score(text, LITD_MARKERS)
    decision = _score(text, DECISION_MARKERS)

    if general == 0 and litd == 0:
        return RoutingDecision(Route.QUARANTINE, 0.30, "no_domain_signal")

    if general > 0 and litd == 0:
        confidence = min(0.95, 0.65 + 0.05 * general)
        return RoutingDecision(Route.GENERAL, confidence, "general_reusable_knowledge")

    if litd > 0 and general == 0:
        confidence = min(0.95, 0.65 + 0.05 * litd)
        return RoutingDecision(Route.LITD, confidence, "litd_specific_knowledge")

    # Mixed general + project-specific information is only accepted into the
    # LITD library when its application to LITD is explicit. Otherwise we
    # quarantine to avoid turning generic knowledge into project canon.
    if decision > 0 or litd >= general + 1:
        confidence = min(0.95, 0.70 + 0.04 * (litd + decision))
        return RoutingDecision(
            Route.LITD,
            confidence,
            "litd_application_of_general_knowledge",
            cross_reference=True,
        )

    return RoutingDecision(Route.QUARANTINE, 0.45, "ambiguous_general_vs_litd")


def can_write_core(_: RoutingDecision) -> bool:
    """Hard invariant: routing never grants authority to mutate the Core."""
    return False
