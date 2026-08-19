#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

REQUIRED_CUES = {
    "exploration_ashlands",
    "exploration_ruins",
    "exploration_threat",
    "combat_normal",
    "combat_elite",
    "combat_boss",
    "boss_phase_change",
    "sadness_loss",
    "memorial",
    "emotional_reunion",
    "hope_manifestation",
    "sanctuary_day",
    "tavern",
    "chapel",
    "political_tension",
    "ancient_archive",
    "fear_panic",
    "madness_trace",
    "creature_empathy",
    "discovery_revelation",
    "victory_costly",
    "defeat_retreat",
    "ending_choice",
    "credits",
}


def run(root: Path = ROOT) -> dict:
    library_path = root / "data/music_library.json"
    runtime_path = root / "scripts/core/music_library.gd"
    smoke_path = root / "scripts/core/music_library_smoke_test.gd"
    scene_path = root / "scenes/tests/music_library_smoke.tscn"
    project_path = root / "project.godot"
    ci_path = root / ".github/workflows/ci.yml"
    godot_ci_path = root / "tools/build/run_godot_ci.sh"
    guide_path = root / "docs/design/music_library.md"

    library = json.loads(library_path.read_text(encoding="utf-8"))
    runtime = runtime_path.read_text(encoding="utf-8")
    smoke = smoke_path.read_text(encoding="utf-8")
    scene = scene_path.read_text(encoding="utf-8")
    project = project_path.read_text(encoding="utf-8")
    ci = ci_path.read_text(encoding="utf-8")
    godot_ci = godot_ci_path.read_text(encoding="utf-8")
    guide = guide_path.read_text(encoding="utf-8")

    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    check("Musique : schéma v1", int(library.get("version", 0)) >= 1)
    check("Musique : source de design", library.get("design_source") == "narrative_music_library_pass_17")
    check("Musique : catalogue sans faux binaires", library.get("asset_status") == "catalog_only_no_audio_binaries")

    sources = {item.get("id"): item for item in library.get("sources", []) if isinstance(item, dict)}
    for source_id in ["pixabay", "creative_commons_cc0", "incompetech", "opengameart", "musopen", "mixkit"]:
        check(f"Source musicale : {source_id}", source_id in sources)
    check("Mixkit : explicitement rouge", sources.get("mixkit", {}).get("default_tier") == "red")
    check("CC0 : classe verte", sources.get("creative_commons_cc0", {}).get("default_tier") == "green")

    policy = library.get("license_policy", {})
    check("Licences : preuves avant ingestion", len(policy.get("evidence_required_before_ingestion", [])) >= 8)
    check("Licences : règles substantielles", len(policy.get("rules", [])) >= 8)
    check("Licences : Content ID traité", any("Content-ID" in str(value) or "Content ID" in str(value) for value in policy.get("rules", [])))
    check("Licences : CC BY traité", any("CC BY" in str(value) for value in policy.get("rules", [])))

    cues = library.get("cue_families", [])
    cue_ids = {str(item.get("id", "")) for item in cues if isinstance(item, dict)}
    check("Cues : au moins vingt-quatre familles", len(cue_ids) >= 24, str(len(cue_ids)))
    for cue_id in sorted(REQUIRED_CUES):
        check(f"Cue : {cue_id}", cue_id in cue_ids)

    tracks = [item for item in library.get("tracks", []) if isinstance(item, dict)]
    track_ids = [str(item.get("id", "")) for item in tracks]
    check("Musiques : au moins vingt-cinq candidates", len(tracks) >= 25, str(len(tracks)))
    check("Musiques : IDs uniques", len(track_ids) == len(set(track_ids)))
    green = [item for item in tracks if item.get("legal_tier") == "green"]
    amber = [item for item in tracks if item.get("legal_tier") == "amber"]
    red = [item for item in tracks if item.get("legal_tier") == "red"]
    check("Musiques : quinze candidates vertes minimum", len(green) >= 15, str(len(green)))
    check("Musiques : candidates ambiguës isolées", len(amber) >= 5, str(len(amber)))
    check("Musiques : refus explicites conservés", len(red) >= 1, str(len(red)))

    for item in tracks:
        track_id = str(item.get("id", ""))
        check(f"{track_id} : titre et artiste", bool(item.get("title")) and bool(item.get("artist")))
        check(f"{track_id} : source connue", item.get("source") in sources)
        check(f"{track_id} : niveau légal", item.get("legal_tier") in {"green", "amber", "red"})
        check(f"{track_id} : URL licence", str(item.get("license_url", "")).startswith("https://"))
        check(f"{track_id} : pas de faux chemin local", item.get("local_path", "") == "")
        for cue_id in item.get("cues", []):
            check(f"{track_id} : cue {cue_id} connu", cue_id in cue_ids)

    check(
        "Musiques vertes : pages sources exactes",
        all(str(item.get("source_url", "")).startswith("https://") for item in green),
    )
    check(
        "Content ID : jamais vert",
        all(item.get("legal_tier") != "green" for item in tracks if item.get("content_id") is True),
    )
    check(
        "Mixkit : aucune candidate expédiable",
        all(item.get("legal_tier") == "red" for item in tracks if item.get("source") == "mixkit"),
    )
    check(
        "Risque d'identité : rejeté",
        any(item.get("originality_risk") == "high" and item.get("legal_tier") == "red" for item in tracks),
    )

    mapped_green_cues = {
        cue_id
        for item in green
        for cue_id in item.get("cues", [])
        if isinstance(cue_id, str)
    }
    for cue_id in ["exploration_ruins", "combat_boss", "memorial", "sanctuary_day", "fear_panic"]:
        check(f"Couverture verte : {cue_id}", cue_id in mapped_green_cues)

    check("Score adaptatif : au moins dix règles", len(library.get("adaptive_score_rules", [])) >= 10)
    check("Ingestion : au moins douze étapes", len(library.get("ingestion_checklist", [])) >= 12)
    mix = library.get("mix_priorities", {})
    check("Mix : dialogue ducking", int(mix.get("dialogue_ducking_db", 0)) < 0)
    check("Mix : télégraphes au-dessus de la musique", mix.get("combat_telegraph_priority") == "above_music")

    for token in [
        'const DATA_PATH := "res://data/music_library.json"',
        "func tracks()",
        "func track(",
        "func cues()",
        "func cue(",
        "func tracks_for_cue(",
        "func shipping_candidates(",
        "func content_id_candidates()",
        "func source_is_excluded(",
        "func credits_lines()",
        "func coverage()",
    ]:
        check(f"Runtime musique : {token}", token in runtime)

    check("Projet : MusicLibrary autoload", 'MusicLibrary="*res://scripts/core/music_library.gd"' in project)
    check("Smoke : runner musique", "MusicLibrary.coverage()" in smoke)
    check("Smoke : scène musique", "music_library_smoke_bootstrap.gd" in scene)
    check("Godot CI : smoke musique", "music_library_smoke.tscn" in godot_ci)
    check("CI : audit musique", "python -m tools.qa.music_library_audit" in ci)

    check("Documentation : licences", "licence" in guide.lower())
    check("Documentation : Content ID", "Content ID" in guide)
    check("Documentation : narration", "narration" in guide.lower())
    check("Documentation : Mixkit exclu", "Mixkit" in guide and "interdit" in guide.lower())
    check("Documentation : stock temporaire", "identité musicale" in guide.lower())

    return {
        "summary": {"checks": len(checks), "errors": sum(1 for item in checks if not item["ok"])},
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "music-library-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
