local CONFIG_PATH = "/sorter_config.lua"

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

local function collectInventories()
  local out = {}
  for _, name in ipairs(sortedPeripheralNames()) do
    if isInventory(name) then
      out[#out + 1] = name
    end
  end
  return out
end

local function collectMonitors()
  local out = {}
  for _, name in ipairs(sortedPeripheralNames()) do
    if isMonitor(name) then
      out[#out + 1] = name
    end
  end
  return out
end

local function getConfiguredDashboardMonitors(cfg)
  local out = {}
  local seen = {}

  if cfg and type(cfg.monitors) == "table" then
    if type(cfg.monitors.dashboards) == "table" then
      for _, name in ipairs(cfg.monitors.dashboards) do
        if type(name) == "string" and isMonitor(name) and not seen[name] then
          out[#out + 1] = name
          seen[name] = true
        end
      end
    end

    if #out == 0 and type(cfg.monitors.dashboard) == "string" and isMonitor(cfg.monitors.dashboard) then
      out[#out + 1] = cfg.monitors.dashboard
    end
  end

  return out
end

local function detectDashboardMonitors(cfg)
  local configured = getConfiguredDashboardMonitors(cfg)
  if #configured > 0 then
    return configured[1], configured
  end

  for _, name in ipairs(sortedPeripheralNames()) do
    if isMonitor(name) then
      return name, { name }
    end
  end

  error("No monitor peripheral found for setup.")
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
      desired = (existing and type(existing.desired) == "number" and existing.desired) or entry.desired,
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
          desired = type(category.desired) == "number" and category.desired
            or (type(category.chests) == "table" and #category.chests or 0),
          chests = {},
        }
      end
    end
  end

  return categories
end

local function makeMonitorsState(cfg, dashboardMonitors)
  local monitors = {}

  if cfg and type(cfg.monitors) == "table" then
    for key, value in pairs(cfg.monitors) do
      if type(key) == "string" and key ~= "dashboard" and key ~= "dashboards" and type(value) == "string" then
        monitors[key] = value
      end
    end
  end

  monitors.dashboard = dashboardMonitors[1]
  monitors.dashboards = {}
  for i, name in ipairs(dashboardMonitors) do
    monitors.dashboards[i] = name
  end
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

  lines[#lines + 1] = "  dashboards = {"
  for _, name in ipairs(state.dashboardMonitors) do
    lines[#lines + 1] = "    " .. quoteLua(name) .. ","
  end
  lines[#lines + 1] = "  },"
  lines[#lines + 1] = "  dashboard = " .. quoteLua(state.dashboardMonitors[1]) .. ","

  local monitorKeys = {}
  for key, value in pairs(state.monitors) do
    if type(key) == "string" and key ~= "dashboard" and key ~= "dashboards" and type(value) == "string" then
      monitorKeys[#monitorKeys + 1] = key
    end
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
    lines[#lines + 1] = ("    { key = %s, label = %s, desired = %d, chests = {"):format(
      quoteLua(category.key),
      quoteLua(category.label),
      category.desired or 0
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
local dashboardMonitorName, detectedDashboardMonitors = detectDashboardMonitors(existingConfig)
local monitor = peripheral.wrap(dashboardMonitorName)
local allInventories = collectInventories()
local allMonitors = collectMonitors()
local inventorySet = {}
for _, name in ipairs(allInventories) do
  inventorySet[name] = true
end

local state = {
  monitorName = dashboardMonitorName,
  dashboardMonitors = detectedDashboardMonitors,
  monitors = makeMonitorsState(existingConfig, detectedDashboardMonitors),
  categories = makeCategoryState(existingConfig),
  inputName = nil,
  mode = "input",
  currentIndex = 1,
  categoryPage = 1,
  activeCategoryKey = nil,
  pendingDashboardIndex = nil,
  pendingMonitorCategoryKey = nil,
  message = "Touch buttons on the monitor to configure storage.",
  history = {},
  baseline = {},
  saved = false,
}

local function syncDashboardMonitors()
  local dashboards = { state.monitorName }
  if type(state.dashboardMonitors[2]) == "string"
    and state.dashboardMonitors[2] ~= ""
    and state.dashboardMonitors[2] ~= state.monitorName then
    dashboards[2] = state.dashboardMonitors[2]
  end

  state.dashboardMonitors = dashboards
  state.monitors.dashboard = dashboards[1]
  state.monitors.dashboards = {}
  for i, name in ipairs(dashboards) do
    state.monitors.dashboards[i] = name
  end
end

syncDashboardMonitors()

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

local function categoryForMonitor(monitorName)
  for _, category in ipairs(state.categories) do
    if state.monitors[category.key] == monitorName then
      return category
    end
  end
  return nil
end

local function monitorLabelForCategory(categoryKey)
  local name = state.monitors[categoryKey]
  if type(name) == "string" and name ~= "" then
    return name
  end
  return "unassigned"
end

local function dashboardLabel(index)
  local name = state.dashboardMonitors[index]
  if type(name) == "string" and name ~= "" then
    return name
  end
  return "unassigned"
end

local function isDashboardMonitorName(name)
  for _, dashboardName in ipairs(state.dashboardMonitors) do
    if dashboardName == name then
      return true
    end
  end
  return false
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

local function beginMonitorAssignment()
  if not state.activeCategoryKey then
    setMessage("Select a category first.")
    return
  end

  if #allMonitors <= #state.dashboardMonitors then
    setMessage("No extra monitor found for labels.")
    return
  end

  local category = categoryByKey(state.activeCategoryKey)
  state.pendingMonitorCategoryKey = state.activeCategoryKey
  setMessage(("Touch the label monitor for %s."):format(category.label))
end

local function beginSecondaryDashboardAssignment()
  if #allMonitors <= #state.dashboardMonitors then
    setMessage("No extra monitor found for dashboard 2.")
    return
  end

  state.pendingMonitorCategoryKey = nil
  state.pendingDashboardIndex = 2
  setMessage("Touch the second dashboard monitor.")
end

local function clearSecondaryDashboard()
  state.dashboardMonitors[2] = nil
  state.pendingDashboardIndex = nil
  syncDashboardMonitors()
  setMessage("Cleared dashboard 2.")
end

local function assignPendingDashboard(monitorName)
  if state.pendingDashboardIndex ~= 2 then
    return false
  end

  if monitorName == state.monitorName then
    setMessage("Touch the second dashboard monitor, not the setup monitor.")
    return true
  end

  if not isMonitor(monitorName) then
    setMessage("Touched peripheral is not a monitor.")
    return true
  end

  local category = categoryForMonitor(monitorName)
  if category then
    setMessage(("Monitor already used as label for %s."):format(category.label))
    return true
  end

  state.dashboardMonitors[2] = monitorName
  state.pendingDashboardIndex = nil
  syncDashboardMonitors()
  setMessage(("Assigned dashboard 2: %s"):format(monitorName))
  return true
end

local function clearActiveCategoryMonitor()
  if not state.activeCategoryKey then
    setMessage("Select a category first.")
    return
  end

  local category = categoryByKey(state.activeCategoryKey)
  state.monitors[state.activeCategoryKey] = nil
  if state.pendingMonitorCategoryKey == state.activeCategoryKey then
    state.pendingMonitorCategoryKey = nil
  end
  setMessage(("Cleared label monitor for %s."):format(category.label))
end

local function assignPendingMonitor(monitorName)
  local categoryKey = state.pendingMonitorCategoryKey
  if not categoryKey then
    return false
  end

  if isDashboardMonitorName(monitorName) then
    setMessage("Touch a label monitor, not a dashboard monitor.")
    return true
  end

  if not isMonitor(monitorName) then
    setMessage("Touched peripheral is not a monitor.")
    return true
  end

  local category = categoryByKey(categoryKey)
  if not category then
    state.pendingMonitorCategoryKey = nil
    setMessage("Selected category is missing.")
    return true
  end

  state.monitors[categoryKey] = monitorName
  state.pendingMonitorCategoryKey = nil
  setMessage(("Assigned label monitor %s -> %s"):format(monitorName, category.label))
  return true
end

local function startFresh()
  state.inputName = nil
  state.mode = "input"
  state.currentIndex = 1
  state.categoryPage = 1
  state.activeCategoryKey = nil
  state.pendingDashboardIndex = nil
  state.pendingMonitorCategoryKey = nil
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

  local reservedRows = state.mode == "assign" and 20 or 10
  local rowsAvailable = math.max(1, math.floor((h - reservedRows) / 2))
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
    local y = 9

    local activeCategory = state.activeCategoryKey and categoryByKey(state.activeCategoryKey) or nil
    local dashboardsText = ("Dashboards: 1=%s  2=%s"):format(dashboardLabel(1), dashboardLabel(2))
    local dashboardsColor = state.pendingDashboardIndex and colors.cyan or colors.gray
    writeCentered(monitor, 6, clip(dashboardsText, w), dashboardsColor, colors.black)

    if activeCategory then
      local selectedText = ("Selected: %s (%d/%d)"):format(activeCategory.label, #activeCategory.chests, activeCategory.desired)
      writeCentered(monitor, 7, clip(selectedText, w), colors.lime, colors.black)
      local monitorText = "Label monitor: " .. monitorLabelForCategory(activeCategory.key)
      local monitorColor = state.pendingMonitorCategoryKey == activeCategory.key and colors.cyan or colors.gray
      writeCentered(monitor, 8, clip(monitorText, w), monitorColor, colors.black)
    else
      writeCentered(monitor, 7, "Selected: none", colors.yellow, colors.black)
      writeCentered(monitor, 8, "Label monitor: none", colors.gray, colors.black)
    end

    for i = pageStart, math.min(#state.categories, pageStart + pageSize - 1) do
      local category = state.categories[i]
      local col = ((i - pageStart) % 2)
      local row = math.floor((i - pageStart) / 2)
      local x = col == 0 and leftX or rightX
      local yy = y + (row * 2)
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

    drawButton(monitor, buttons, "assign_dashboard_2", 2, h - 17, 14, 2, "Set Dash 2", colors.cyan, colors.black)
    drawButton(monitor, buttons, "clear_dashboard_2", w - 13, h - 17, 12, 2, "Clear Dash2", colors.gray, colors.black)
    drawButton(monitor, buttons, "clear_category", 2, h - 8, 14, 2, "Clear Chests", colors.red, colors.white)
    drawButton(monitor, buttons, "assign_monitor", math.max(2, math.floor((w - 16) / 2)), h - 8, 16, 2, "Assign Label", colors.cyan, colors.black)
    drawButton(monitor, buttons, "clear_monitor", w - 13, h - 8, 12, 2, "Clear Label", colors.gray, colors.black)
    drawButton(monitor, buttons, "confirm_category", math.max(2, math.floor((w - 20) / 2)), h - 2, 20, 2, "Confirm Category", colors.green, colors.black)
    drawButton(monitor, buttons, "undo", 2, h - 2, 8, 2, "Undo", colors.orange, colors.black)
    drawButton(monitor, buttons, "save", w - 7, h - 2, 8, 2, "Save", colors.lime, colors.black)
  else
    drawButton(monitor, buttons, "set_input", math.max(2, math.floor((w - 14) / 2)), 8, 14, 3, "Set Input", colors.lime, colors.black)
  end

  drawButton(monitor, buttons, "prev", 2, h - 11, 8, 2, "< Prev", colors.lightGray, colors.black)
  drawButton(monitor, buttons, "next", w - 7, h - 11, 8, 2, "Next >", colors.lightGray, colors.black)
  drawButton(monitor, buttons, "mark", math.max(2, math.floor((w - 14) / 2)), h - 11, 14, 2, "Find Marked", colors.purple, colors.white)
  drawButton(monitor, buttons, "reset", math.max(2, math.floor((w - 14) / 2)), h - 14, 14, 2, "Reset Baseline", colors.gray, colors.black)
  drawButton(monitor, buttons, "start_fresh", w - 13, h - 14, 12, 2, "Start Fresh", colors.red, colors.white)

  local footer
  if state.pendingDashboardIndex then
    footer = "Touch the second dashboard monitor"
  elseif state.pendingMonitorCategoryKey then
    footer = "Touch a label monitor to assign it"
  else
    footer = "Change chests, then tap Find Marked"
  end
  writeCentered(monitor, h, clip(footer, w), colors.lightGray, colors.black)

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
  elseif id == "assign_dashboard_2" then
    beginSecondaryDashboardAssignment()
  elseif id == "clear_dashboard_2" then
    clearSecondaryDashboard()
  elseif id == "assign_monitor" then
    beginMonitorAssignment()
  elseif id == "clear_monitor" then
    clearActiveCategoryMonitor()
  elseif id == "confirm_category" then
    if not state.activeCategoryKey then
      setMessage("Select a category first.")
    else
      local category = categoryByKey(state.activeCategoryKey)
      setMessage(("Confirmed %s with %d chest(s), label monitor %s."):format(
        category.label,
        #category.chests,
        monitorLabelForCategory(category.key)
      ))
      state.activeCategoryKey = nil
    end
  elseif id == "start_fresh" then
    startFresh()
  elseif string.sub(id, 1, 4) == "cat:" then
    state.pendingDashboardIndex = nil
    state.pendingMonitorCategoryKey = nil
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

  if event == "monitor_touch" then
    if state.pendingDashboardIndex then
      if assignPendingDashboard(p1) then
        -- handled dashboard assignment touch
      elseif p1 == state.monitorName then
        local id = hitButton(buttons, p2, p3)
        if id then
          handleButton(id)
        end
      end
    elseif state.pendingMonitorCategoryKey then
      if assignPendingMonitor(p1) then
        -- handled monitor assignment touch
      elseif p1 == state.monitorName then
        local id = hitButton(buttons, p2, p3)
        if id then
          handleButton(id)
        end
      end
    elseif p1 == state.monitorName then
      local id = hitButton(buttons, p2, p3)
      if id then
        handleButton(id)
      end
    end
  elseif event == "key" and p1 == keys.q then
    monitor.setBackgroundColor(colors.black)
    monitor.clear()
    term.setCursorPos(1, 6)
    print("Setup exited.")
    break
  end
end
