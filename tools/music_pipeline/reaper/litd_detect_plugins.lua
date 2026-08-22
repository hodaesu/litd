-- LITD Music Factory — detect installed instrument players for the selected stack.
-- Run from REAPER's Action List after installing SINEplayer and/or Kontakt Player.
-- Uses REAPER 7.42+ EnumInstalledFX API.

local needles = {
  "sine",
  "orchestral tools",
  "kontakt",
  "native instruments",
  "uvi",
  "falcon",
  "workstation"
}

local function contains_any(value)
  local lowered = string.lower(value or "")
  for _, needle in ipairs(needles) do
    if string.find(lowered, needle, 1, true) then
      return true
    end
  end
  return false
end

reaper.ClearConsole()
reaper.ShowConsoleMsg("LITD Music Factory — matching installed FX\n")
reaper.ShowConsoleMsg("==========================================\n")

local index = 0
local found = 0
while true do
  local ok, name, ident = reaper.EnumInstalledFX(index)
  if not ok then break end
  if contains_any(name) or contains_any(ident) then
    found = found + 1
    reaper.ShowConsoleMsg(string.format("%02d | %s\n     %s\n", found, name or "", ident or ""))
  end
  index = index + 1
end

if found == 0 then
  reaper.ShowConsoleMsg("No SINE/Kontakt/UVI-family plugin was detected.\n")
  reaper.ShowConsoleMsg("Install the selected player, restart REAPER, then run this detector again.\n")
else
  reaper.ShowConsoleMsg("\nCopy the exact plugin names above into litd_instrument_map.lua if automatic setup does not resolve them.\n")
end

reaper.MB(
  "Plugin scan complete. Open REAPER's ReaScript console to see the exact installed FX names.",
  "LITD Music Factory", 0
)
