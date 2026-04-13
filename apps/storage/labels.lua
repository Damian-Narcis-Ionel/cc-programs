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

local function repeatChar(ch, count)
  if count <= 0 then
    return ""
  end
  return string.rep(ch, count)
end

local function stretchTextToWidth(text, width)
  if #text >= width or #text <= 1 then
    return text
  end

  local gaps = #text - 1
  local extra = width - #text
  local base = math.floor(extra / gaps)
  local remainder = extra % gaps
  local out = {}

  for i = 1, #text do
    out[#out + 1] = text:sub(i, i)
    if i < #text then
      local pad = base
      if remainder > 0 then
        pad = pad + 1
        remainder = remainder - 1
      end
      out[#out + 1] = repeatChar(" ", pad)
    end
  end

  return table.concat(out)
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

  local scale = chooseLabelScale(monitorName, text)
  m.setTextScale(scale)
  m.setBackgroundColor(colors.black)
  m.setTextColor(colors.white)
  m.clear()

  local w, h = m.getSize()
  local displayText = stretchTextToWidth(text, w)
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
