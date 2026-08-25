#!/usr/bin/env python3
"""Generate MuseScore, REAPER and cue-sheet inputs for Le Dernier Vol."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parents[2]
PIPELINE = ROOT / "data/cinematics/opening_pipeline.json"
INTRO = ROOT / "data/cinematics/opening_bird_intro.json"
DEFAULT_OUTPUT = ROOT / "local/cinematics/opening_bird_intro"


def load(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def timeline() -> list[dict]:
    intro = load(INTRO)
    elapsed = 0.0
    cues = []
    for waypoint in intro["runtime_waypoints"]:
        cues.append({"id": waypoint["id"], "seconds": round(elapsed, 3)})
        elapsed += float(waypoint["duration"])
    for cue_id, duration in [("last_breath", 2.4), ("heroes_approach", 3.85), ("hero_hand_occlusion", 0.55), ("exploration_handoff", 1.2)]:
        cues.append({"id": cue_id, "seconds": round(elapsed, 3)})
        elapsed += duration
    return cues


def musicxml() -> str:
    title = escape("Le Dernier Vol — esquisse")
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE score-partwise PUBLIC "-//Recordare//DTD MusicXML 4.0 Partwise//EN" "http://www.musicxml.org/dtds/partwise.dtd">
<score-partwise version="4.0">
  <work><work-title>{title}</work-title></work>
  <part-list><score-part id="P1"><part-name>Trame</part-name></score-part></part-list>
  <part id="P1">
    <measure number="1"><attributes><divisions>1</divisions><key><fifths>-2</fifths></key><time><beats>4</beats><beat-type>4</beat-type></time><clef><sign>G</sign><line>2</line></clef></attributes>
      <direction placement="above"><direction-type><words>Cité vivante — retenu, sans annoncer la catastrophe</words></direction-type><sound tempo="58"/></direction>
      <note><pitch><step>D</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
    <measure number="2"><note><pitch><step>F</step><alter>-1</alter><octave>4</octave></pitch><duration>4</duration><type>whole</type></note></measure>
    <measure number="3"><direction placement="above"><direction-type><words>La Porte — retirer progressivement les couches</words></direction-type></direction>
      <note><pitch><step>E</step><octave>4</octave></pitch><duration>4</duration><type>whole</type></note>
    </measure>
    <measure number="4"><direction placement="above"><direction-type><words>Dernier souffle vers vent de cendres</words></direction-type></direction>
      <note><rest/><duration>4</duration><type>whole</type></note>
    </measure>
  </part>
</score-partwise>
"""


def reaper_project(cues: list[dict], stems: list[str], sample_rate: int) -> str:
    lines = [
        '<REAPER_PROJECT 0.1 "7.0" 1700000000',
        f"  SAMPLERATE {sample_rate} 0 0",
        "  TEMPO 58 4 4",
    ]
    for index, cue in enumerate(cues, start=1):
        lines.append(f'  MARKER {index} {cue["seconds"]:.6f} "{cue["id"]}" 0 0 1 B')
    for stem in stems:
        lines.extend([
            "  <TRACK",
            f'    NAME "{stem}"',
            "    VOLPAN 1 0 -1 -1 1",
            "    MUTESOLO 0 0 0",
            "  >",
        ])
    lines.append(">")
    return "\n".join(lines) + "\n"


def write(output: Path) -> dict:
    pipeline = load(PIPELINE)
    audio = pipeline["audio"]
    cues = timeline()
    music_dir = output / "music"
    audio_dir = output / "audio"
    music_dir.mkdir(parents=True, exist_ok=True)
    audio_dir.mkdir(parents=True, exist_ok=True)
    (music_dir / "opening_bird_intro.musicxml").write_text(musicxml(), encoding="utf-8")
    (audio_dir / "opening_bird_intro.rpp").write_text(
        reaper_project(cues, audio["stems"], int(audio["sample_rate"])), encoding="utf-8"
    )
    cue_sheet = {
        "version": 1,
        "cinematic_id": pipeline["id"],
        "sample_rate": audio["sample_rate"],
        "events": audio["events"],
        "stems": audio["stems"],
        "timeline": cues,
        "rule": "bird_breath crossfades into ash_wind across the camera handoff",
        "human_listening_review_required": True,
    }
    (audio_dir / "cue_sheet.json").write_text(
        json.dumps(cue_sheet, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    return cue_sheet


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    pipeline = load(PIPELINE)
    if args.check:
        assert pipeline["audio"]["sample_rate"] == 48000
        assert "bird_breath" in pipeline["audio"]["events"]
        assert "ash_wind" in pipeline["audio"]["events"]
        assert timeline()[-1]["id"] == "exploration_handoff"
        print("OPENING_AUDIO_PLAN_OK")
        return 0
    result = write(args.output)
    print(f"OPENING_AUDIO_SESSION_WRITTEN {len(result['timeline'])} markers")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
