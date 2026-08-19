#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

from tools.voice.openvoice_v2_pipeline import build_plan

ROOT = Path(__file__).resolve().parents[2]


def _load(path: str) -> dict:
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


def run(root: Path = ROOT) -> dict:
    production = _load("data/voice_production.json")
    assets = _load("data/voice_assets.json")
    registry_example = _load("docs/templates/voice_reference_registry.example.json")
    project = (root / "project.godot").read_text(encoding="utf-8")
    runtime = (root / "scripts/core/voice_runtime.gd").read_text(encoding="utf-8")
    pipeline = (root / "tools/voice/openvoice_v2_pipeline.py").read_text(encoding="utf-8")
    gitignore = (root / ".gitignore").read_text(encoding="utf-8")
    docs = (root / "docs/design/voice_production_pipeline.md").read_text(encoding="utf-8")
    plan = build_plan(root)
    checks: list[dict] = []

    def check(name: str, ok: bool, detail: str = "") -> None:
        checks.append({"name": name, "ok": bool(ok), "detail": detail})

    engine = production.get("engine", {})
    rules = production.get("rules", {})
    check("Moteur : OpenVoice V2", engine.get("id") == "openvoice_v2")
    check("Moteur : français", engine.get("language") == "FR")
    check("OpenVoice : commit épinglé", engine.get("openvoice_pinned_commit") == "74a1d147b17a8c3092dd5430504bd83ef6c7eb23")
    check("MeloTTS : commit épinglé", engine.get("melotts_pinned_commit") == "209145371cff8fc3bd60d7be902ea69cbdb7965a")
    check("Production : aucun TTS dans le jeu", rules.get("runtime_generation_in_game") is False)
    check("Production : texte écrit uniquement", rules.get("authored_text_only") is True)
    check("Droits : consentement requis", rules.get("explicit_consent_record_required") is True)
    check("Droits : voix originale ou autorisée", rules.get("reference_voice_must_be_original_or_authorized") is True)
    check("Droits : imitation acteur/célébrité interdite", rules.get("celebrity_or_actor_imitation_forbidden") is True)
    check("Validation : écoute humaine avant ingestion", rules.get("human_review_required_before_ingest") is True)
    check("Manifest : aucun faux asset vocal", assets.get("assets") == [])

    references = registry_example.get("references", [])
    check("Registre exemple : au moins quatre références", len(references) >= 4)
    check(
        "Registre exemple : aucune autorisation pré-cochée",
        all(
            item.get("consent_confirmed") is False
            and item.get("original_or_authorized") is False
            and item.get("commercial_game_use") is False
            for item in references
        ),
    )
    check("Confidentialité : références locales ignorées", "local/voice_refs/" in gitignore)

    check("Plan : au moins trente lignes mortelles", int(plan.get("entry_count", 0)) >= 30, str(plan.get("entry_count", 0)))
    entries = plan.get("entries", [])
    check("Plan : tous les WAV ont un hash texte", all(len(str(item.get("text_sha256", ""))) == 64 for item in entries))
    check("Plan : toutes les sorties restent déterministes", all(str(item.get("shipping_path", "")).endswith(".wav") for item in entries))
    check("Plan : aucune narration obligatoire clonée", all(str(item.get("speaker_id", "")) != "narrator" for item in entries))

    for token in ["def build_plan", "def render", "def ingest", "--approve-reviewed", "ToneColorConverter", "TTS(language="]:
        check("Pipeline : " + token, token in pipeline)
    check("Pipeline : import IA retardé jusqu'au rendu", "from openvoice" in pipeline and "def render" in pipeline)

    for token in ["func voice_available", "func play_payload", "func asset_for_line", "human_reviewed", "DialogueDirector.line_selected"]:
        check("Runtime voix : " + token, token in runtime)
    check("Projet : VoiceRuntime autoload", 'VoiceRuntime="*res://scripts/core/voice_runtime.gd"' in project)
    check("Documentation : installation locale", "Installation locale recommandée" in docs)
    check("Documentation : écoute humaine", "Étape 3 — écoute humaine" in docs)
    check("Documentation : ingestion Godot", "Étape 4 — ingestion Godot" in docs)

    return {
        "summary": {
            "checks": len(checks),
            "errors": sum(1 for item in checks if not item["ok"]),
        },
        "checks": checks,
    }


def main() -> int:
    payload = run(ROOT)
    out = ROOT / "reports" / "voice-pipeline-report.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    for item in payload["checks"]:
        print(("PASS" if item["ok"] else "FAIL"), "-", item["name"], item["detail"])
    print(f"RESULT: {payload['summary']['errors']} error(s) — {out}")
    return 1 if payload["summary"]["errors"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
