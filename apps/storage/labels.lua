local CFG = dofile("/sorter_config.lua")

if not CFG.monitors then
  error("Missing CFG.monitors in /sorter_config.lua")
end

if not CFG.categories or type(CFG.categories) ~= "table" then
  error("Missing CFG.categories in /sorter_config.lua")
end

local function centerX(termObj, text)
  local w, _ = termObj.getSize()
  return math.max(1, math.floor((w - #text) / 2) + 1)
end

local function chooseLabelLayout(monitorName, text)
  local normalized = tostring(text or ""):upper():gsub("%s+", "")
  local candidates = { 5, 4, 3, 2, 1.5, 1 }

  for _, scale in ipairs(candidates) do
    local monitor = peripheral.wrap(monitorName)
    if monitor then
      monitor.setTextScale(scale)
      local w, h = monitor.getSize()
      local safeWidth = math.max(1, w - 1)
      if h >= 1 and #normalized <= safeWidth then
        return scale, normalized
      end
    end
  end

  local monitor = peripheral.wrap(monitorName)
  monitor.setTextScale(0.5)
  local w = select(1, monitor.getSize())
  local safeWidth = math.max(1, w - 1)

  if #normalized <= safeWidth then
    return 0.5, normalized
  end

  return 0.5, normalized:sub(1, safeWidth)
end

local function drawLabel(monitorName, text)
  local m = peripheral.wrap(monitorName)
  if not m then
    error("Monitor not found: " .. tostring(monitorName))
  end

  local scale, displayText = chooseLabelLayout(monitorName, text)
  m.setTextScale(scale)
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()

  local _, h = m.getSize()
  local y = math.max(1, math.floor((h - 1) / 2) + 1)

  m.setCursorPos(centerX(m, displayText), y)
  m.write(displayText)
end

for _, category in ipairs(CFG.categories) do
  if type(category) == "table" and category.key and category.label then
    local monitorName = CFG.monitors[category.key]
    if monitorName then
      drawLabel(monitorName, string.upper(tostring(category.label)))
    end
  end
end
