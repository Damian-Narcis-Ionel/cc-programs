local CONFIG_PATH = "sorter_config.lua"

local DEFAULT_CATEGORIES = {
  { key = "stone", label = "Stone", desired = 4 },
  { key = "wood", label = "Wood", desired = 4 },
  { key = "farm", label = "Farm", desired = 4 },
  { key = "ores", label = "Ores", desired = 4 },
  { key = "misc", label = "Misc", desired = 4 },
  { key = "armory", label = "Armory", desired = 4 },
  { key = "flowers", label = "Flowers", desired = 4 },
  { key = "building", label = "Building", desired = 4 },
  { key = "mobs", label = "Mobs", desired = 4 },
  { key = "blocks", label = "Blocks", desired = 4 },
}

local function clip(text, maxLen)
  text = tostring(text or "")
  if maxLen <= 0 then return "" end
  if #text <= maxLen then return text end
  if maxLen <= 3 then return string.sub(text, 1, maxLen) end
  return string.sub(text, 1, maxLen - 3) .. "..."
end

local function centerX(termObj, text)
  local w = select(1, termObj.getSize())
  return math.max(1, math.floor((w - #text) / 2) + 1)
end

local function writeCentered(termObj, y, text, fg, bg)
  if fg then termObj.setTextColor(fg) end
  if bg then termObj.setBackgroundColor(bg) end
  termObj.setCursorPos(centerX(termObj, text), y)
  termObj.write(text)
end

local function fillRect(termObj, x, y, w, h, bg)
  termObj.setBackgroundColor(bg or colors.black)
  for yy = y, y + h - 1 do
    termObj.setCursorPos(x, yy)
    termObj.write(string.rep(" ", w))
  end
end

local function drawButton(termObj, buttons, id, x, y, w, h, label, bg, fg)
  fillRect(termObj, x, y, w, h, bg)
  local labelY = y + math.floor(h / 2)
  termObj.setCursorPos(x + math.max(0, math.floor((w - #label) / 2)), labelY)
  termObj.setTextColor(fg or colors.white)
  termObj.setBackgroundColor(bg)
  termObj.write(clip(label, w))
  buttons[#buttons + 1] = {
    id = id,
    x1 = x,
    y1 = y,
    x2 = x + w - 1,
    y2 = y + h - 1,
  }
end

local function loadExistingConfig()
  if not fs.exists(CONFIG_PATH) then
    return nil
  end

  local ok, cfg = pcall(dofile, CONFIG_PATH)
  if ok and type(cfg) == "table" then
    return cfg
  end

  return nil
end

local function isInventory(name)
  return peripheral.isPresent(name) and peripheral.hasType(name, "inventory")
end

local function isMonitor(name)
  return peripheral.isPresent(name) and peripheral.hasType(name, "monitor")
end

local function sortedPeripheralNames()
  local names = peripheral.getNames()
  table.sort(names)
  return names
end

local function detectDashboardMonitor(cfg)
  if cfg and cfg.monitors and type(cfg.monitors.dashboard) == "string" and isMonitor(cfg.monitors.dashboard) then
    return cfg.monitors.dashboard
  end

  for _, name in ipairs(sortedPeripheralNames()) do
    if isMonitor(name) then
      return name
    end
  end

  error("No monitor peripheral found for setup.")
end

local function collectInventories()
  local out = {}
  for _, name in ipairs(sortedPeripheralNames()) do
    if isInventory(name) then
      out[#out + 1] = name
    end
  end
  return out
end

local function makeCategoryState(cfg)
  local existingByKey = {}
  if cfg and type(cfg.categories) == "table" then
    for _, category in ipairs(cfg.categories) do
      if type(category) == "table" and type(category.key) == "string" then
        existingByKey[category.key] = category
      end
    end
  end

  local categories = {}
  local seen = {}

  for _, entry in ipairs(DEFAULT_CATEGORIES) do
    local existing = existingByKey[entry.key]
    categories[#categories + 1] = {
      key = entry.key,
      label = (existing and existing.label) or entry.label,
      desired = (existing and type(existing.chests) == "table" and #existing.chests) or entry.desired,
      chests = {},
    }
    seen[entry.key] = true
  end

  if cfg and type(cfg.categories) == "table" then
    for _, category in ipairs(cfg.categories) do
      if type(category) == "table" and type(category.key) == "string" and not seen[category.key] then
        categories[#categories + 1] = {
          key = category.key,
          label = category.label or category.key,
          desired = type(category.chests) == "table" and #category.chests or 0,
          chests = {},
        }
      end
    end
  end

  return categories
end

local function makeMonitorsState(cfg, dashboardMonitor)
  local monitors = {
    dashboard = dashboardMonitor,
  }

  if cfg and type(cfg.monitors) == "table" then
    for key, value in pairs(cfg.monitors) do
      if type(key) == "string" and type(value) == "string" then
        monitors[key] = value
      end
    end
  end

  monitors.dashboard = dashboardMonitor
  return monitors
end

local function contains(list, value)
  for i = 1, #list do
    if list[i] == value then
      return true
    end
  end
  return false
end

local function snapshotInventory(name)
  if not isInventory(name) then
    return "missing"
  end

  local inv = peripheral.wrap(name)
  local ok, items = pcall(function()
    return inv.list()
  end)

  if not ok then
    return "error"
  end

  local parts = {}
  for slot, item in pairs(items) do
    parts[#parts + 1] = ("%s@%d:%d"):format(item.name or "?", slot, item.count or 0)
  end
  table.sort(parts)
  return table.concat(parts, "|")
end

local function previewInventory(name)
  if not isInventory(name) then
    return "Inventory missing"
  end

  local inv = peripheral.wrap(name)
  local ok, items = pcall(function()
    return inv.list()
  end)

  if not ok then
    return "Could not read inventory"
  end

  local parts = {}
  local occupied = 0
  for _, item in pairs(items) do
    occupied = occupied + 1
    if #parts < 3 then
      parts[#parts + 1] = ("%s x%d"):format(item.name or "?", item.count or 0)
    end
  end

  local slots = inv.size()
  if occupied == 0 then
    return ("empty (%d slots)"):format(slots)
  end

  return ("%d/%d used | %s"):format(occupied, slots, table.concat(parts, ", "))
end

local function quoteLua(value)
  return string.format("%q", value)
end

local function writeConfigFile(state)
  if not state.inputName or state.inputName == "" then
    return nil, "Input chest is not assigned"
  end

  local lines = {}

  lines[#lines + 1] = "-- generated by setup_storage.lua"
  lines[#lines + 1] = "local chests = {"
  lines[#lines + 1] = "  input = " .. quoteLua(state.inputName) .. ","
  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "local monitors = {"

  local monitorKeys = {}
  for key in pairs(state.monitors) do
    monitorKeys[#monitorKeys + 1] = key
  end
  table.sort(monitorKeys)

  for _, key in ipairs(monitorKeys) do
    lines[#lines + 1] = ("  %s = %s,"):format(key, quoteLua(state.monitors[key]))
  end

  lines[#lines + 1] = "}"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "return {"
  lines[#lines + 1] = "  chests = chests,"
  lines[#lines + 1] = "  monitors = monitors,"
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  categories = {"

  for _, category in ipairs(state.categories) do
    lines[#lines + 1] = ("    { key = %s, label = %s, chests = {"):format(
      quoteLua(category.key),
      quoteLua(category.label)
    )
    for _, chestName in ipairs(category.chests) do
      lines[#lines + 1] = "      " .. quoteLua(chestName) .. ","
    end
    lines[#lines + 1] = "    }},"
  end

  lines[#lines + 1] = "  }"
  lines[#lines + 1] = "}"

  local file = fs.open(CONFIG_PATH, "w")
  if not file then
    return nil, "Could not open sorter_config.lua for writing"
  end

  file.write(table.concat(lines, "\n"))
  file.close()

  return true
end

local existingConfig = loadExistingConfig()
local dashboardMonitorName = detectDashboardMonitor(existingConfig)
local monitor = peripheral.wrap(dashboardMonitorName)
local allInventories = collectInventories()
local inventorySet = {}
for _, name in ipairs(allInventories) do
  inventorySet[name] = true
end

local state = {
  monitorName = dashboardMonitorName,
  monitors = makeMonitorsState(existingConfig, dashboardMonitorName),
  categories = makeCategoryState(existingConfig),
  inputName = nil,
  mode = "input",
  currentIndex = 1,
  categoryPage = 1,
  activeCategoryKey = nil,
  message = "Touch buttons on the monitor to configure storage.",
  history = {},
  baseline = {},
  saved = false,
}

if existingConfig and existingConfig.chests and type(existingConfig.chests.input) == "string" and inventorySet[existingConfig.chests.input] then
  state.inputName = existingConfig.chests.input
  state.mode = "assign"
end

if existingConfig and type(existingConfig.categories) == "table" then
  local byKey = {}
  for _, category in ipairs(state.categories) do
    byKey[category.key] = category
  end

  for _, category in ipairs(existingConfig.categories) do
    local target = byKey[category.key]
    if target and type(category.chests) == "table" then
      for _, chestName in ipairs(category.chests) do
        if inventorySet[chestName] and chestName ~= state.inputName and not contains(target.chests, chestName) then
          target.chests[#target.chests + 1] = chestName
        end
      end
    end
  end
end

local function categoryByKey(key)
  for _, category in ipairs(state.categories) do
    if category.key == key then
      return category
    end
  end
  return nil
end

local function assignedSet()
  local used = {}
  if state.inputName then
    used[state.inputName] = true
  end
  for _, category in ipairs(state.categories) do
    for _, chestName in ipairs(category.chests) do
      used[chestName] = true
    end
  end
  return used
end

local function candidateNames()
  local used = assignedSet()
  local out = {}
  for _, name in ipairs(allInventories) do
    if state.mode == "input" then
      out[#out + 1] = name
    elseif not used[name] then
      out[#out + 1] = name
    end
  end
  return out
end

local function resetBaseline()
  state.baseline = {}
  for _, name in ipairs(candidateNames()) do
    state.baseline[name] = snapshotInventory(name)
  end
end

local function currentCandidate()
  local candidates = candidateNames()
  if #candidates == 0 then
    return nil, candidates
  end

  if state.currentIndex < 1 then
    state.currentIndex = 1
  end
  if state.currentIndex > #candidates then
    state.currentIndex = #candidates
  end

  return candidates[state.currentIndex], candidates
end

local function setMessage(text)
  state.message = text
  term.setCursorPos(1, 1)
  term.clearLine()
  print(text)
end

local function findMarkedCandidate()
  local candidates = candidateNames()
  local changed = {}

  for _, name in ipairs(candidates) do
    local now = snapshotInventory(name)
    if now ~= state.baseline[name] then
      changed[#changed + 1] = name
    end
  end

  if #changed == 1 then
    for i, name in ipairs(candidates) do
      if name == changed[1] then
        state.currentIndex = i
        setMessage("Marked chest found: " .. name)
        return
      end
    end
  elseif #changed == 0 then
    setMessage("No changed chest found. Add or remove one temporary item, then try again.")
  else
    setMessage("Multiple changed chests found. Reset baseline, then mark only one chest.")
  end
end

local function assignCurrentToCategory(categoryKey)
  local name = currentCandidate()
  if not name then
    setMessage("No unassigned chests left.")
    return
  end

  local category = categoryByKey(categoryKey)
  if not category then
    setMessage("Unknown category: " .. tostring(categoryKey))
    return
  end

  category.chests[#category.chests + 1] = name
  state.history[#state.history + 1] = {
    kind = "category",
    key = categoryKey,
    chest = name,
  }
  setMessage(("Assigned %s -> %s"):format(name, category.label))
  resetBaseline()
end

local function addMarkedToActiveCategory()
  if not state.activeCategoryKey then
    setMessage("Select a category first.")
    return
  end

  local candidates = candidateNames()
  local changed = {}

  for _, name in ipairs(candidates) do
    local now = snapshotInventory(name)
    if now ~= state.baseline[name] then
      changed[#changed + 1] = name
    end
  end

  if #changed == 0 then
    setMessage("No changed chest found. Add or remove one temporary item, then try again.")
    return
  end

  local category = categoryByKey(state.activeCategoryKey)
  if not category then
    setMessage("Active category is missing.")
    return
  end

  table.sort(changed)

  for _, chestName in ipairs(changed) do
    category.chests[#category.chests + 1] = chestName
    state.history[#state.history + 1] = {
      kind = "category",
      key = state.activeCategoryKey,
      chest = chestName,
    }
  end

  setMessage(("Added %d chest(s) -> %s (%d/%d)"):format(#changed, category.label, #category.chests, category.desired))
  state.currentIndex = 1
  resetBaseline()
end

local function assignCurrentAsInput()
  local name = currentCandidate()
  if not name then
    setMessage("No inventories found.")
    return
  end

  state.history[#state.history + 1] = {
    kind = "input",
    previous = state.inputName,
    chest = name,
  }
  state.inputName = name
  state.mode = "assign"
  state.currentIndex = 1
  setMessage("Input chest set to " .. name)
  resetBaseline()
end

local function undoLast()
  local entry = table.remove(state.history)
  if not entry then
    setMessage("Nothing to undo.")
    return
  end

  if entry.kind == "category" then
    local category = categoryByKey(entry.key)
    if category then
      for i = #category.chests, 1, -1 do
        if category.chests[i] == entry.chest then
          table.remove(category.chests, i)
          break
        end
      end
    end
    setMessage("Removed " .. entry.chest .. " from " .. entry.key)
  elseif entry.kind == "input" then
    state.inputName = entry.previous
    state.mode = state.inputName and "assign" or "input"
    setMessage("Reverted input selection.")
  end

  state.currentIndex = 1
  resetBaseline()
end

local function clearActiveCategory()
  if not state.activeCategoryKey then
    setMessage("Select a category first.")
    return
  end

  local category = categoryByKey(state.activeCategoryKey)
  if not category then
    setMessage("Active category is missing.")
    return
  end

  category.chests = {}
  resetBaseline()
  setMessage("Cleared category: " .. category.label)
end

local function startFresh()
  state.inputName = nil
  state.mode = "input"
  state.currentIndex = 1
  state.categoryPage = 1
  state.activeCategoryKey = nil
  state.history = {}

  for _, category in ipairs(state.categories) do
    category.chests = {}
  end

  resetBaseline()
  setMessage("Started fresh. All assignments cleared.")
end

local function render()
  monitor.setTextScale(1)
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()

  local w, h = monitor.getSize()
  local buttons = {}
  local currentName, candidates = currentCandidate()

  writeCentered(monitor, 1, "Storage Setup", colors.cyan, colors.black)

  local modeText = state.mode == "input" and "Step 1: choose input chest" or "Step 2: assign categories in batches"
  writeCentered(monitor, 2, clip(modeText, w), colors.white, colors.black)
  writeCentered(monitor, 3, clip(state.message, w), colors.lightGray, colors.black)

  if currentName then
    writeCentered(monitor, 4, clip(("Current: %s (%d/%d)"):format(currentName, state.currentIndex, #candidates), w), colors.yellow, colors.black)
    writeCentered(monitor, 5, clip(previewInventory(currentName), w), colors.gray, colors.black)
  else
    writeCentered(monitor, 4, "No candidate chest selected", colors.yellow, colors.black)
    writeCentered(monitor, 5, state.mode == "input" and "Assign an input chest to continue" or "All detected chests are assigned", colors.gray, colors.black)
  end

  local rowsAvailable = math.max(1, math.floor((h - 10) / 3))
  local pageSize = rowsAvailable * 2
  local pageCount = math.max(1, math.ceil(#state.categories / pageSize))
  if state.categoryPage > pageCount then
    state.categoryPage = pageCount
  end
  local pageStart = ((state.categoryPage - 1) * pageSize) + 1

  if state.mode == "assign" then
    local buttonW = math.max(10, math.floor((w - 6) / 2))
    local leftX = 2
    local rightX = leftX + buttonW + 2
    local y = 7

    local activeCategory = state.activeCategoryKey and categoryByKey(state.activeCategoryKey) or nil
    if activeCategory then
      writeCentered(monitor, 6, clip(("Selected: %s (%d/%d)"):format(activeCategory.label, #activeCategory.chests, activeCategory.desired), w), colors.lime, colors.black)
    else
      writeCentered(monitor, 6, "Selected: none", colors.yellow, colors.black)
    end

    for i = pageStart, math.min(#state.categories, pageStart + pageSize - 1) do
      local category = state.categories[i]
      local col = ((i - pageStart) % 2)
      local row = math.floor((i - pageStart) / 2)
      local x = col == 0 and leftX or rightX
      local yy = y + (row * 3)
      local label = ("%s %d/%d"):format(category.label, #category.chests, category.desired)
      local bg = category.key == state.activeCategoryKey and colors.lime or colors.blue
      local fg = category.key == state.activeCategoryKey and colors.black or colors.white
      drawButton(monitor, buttons, "cat:" .. category.key, x, yy, buttonW, 2, label, bg, fg)
    end

    if pageCount > 1 then
      drawButton(monitor, buttons, "cat_prev", 2, h - 5, 8, 2, "< Cats", colors.gray, colors.black)
      drawButton(monitor, buttons, "cat_next", w - 7, h - 5, 8, 2, "Cats >", colors.gray, colors.black)
      writeCentered(monitor, h - 4, ("Page %d/%d"):format(state.categoryPage, pageCount), colors.white, colors.black)
    end

    drawButton(monitor, buttons, "clear_category", 2, h - 5, 14, 2, "Clear Category", colors.red, colors.white)
    drawButton(monitor, buttons, "confirm_category", math.max(2, math.floor((w - 20) / 2)), h - 5, 20, 2, "Confirm Category", colors.green, colors.black)
    drawButton(monitor, buttons, "undo", 2, h - 2, 8, 2, "Undo", colors.orange, colors.black)
    drawButton(monitor, buttons, "save", w - 7, h - 2, 8, 2, "Save", colors.lime, colors.black)
  else
    drawButton(monitor, buttons, "set_input", math.max(2, math.floor((w - 14) / 2)), 8, 14, 3, "Set Input", colors.lime, colors.black)
  end

  drawButton(monitor, buttons, "prev", 2, h - 8, 8, 2, "< Prev", colors.lightGray, colors.black)
  drawButton(monitor, buttons, "next", w - 7, h - 8, 8, 2, "Next >", colors.lightGray, colors.black)
  drawButton(monitor, buttons, "mark", math.max(2, math.floor((w - 14) / 2)), h - 8, 14, 2, "Find Marked", colors.purple, colors.white)
  drawButton(monitor, buttons, "reset", math.max(2, math.floor((w - 14) / 2)), h - 11, 14, 2, "Reset Baseline", colors.gray, colors.black)
  drawButton(monitor, buttons, "start_fresh", w - 13, h - 11, 12, 2, "Start Fresh", colors.red, colors.white)

  writeCentered(monitor, h, "Change one or more chests, then tap Find Marked", colors.lightGray, colors.black)

  return buttons
end

local function hitButton(buttons, x, y)
  for _, button in ipairs(buttons) do
    if x >= button.x1 and x <= button.x2 and y >= button.y1 and y <= button.y2 then
      return button.id
    end
  end
  return nil
end

local function handleButton(id)
  if id == "prev" then
    state.currentIndex = state.currentIndex - 1
  elseif id == "next" then
    state.currentIndex = state.currentIndex + 1
  elseif id == "mark" then
    if state.mode == "input" then
      findMarkedCandidate()
    else
      addMarkedToActiveCategory()
    end
  elseif id == "reset" then
    resetBaseline()
    setMessage("Baseline reset. Mark one chest by adding or removing a temporary item.")
  elseif id == "set_input" then
    assignCurrentAsInput()
  elseif id == "undo" then
    undoLast()
  elseif id == "save" then
    local ok, err = writeConfigFile(state)
    if ok then
      state.saved = true
      setMessage("Saved sorter_config.lua")
    else
      setMessage(err)
    end
  elseif id == "cat_prev" then
    state.categoryPage = math.max(1, state.categoryPage - 1)
  elseif id == "cat_next" then
    state.categoryPage = state.categoryPage + 1
  elseif id == "clear_category" then
    clearActiveCategory()
  elseif id == "confirm_category" then
    if not state.activeCategoryKey then
      setMessage("Select a category first.")
    else
      local category = categoryByKey(state.activeCategoryKey)
      setMessage(("Confirmed %s with %d chest(s)."):format(category.label, #category.chests))
      state.activeCategoryKey = nil
    end
  elseif id == "start_fresh" then
    startFresh()
  elseif string.sub(id, 1, 4) == "cat:" then
    state.activeCategoryKey = string.sub(id, 5)
    local category = categoryByKey(state.activeCategoryKey)
    setMessage(("Selected category: %s. Mark chests and tap Find Marked."):format(category.label))
  end
end

term.clear()
term.setCursorPos(1, 1)
print("Storage setup starting.")
print("Stop the dashboard program first if it is currently using the same monitor.")
print("Select a category, then add or remove one temporary item in one or more chests for that category.")
print("Tap 'Find Marked' to add all changed chests at once. Opening a chest is not enough; the script detects content changes.")

resetBaseline()

while true do
  local buttons = render()
  local event, p1, p2, p3 = os.pullEvent()

  if event == "monitor_touch" and p1 == state.monitorName then
    local id = hitButton(buttons, p2, p3)
    if id then
      handleButton(id)
    end
  elseif event == "key" and p1 == keys.q then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    term.setCursorPos(1, 6)
    print("Setup exited.")
    break
  end
end
