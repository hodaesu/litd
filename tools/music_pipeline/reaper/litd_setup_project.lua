-- LITD Music Factory — project setup
-- Run this ReaScript in a NEW REAPER project after:
--   python tools/music_pipeline/build_music.py prepare
--
-- REAPER preference required once:
--   MIDI import -> expand multichannel/multitrack MIDI to new tracks.

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("^(.*[\\/])") or ""
local settings_path = script_dir .. "litd_generated_settings.lua"
local instrument_map_path = script_dir .. "litd_instrument_map.lua"

local ok, err = pcall(dofile, settings_path)
if not ok then
  reaper.MB(
    "Missing generated settings.\nRun:\npython tools/music_pipeline/build_music.py prepare\n\n" .. tostring(err),
    "LITD Music Factory", 0
  )
  return
end

pcall(dofile, instrument_map_path)

local TRACKS = {
  "OSTINATO",
  "STRINGS_LOW",
  "BODY_PERCUSSION",
  "MIND_MELODY",
  "COMMON_COUNTERPOINT",
  "CHOIR",
  "ASH_CORRUPTION",
  "WORLD_TEXTURE",
  "IMPACTS",
  "TRANSITIONS"
}

local SECTIONS = {
  "S00_FOUNDATION",
  "S01_BODY",
  "S02_MIND",
  "S03_COMMON",
  "S04_ANCIENT_CIVILIZATION",
  "S05_ASH_ARRIVAL",
  "S06_FEAR",
  "S07_COMBAT_I",
  "S08_COMBAT_II",
  "S09_HOPE",
  "S10_BODY_SANCTUARY",
  "S11_RUPTURE",
  "S12_MIND_SANCTUARY",
  "S13_COMMON_SANCTUARY",
  "S14_FIRST_ACCORD",
  "S15_FALL",
  "S16_RECONSTRUCTION",
  "S17_MADNESS",
  "S18_ANGEL_FALSE_ACCORD",
  "S19_RESISTANCE",
  "S20_TRUE_ACCORD"
}

local function configure_fx(track, track_id)
  if type(LITD_INSTRUMENT_MAP) ~= "table" then return end
  local chain = LITD_INSTRUMENT_MAP[track_id]
  if type(chain) ~= "table" then return end
  for _, fx_name in ipairs(chain) do
    if type(fx_name) == "string" and fx_name ~= "" then
      local fx_index = reaper.TrackFX_AddByName(track, fx_name, false, -1)
      if fx_index < 0 then
        reaper.ShowConsoleMsg("LITD: FX not found for " .. track_id .. ": " .. fx_name .. "\n")
      end
    end
  end
end

local function configure_render(proj)
  reaper.GetSetProjectInfo(proj, "RENDER_SETTINGS", 8, true) -- region render matrix
  reaper.GetSetProjectInfo(proj, "RENDER_BOUNDSFLAG", 3, true) -- all project regions
  reaper.GetSetProjectInfo(proj, "RENDER_SRATE", 48000, true)
  reaper.GetSetProjectInfo(proj, "RENDER_CHANNELS", 2, true)
  reaper.GetSetProjectInfo(proj, "RENDER_TAILFLAG", 0, true)
  reaper.GetSetProjectInfo(proj, "RENDER_ADDTOPROJ", 0, true)
  reaper.GetSetProjectInfo_String(proj, "RENDER_FILE", LITD_RENDER_ROOT, true)
  reaper.GetSetProjectInfo_String(proj, "RENDER_PATTERN", "$region_$track", true)
  reaper.GetSetProjectInfo_String(proj, "RENDER_FORMAT", "evaw", true)
end

local proj = 0
if not reaper.file_exists(LITD_SOURCE_MIDI) then
  reaper.MB("Master MIDI not found:\n" .. LITD_SOURCE_MIDI, "LITD Music Factory", 0)
  return
end

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

-- Project clock first so imported MIDI and the 8-bar regions share the same grid.
reaper.SetTempoTimeSigMarker(
  proj, -1, 0.0, 0, 0.0,
  LITD_BPM, LITD_TIME_SIG_NUM, LITD_TIME_SIG_DEN, false
)

local before = reaper.CountTracks(proj)
reaper.SetEditCurPos(0.0, false, false)
reaper.InsertMedia(LITD_SOURCE_MIDI, 1)
local after = reaper.CountTracks(proj)
local added = after - before

if added < #TRACKS then
  reaper.PreventUIRefresh(-1)
  reaper.Undo_EndBlock("LITD music factory: import MIDI", -1)
  reaper.MB(
    "REAPER created only " .. tostring(added) .. " track(s), but LITD needs 10.\n\n" ..
    "Enable the REAPER MIDI-import option that expands multitrack MIDI to separate tracks, " ..
    "open a new project, then run this script again. This is a one-time REAPER preference.",
    "LITD Music Factory", 0
  )
  return
end

-- Use exactly the first ten newly imported tracks as the production stems.
local production_tracks = {}
for i, track_id in ipairs(TRACKS) do
  local track = reaper.GetTrack(proj, before + i - 1)
  production_tracks[i] = track
  reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_id, true)
  configure_fx(track, track_id)
end

-- Regions are calculated in quarter-note positions: 3/4 => 3 QN/bar, 8 bars => 24 QN.
for section_index, section_id in ipairs(SECTIONS) do
  local qn_start = (section_index - 1) * LITD_BARS_PER_SECTION * LITD_TIME_SIG_NUM
  local qn_end = section_index * LITD_BARS_PER_SECTION * LITD_TIME_SIG_NUM
  local start_time = reaper.TimeMap2_QNToTime(proj, qn_start)
  local end_time = reaper.TimeMap2_QNToTime(proj, qn_end)
  local region_index = reaper.AddProjectMarker2(proj, true, start_time, end_time, section_id, -1, 0)
  if region_index >= 0 then
    for _, track in ipairs(production_tracks) do
      reaper.SetRegionRenderMatrix(proj, region_index, track, 4) -- force stereo
    end
  end
end

configure_render(proj)

reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
reaper.Undo_EndBlock("LITD music factory: setup Arrangement 01", -1)

reaper.MB(
  "LITD Arrangement 01 is prepared.\n\n" ..
  "10 production tracks renamed.\n" ..
  "21 x 8-bar regions created.\n" ..
  "Region Render Matrix configured (210 stems).\n" ..
  "Optional VST chains loaded when named in litd_instrument_map.lua.\n\n" ..
  "When the orchestration is ready, run litd_render_all.lua.",
  "LITD Music Factory", 0
)
