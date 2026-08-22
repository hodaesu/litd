# LITD Music Factory

Automated production pipeline for the adaptive score of **Light in the Dark**.

Arrangement 01 is built around the public-domain composition *Passacaglia in C minor, BWV 582* by J. S. Bach. The master MIDI, automation and metadata are versioned here; proprietary VST/sample-library content must stay outside Git.

## Production contract

- 52 BPM
- 3/4
- 8 bars per adaptive cell
- 21 cells
- 10 production tracks
- 210 synchronized WAV stems per complete render
- 48 kHz stereo WAV master stems

Production tracks:

1. `OSTINATO`
2. `STRINGS_LOW`
3. `BODY_PERCUSSION`
4. `MIND_MELODY`
5. `COMMON_COUNTERPOINT`
6. `CHOIR`
7. `ASH_CORRUPTION`
8. `WORLD_TEXTURE`
9. `IMPACTS`
10. `TRANSITIONS`

## One-time workstation setup

Install:

- MuseScore Studio (score/MusicXML conversion and editing)
- REAPER (orchestration, VST instruments, FX and stem rendering)
- Godot 4.3 editor
- Python 3.10+

If the executables are not on `PATH`, define `MUSESCORE_BIN`, `REAPER_BIN` and/or `GODOT_BIN` with their complete executable paths.

In REAPER, enable the MIDI-import preference that expands a multitrack MIDI file into separate tracks. This is the only MIDI import preference required by the setup ReaScript.

Register these two Lua files once in REAPER's Action List as ReaScripts:

- `tools/music_pipeline/reaper/litd_setup_project.lua`
- `tools/music_pipeline/reaper/litd_render_all.lua`

## Arrangement 01 source

The master MIDI is already included at:

`tools/music_pipeline/inbox/LITD_Arrangement_01_Accord_Brise_BWV582_MASTER.mid`

No manual copy is needed after checking out this branch/PR.

## Prepare

From the repository root:

```bash
python tools/music_pipeline/build_music.py doctor
python tools/music_pipeline/build_music.py prepare
```

`prepare` creates the render/output directories and writes `litd_generated_settings.lua` with absolute local paths for REAPER.

On Windows, `tools/music_pipeline/LITD_MUSIC_PREPARE.cmd` performs this preparation with a double-click.

## REAPER project creation

Open a new REAPER project and run `litd_setup_project.lua`.

The script automatically:

- sets 52 BPM and 3/4;
- imports the master MIDI;
- checks that 10 production tracks were created;
- renames those tracks to the LITD production IDs;
- optionally loads VST/FX names configured in `litd_instrument_map.lua`;
- creates the 21 adaptive regions;
- creates the Region Render Matrix for every region and production track;
- sets the render directory;
- sets `$region_$track` naming;
- prepares 48 kHz stereo WAV rendering.

The optional `litd_instrument_map.lua` is deliberately empty by default. Fill it with the exact names of instruments/effects you legally own, or use a REAPER track template and leave the map empty.

## Render

When the orchestration/mix is ready, run `litd_render_all.lua`.

REAPER renders files named like:

`S07_COMBAT_I_BODY_PERCUSSION.wav`

The complete Arrangement 01 render contains **210 files**.

## Validate and integrate into Godot

```bash
python tools/music_pipeline/build_music.py validate-renders
python tools/music_pipeline/build_music.py finalize
```

On Windows, `tools/music_pipeline/LITD_MUSIC_FINALIZE.cmd` performs finalization with a double-click.

`finalize`:

1. rejects missing, invalid or incorrectly timed WAV stems;
2. copies the 210 stems into `assets/audio/music/adaptive/arr_01_accord_brise_bwv582/`;
3. generates `data/generated/litd_arrangement_01_stems.json`;
4. runs Godot with `--headless --path <repo> --import` so the audio assets are imported without opening the editor UI.

Each 8-bar cell must be approximately **27.692 seconds** at 52 BPM. The validator allows only a small timing tolerance to protect phase alignment.

## Current Godot relationship

LITD already contains `AudioDirector`, `AdaptiveMusicDirector` and `LayeredMusicRuntime`. The production manifest keeps the new 10-stem vocabulary while also declaring a compatibility map to the current five runtime layer families (`pulse`, `percussion`, `strings`, `choir`, `crisis`). This lets the production pipeline evolve without creating a second competing audio director.

The existing procedural layers remain useful as development fallbacks until the final stems are rendered and wired as file-backed streams.

## MuseScore CLI helper

The coordinator can call MuseScore's converter mode without opening its UI:

```bash
python tools/music_pipeline/build_music.py musescore-export input.musicxml output.mid
```

## Legal / asset rule

Do not commit proprietary sample libraries, VST binaries or recordings merely because the underlying classical composition is public domain. Only commit assets for which the project has the required rights. The arrangement source, project automation and newly rendered LITD audio must keep their provenance documented.
