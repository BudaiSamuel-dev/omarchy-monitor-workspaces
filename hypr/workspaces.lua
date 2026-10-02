-- Per-monitor workspaces for Omarchy.
-- https://github.com/BudaiSamuel-dev/omarchy-monitor-workspaces
--
-- Each monitor owns its own block of ten workspaces, addressed with the same
-- digits:
--   SUPER + N                       primary monitor, workspace N   (ids 1-10)
--   SUPER + <modifier> + N          secondary monitor, workspace N (ids 11-20)
--   SUPER + SHIFT [+ <modifier>] + N  move the active window there
--
-- The primary is any external display while one is connected; the laptop panel
-- (eDP/LVDS/DSI) is primary only when it is the sole screen. Undocked, both
-- blocks live on the laptop and go back to their own monitor on re-dock.
--
-- The default modifier is MOD5, which is Right Alt once kb_options contains
-- "lv3:ralt_switch". To use another one, set this before loading the file:
--   monitor_workspaces = { modifier = "CTRL" }
--
-- The plugin's bar widget (Workspaces.qml) mirrors the primary rule below.

local settings = _G.monitor_workspaces or {}
local MODIFIER = settings.modifier or "MOD5"
local OFFSET = 10
local LAPTOP_OUTPUTS = { "^eDP", "^LVDS", "^DSI" }

local function monitors()
  local list = {}
  for _, monitor in ipairs(hl.get_monitors()) do
    if not monitor.is_mirror then
      list[#list + 1] = monitor
    end
  end

  table.sort(list, function(left, right) return left.id < right.id end)
  return list
end

local function is_laptop(monitor)
  for _, pattern in ipairs(LAPTOP_OUTPUTS) do
    if monitor.name:match(pattern) then return true end
  end

  return false
end

local function primary()
  local list = monitors()
  for _, monitor in ipairs(list) do
    if not is_laptop(monitor) then
      return monitor
    end
  end

  return list[1]
end

local function secondary()
  local main = primary()
  for _, monitor in ipairs(monitors()) do
    if main and monitor.name ~= main.name then
      return monitor
    end
  end

  return nil
end

local function home(id)
  if id > OFFSET then
    return secondary() or primary()
  end

  return primary()
end

local function managed(id)
  return id >= 1 and id <= OFFSET * 2
end

local function place(id)
  if not managed(id) then return end

  local workspace = hl.get_workspace(tostring(id))
  local target = home(id)
  if not workspace or not workspace.monitor or not target then return end

  if workspace.monitor.name ~= target.name then
    hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(id), monitor = target.name }))
  end
end

local function rebalance()
  for _, workspace in ipairs(hl.get_workspaces()) do
    place(workspace.id)
  end
end

-- Hyprland is mid-way through creating the workspace when the event fires, so
-- move it on the next loop iteration instead of from inside the callback.
local pending = {}

local function defer(callback)
  local timer
  timer = hl.timer(function()
    pending[timer] = nil
    callback()
  end, { timeout = 1, type = "oneshot" })
  pending[timer] = true
end

local function focus(id)
  local target = home(id)
  if target then
    hl.dispatch(hl.dsp.focus({ monitor = target.name }))
  end

  hl.dispatch(hl.dsp.focus({ workspace = tostring(id) }))
  place(id)
end

local function move_window(id)
  hl.dispatch(hl.dsp.window.move({ workspace = tostring(id) }))
  place(id)
end

for digit = 1, 10 do
  local key = "code:" .. tostring(digit + 9)
  local label = digit == 10 and "0" or tostring(digit)

  local secondary_key = "SUPER + " .. MODIFIER .. " + " .. key
  local secondary_move_key = "SUPER + SHIFT + " .. MODIFIER .. " + " .. key

  -- Replace Omarchy's global workspace bindings (default/hypr/bindings/tiling.lua),
  -- and whatever a non-default modifier would otherwise collide with.
  hl.unbind("SUPER + " .. key)
  hl.unbind("SUPER + SHIFT + " .. key)
  hl.unbind(secondary_key)
  hl.unbind(secondary_move_key)

  o.bind("SUPER + " .. key, "Primary workspace " .. label, function() focus(digit) end)
  o.bind("SUPER + SHIFT + " .. key, "Move window to primary workspace " .. label, function() move_window(digit) end)
  o.bind(secondary_key, "Secondary workspace " .. label, function() focus(digit + OFFSET) end)
  o.bind(secondary_move_key, "Move window to secondary workspace " .. label, function() move_window(digit + OFFSET) end)
end

hl.on("workspace.created", function(workspace)
  local id = workspace.id
  defer(function() place(id) end)
end)

hl.on("monitor.added", function() defer(rebalance) end)
hl.on("monitor.removed", function() defer(rebalance) end)
hl.on("hyprland.start", function() defer(rebalance) end)
hl.on("config.reloaded", function() defer(rebalance) end)
