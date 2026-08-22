-- LITD Music Factory — render all adaptive stems
-- Expects the project prepared by litd_setup_project.lua.

local TRACKS = {
  "OSTINATO","STRINGS_LOW","BODY_PERCUSSION","MIND_MELODY","COMMON_COUNTERPOINT",
  "CHOIR","ASH_CORRUPTION","WORLD_TEXTURE","IMPACTS","TRANSITIONS"
}

local function find_track(name)
  for i = 0, reaper.CountTracks(0) - 1 do
    local tr = reaper.GetTrack(0, i)
    local _, tr_name = reaper.GetSetMediaTrackInfo_String(tr, "P_NAME", "", false)
    if tr_name == name then return tr end
  end
  return nil
end

for _, name in ipairs(TRACKS) do
  if not find_track(name) then
    reaper.MB("Missing production track: " .. name .. "\nRun litd_setup_project.lua first.", "LITD Music Factory", 0)
    return
  end
end

local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
if num_regions < 21 then
  reaper.MB("Only " .. tostring(num_regions) .. " regions found; 21 are required.", "LITD Music Factory", 0)
  return
end

-- Keep render settings deterministic even if the Render dialog was changed.
reaper.GetSetProjectInfo(0, "RENDER_SETTINGS", 8, true)
reaper.GetSetProjectInfo(0, "RENDER_BOUNDSFLAG", 3, true)
reaper.GetSetProjectInfo(0, "RENDER_SRATE", 48000, true)
reaper.GetSetProjectInfo(0, "RENDER_CHANNELS", 2, true)
reaper.GetSetProjectInfo(0, "RENDER_TAILFLAG", 0, true)
reaper.GetSetProjectInfo_String(0, "RENDER_PATTERN", "$region_$track", true)
reaper.GetSetProjectInfo_String(0, "RENDER_FORMAT", "evaw", true)

-- Built-in action: File: Render project using the most recent render settings.
-- The render directory and Region Render Matrix are set during project setup.
reaper.Main_OnCommand(41824, 0)
