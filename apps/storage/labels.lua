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

local function chooseLabelScale(monitorName, text)
  local candidates = { 3, 2, 1.5, 1 }

  for _, scale in ipairs(candidates) do
    local monitor = peripheral.wrap(monitorName)
    if monitor then
      monitor.setTextScale(scale)
      local w = select(1, monitor.getSize())
      if #text <= w then
        return scale
      end
    end
  end

  return 1
end

local function drawLabel(monitorName, text)
  local m = peripheral.wrap(monitorName)
  if not m then
    error("Monitor not found: " .. tostring(monitorName))
  end

  m.setTextScale(chooseLabelScale(monitorName, text))
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()

  local _, h = m.getSize()
  local y = math.max(1, math.floor((h - 1) / 2) + 1)

  m.setCursorPos(centerX(m, text), y)
  m.write(text)
end

for _, category in ipairs(CFG.categories) do
  if type(category) == "table" and category.key and category.label then
    local monitorName = CFG.monitors[category.key]
    if monitorName then
      drawLabel(monitorName, string.upper(tostring(category.label)))
    end
  end
end
