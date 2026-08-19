#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
DIALOGUES_PATH = ROOT / "data/reactive_dialogues.json"
PROFILES_PATH = ROOT / "data/voice_profiles.json"
PRODUCTION_PATH = ROOT / "data/voice_production.json"


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _sha256_text(text: str) -> str:
    return _sha256_bytes(text.encode("utf-8"))


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _as_float(value: Any, default: float = 1.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _repo_relative(path: Path) -> str:
    return path.resolve().relative_to(ROOT.resolve()).as_posix()


def _delivery_for_line(line: dict[str, Any], production: dict[str, Any]) -> dict[str, Any]:
    default = dict(production.get("default_delivery", {}))
    event = str(line.get("event", ""))
    event_delivery = dict(production.get("event_delivery", {}).get(event, {}))
    default.update(event_delivery)

    speed = _as_float(default.get("speed", 1.0))
    direction = str(default.get("direction", "retenu, naturel"))

    if bool(line.get("fourth_wall", False)):
        meta_level = str(line.get("meta_level", "fissure"))
        meta = dict(production.get("meta_delivery", {}).get(meta_level, {}))
        speed *= _as_float(meta.get("speed_multiplier", 1.0))
        suffix = str(meta.get("direction_suffix", "")).strip()
        if suffix:
            direction += suffix

    speaker_id = str(line.get("speaker_id", ""))
    speaker = dict(production.get("speaker_overrides", {}).get(speaker_id, {}))
    speed *= _as_float(speaker.get("speed_multiplier", 1.0))

    return {
        "speed": round(max(0.65, min(1.25, speed)), 3),
        "direction": direction,
    }


def build_plan(root: Path = ROOT) -> dict[str, Any]:
    dialogues = _load_json(root / "data/reactive_dialogues.json")
    profiles = _load_json(root / "data/voice_profiles.json")
    production = _load_json(root / "data/voice_production.json")
    profile_ids = {
        str(item.get("hero_id", ""))
        for item in profiles.get("profiles", [])
        if isinstance(item, dict)
    }

    render_dir = Path(str(production["paths"]["render_directory"]))
    shipping_dir = Path(str(production["paths"]["shipping_directory"]))
    overrides = production.get("speaker_overrides", {})
    entries: list[dict[str, Any]] = []

    for raw in dialogues.get("lines", []):
        if not isinstance(raw, dict):
            continue
        speaker_id = str(raw.get("speaker_id", ""))
        line_id = str(raw.get("id", ""))
        text = str(raw.get("text", "")).strip()
        if not line_id or not text or speaker_id == "narrator":
            continue
        if speaker_id not in profile_ids:
            raise ValueError(f"Dialogue {line_id}: missing voice profile for {speaker_id}")

        speaker_override = dict(overrides.get(speaker_id, {}))
        reference_filename = str(speaker_override.get("reference_filename", f"{speaker_id}.wav"))
        delivery = _delivery_for_line(raw, production)
        render_path = render_dir / speaker_id / f"{line_id}.wav"
        shipping_path = shipping_dir / speaker_id / f"{line_id}.wav"
        entries.append(
            {
                "line_id": line_id,
                "speaker_id": speaker_id,
                "event": str(raw.get("event", "")),
                "text": text,
                "text_sha256": _sha256_text(text),
                "fourth_wall": bool(raw.get("fourth_wall", False)),
                "meta_level": str(raw.get("meta_level", "")),
                "delivery": delivery,
                "reference_id": f"{speaker_id}_voice_reference",
                "reference_filename": reference_filename,
                "render_path": render_path.as_posix(),
                "shipping_path": shipping_path.as_posix(),
                "status": "pending_reference",
            }
        )

    return {
        "version": 1,
        "engine": production["engine"],
        "rules": production["rules"],
        "entry_count": len(entries),
        "entries": entries,
    }


def _registry_by_reference_id(path: Path) -> dict[str, dict[str, Any]]:
    if not path.exists():
        raise FileNotFoundError(
            f"Voice reference registry missing: {path}. Copy the example registry and fill it locally."
        )
    payload = _load_json(path)
    result: dict[str, dict[str, Any]] = {}
    for raw in payload.get("references", []):
        if isinstance(raw, dict):
            reference_id = str(raw.get("reference_id", ""))
            if reference_id:
                result[reference_id] = raw
    return result


def _validate_reference(
    entry: dict[str, Any],
    registry: dict[str, dict[str, Any]],
    reference_dir: Path,
) -> tuple[Path, dict[str, Any]]:
    reference_id = str(entry["reference_id"])
    record = registry.get(reference_id)
    if record is None:
        raise ValueError(f"Missing registry record for {reference_id}")
    for key in ("consent_confirmed", "original_or_authorized", "commercial_game_use"):
        if record.get(key) is not True:
            raise ValueError(f"Reference {reference_id}: {key} must be explicitly true before rendering")
    filename = str(record.get("reference_file", entry["reference_filename"]))
    if not filename:
        raise ValueError(f"Reference {reference_id}: reference_file is empty")
    reference_path = reference_dir / filename
    if not reference_path.is_file():
        raise FileNotFoundError(f"Reference audio missing for {reference_id}: {reference_path}")
    return reference_path, record


def _git_head(repo: Path) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except (OSError, subprocess.CalledProcessError):
        return ""


def _ensure_pinned_checkout(openvoice_root: Path, expected_commit: str) -> None:
    actual = _git_head(openvoice_root)
    if actual and actual != expected_commit:
        raise RuntimeError(
            "OpenVoice checkout is not the tested pinned commit. "
            f"Expected {expected_commit}, got {actual}."
        )


def _select_entries(
    plan: dict[str, Any], speaker_ids: set[str], line_ids: set[str]
) -> list[dict[str, Any]]:
    selected: list[dict[str, Any]] = []
    for entry in plan["entries"]:
        if speaker_ids and str(entry["speaker_id"]) not in speaker_ids:
            continue
        if line_ids and str(entry["line_id"]) not in line_ids:
            continue
        selected.append(entry)
    return selected


def render(
    *,
    openvoice_root: Path,
    registry_path: Path,
    report_path: Path,
    speaker_ids: set[str],
    line_ids: set[str],
    device_override: str,
    force: bool,
) -> dict[str, Any]:
    production = _load_json(PRODUCTION_PATH)
    plan = build_plan(ROOT)
    engine = production["engine"]
    expected_commit = str(engine["openvoice_pinned_commit"])
    _ensure_pinned_checkout(openvoice_root, expected_commit)

    checkpoints = openvoice_root / str(engine.get("checkpoints_folder", "checkpoints_v2"))
    converter_dir = checkpoints / "converter"
    if not (converter_dir / "config.json").is_file() or not (converter_dir / "checkpoint.pth").is_file():
        raise FileNotFoundError(
            f"OpenVoice V2 converter checkpoints not found under {converter_dir}. "
            "Install the official V2 checkpoints before rendering."
        )

    reference_dir = ROOT / str(production["paths"]["reference_directory"])
    registry = _registry_by_reference_id(registry_path)
    selected = _select_entries(plan, speaker_ids, line_ids)
    if not selected:
        raise ValueError("No voice lines matched the requested filters")

    sys.path.insert(0, str(openvoice_root))
    try:
        import torch  # type: ignore
        from melo.api import TTS  # type: ignore
        from openvoice import se_extractor  # type: ignore
        from openvoice.api import ToneColorConverter  # type: ignore
    except ImportError as exc:
        raise RuntimeError(
            "OpenVoice V2/MeloTTS dependencies are not installed in this Python environment. "
            "Follow docs/design/voice_production_pipeline.md."
        ) from exc

    if device_override:
        device = device_override
    else:
        device = "cuda:0" if torch.cuda.is_available() else "cpu"

    converter = ToneColorConverter(str(converter_dir / "config.json"), device=device)
    converter.load_ckpt(str(converter_dir / "checkpoint.pth"))
    model = TTS(language=str(engine.get("language", "FR")), device=device)
    speaker_ids_map = dict(model.hps.data.spk2id)
    if not speaker_ids_map:
        raise RuntimeError("MeloTTS returned no French base speaker")
    base_speaker_name = sorted(speaker_ids_map.keys())[0]
    base_speaker_id = speaker_ids_map[base_speaker_name]
    speaker_key = base_speaker_name.lower().replace("_", "-")
    source_se_path = checkpoints / "base_speakers" / "ses" / f"{speaker_key}.pth"
    if not source_se_path.is_file():
        raise FileNotFoundError(f"OpenVoice V2 source speaker embedding missing: {source_se_path}")
    source_se = torch.load(str(source_se_path), map_location=device)

    target_embeddings: dict[str, Any] = {}
    reference_records: dict[str, dict[str, Any]] = {}
    reference_paths: dict[str, Path] = {}
    report_entries: list[dict[str, Any]] = []

    with tempfile.TemporaryDirectory(prefix="litd-openvoice-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        src_path = temp_dir / "base.wav"

        for entry in selected:
            reference_id = str(entry["reference_id"])
            if reference_id not in target_embeddings:
                reference_path, record = _validate_reference(entry, registry, reference_dir)
                target_se, _audio_name = se_extractor.get_se(
                    str(reference_path), converter, vad=True
                )
                target_embeddings[reference_id] = target_se
                reference_records[reference_id] = record
                reference_paths[reference_id] = reference_path

            output_path = ROOT / str(entry["render_path"])
            output_path.parent.mkdir(parents=True, exist_ok=True)
            if output_path.exists() and not force:
                status = "existing"
            else:
                model.tts_to_file(
                    str(entry["text"]),
                    base_speaker_id,
                    str(src_path),
                    speed=float(entry["delivery"]["speed"]),
                )
                converter.convert(
                    audio_src_path=str(src_path),
                    src_se=source_se,
                    tgt_se=target_embeddings[reference_id],
                    output_path=str(output_path),
                    message=str(engine.get("watermark_message", "@MyShell")),
                )
                status = "rendered"

            record = reference_records[reference_id]
            report_entries.append(
                {
                    **entry,
                    "status": status,
                    "render_sha256": _sha256_file(output_path),
                    "reference_sha256": _sha256_file(reference_paths[reference_id]),
                    "reference_record_id": str(record.get("reference_id", reference_id)),
                    "device": device,
                    "base_speaker": base_speaker_name,
                }
            )

    report = {
        "version": 1,
        "engine": engine,
        "openvoice_checkout": _git_head(openvoice_root),
        "human_review_required": True,
        "entries": report_entries,
    }
    _write_json(report_path, report)
    return report


def ingest(*, report_path: Path, approve_reviewed: bool) -> dict[str, Any]:
    if not approve_reviewed:
        raise ValueError(
            "Ingest is intentionally blocked until --approve-reviewed is supplied after listening review."
        )
    production = _load_json(PRODUCTION_PATH)
    report = _load_json(report_path)
    registry_path = ROOT / str(production["paths"]["reference_registry"])
    reference_dir = ROOT / str(production["paths"]["reference_directory"])
    registry = _registry_by_reference_id(registry_path)

    assets: list[dict[str, Any]] = []
    for entry in report.get("entries", []):
        if not isinstance(entry, dict):
            continue
        render_path = ROOT / str(entry["render_path"])
        if not render_path.is_file():
            raise FileNotFoundError(f"Rendered line missing: {render_path}")
        if _sha256_file(render_path) != str(entry.get("render_sha256", "")):
            raise ValueError(f"Rendered file changed after report: {render_path}")

        _validate_reference(entry, registry, reference_dir)
        shipping_path = ROOT / str(entry["shipping_path"])
        shipping_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(render_path, shipping_path)
        shipping_sha = _sha256_file(shipping_path)
        assets.append(
            {
                "line_id": str(entry["line_id"]),
                "speaker_id": str(entry["speaker_id"]),
                "local_path": "res://" + _repo_relative(shipping_path),
                "sha256": shipping_sha,
                "text_sha256": str(entry["text_sha256"]),
                "engine": "openvoice_v2",
                "reference_id": str(entry["reference_id"]),
                "human_reviewed": True,
            }
        )

    manifest_path = ROOT / str(production["paths"]["asset_manifest"])
    manifest = {
        "version": 1,
        "engine": "openvoice_v2",
        "rule": "Assets ingérés après écoute humaine et validation locale des droits de la voix de référence.",
        "assets": sorted(assets, key=lambda item: str(item["line_id"])),
    }
    _write_json(manifest_path, manifest)
    return manifest


def _plan_command(args: argparse.Namespace) -> int:
    plan = build_plan(ROOT)
    output = Path(args.output)
    if not output.is_absolute():
        output = ROOT / output
    _write_json(output, plan)
    print(f"VOICE_PLAN_OK: {plan['entry_count']} line(s) -> {output}")
    return 0


def _render_command(args: argparse.Namespace) -> int:
    openvoice_root_value = args.openvoice_root or os.environ.get("LITD_OPENVOICE_ROOT", "")
    if not openvoice_root_value:
        raise ValueError("Provide --openvoice-root or LITD_OPENVOICE_ROOT")
    production = _load_json(PRODUCTION_PATH)
    registry_value = args.registry or str(production["paths"]["reference_registry"])
    report_value = args.report or "build/voice_rendered/render-report.json"
    report = render(
        openvoice_root=Path(openvoice_root_value).expanduser().resolve(),
        registry_path=(ROOT / registry_value).resolve() if not Path(registry_value).is_absolute() else Path(registry_value),
        report_path=(ROOT / report_value).resolve() if not Path(report_value).is_absolute() else Path(report_value),
        speaker_ids=set(args.speaker or []),
        line_ids=set(args.line_id or []),
        device_override=args.device,
        force=args.force,
    )
    print(f"VOICE_RENDER_OK: {len(report['entries'])} line(s)")
    return 0


def _ingest_command(args: argparse.Namespace) -> int:
    report_path = Path(args.report)
    if not report_path.is_absolute():
        report_path = ROOT / report_path
    manifest = ingest(report_path=report_path, approve_reviewed=args.approve_reviewed)
    print(f"VOICE_INGEST_OK: {len(manifest['assets'])} asset(s)")
    return 0


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Light in the Dark offline OpenVoice V2 production pipeline")
    sub = parser.add_subparsers(dest="command", required=True)

    plan = sub.add_parser("plan", help="Build the deterministic voice generation plan without AI dependencies")
    plan.add_argument("--output", default="reports/voice-generation-plan.json")
    plan.set_defaults(func=_plan_command)

    render_parser = sub.add_parser("render", help="Render authored dialogue lines with local OpenVoice V2")
    render_parser.add_argument("--openvoice-root", default="")
    render_parser.add_argument("--registry", default="")
    render_parser.add_argument("--report", default="")
    render_parser.add_argument("--speaker", action="append")
    render_parser.add_argument("--line-id", action="append")
    render_parser.add_argument("--device", default="")
    render_parser.add_argument("--force", action="store_true")
    render_parser.set_defaults(func=_render_command)

    ingest_parser = sub.add_parser("ingest", help="Copy listened-and-approved WAV files into Godot assets")
    ingest_parser.add_argument("--report", default="build/voice_rendered/render-report.json")
    ingest_parser.add_argument("--approve-reviewed", action="store_true")
    ingest_parser.set_defaults(func=_ingest_command)
    return parser


def main() -> int:
    args = _parser().parse_args()
    try:
        return int(args.func(args))
    except Exception as exc:  # CLI boundary: emit concise actionable error.
        print(f"VOICE_PIPELINE_ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
