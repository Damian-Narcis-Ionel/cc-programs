local CFG = dofile("/sorter_config.lua")

if type(CFG) ~= "table" then
  error("sorter_config.lua did not return a table")
end

if not CFG.monitors or not CFG.monitors.dashboard then
  error("Missing CFG.monitors.dashboard")
end

if not CFG.categories or type(CFG.categories) ~= "table" then
  error("Missing CFG.categories")
end

local monitorName = CFG.monitors.dashboard
local monitor = peripheral.wrap(monitorName)
if not monitor then
  error("Dashboard monitor not found: " .. tostring(monitorName))
end

local REFRESH_SECONDS = 2
local SPLASH_SECONDS = 0.4
local ROWS_PER_PAGE = 5

local chestMeta = {}
local currentPage = 1
local categoryList = {}

do
  local keyed = {}

  for k, v in pairs(CFG.categories) do
    if type(k) == "number" and type(v) == "table" then
      keyed[#keyed + 1] = { index = k, value = v }
    end
  end

  table.sort(keyed, function(a, b)
    return a.index < b.index
  end)

  for _, entry in ipairs(keyed) do
    categoryList[#categoryList + 1] = entry.value
  end
end

local renderState = {
  width = nil,
  height = nil,
  page = nil,
  rows = {},
  frameDrawn = false
}

local function chooseTextScale()
  return 1
end

local function setScaleAndGetSize()
  monitor.setTextScale(chooseTextScale())
  return monitor.getSize()
end

local function writeAt(x, y, text, fg, bg)
  if fg then monitor.setTextColor(fg) end
  if bg then monitor.setBackgroundColor(bg) end
  monitor.setCursorPos(x, y)
  monitor.write(text)
end

local function clearLine(y, bg)
  local w = select(1, monitor.getSize())
  monitor.setBackgroundColor(bg or colors.black)
  monitor.setCursorPos(1, y)
  monitor.write(string.rep(" ", w))
end

local function fillRect(x, y, w, h, bg)
  monitor.setBackgroundColor(bg or colors.black)
  for yy = y, y + h - 1 do
    monitor.setCursorPos(x, yy)
    monitor.write(string.rep(" ", w))
  end
end

local function centerText(y, text, fg, bg)
  local w = select(1, monitor.getSize())
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  writeAt(x, y, text, fg or colors.white, bg or colors.black)
end

local function rightText(y, text, fg, bg, margin)
  local w = select(1, monitor.getSize())
  local x = math.max(1, w - #text - (margin or 2) + 1)
  writeAt(x, y, text, fg or colors.white, bg or colors.black)
end

local function clip(text, maxLen)
  text = tostring(text or "")
  if maxLen <= 0 then return "" end
  if #text <= maxLen then return text end
  if maxLen <= 3 then return string.sub(text, 1, maxLen) end
  return string.sub(text, 1, maxLen - 3) .. "..."
end

local function fmtCompact(n)
  n = tonumber(n) or 0
  if n >= 1000000 then
    return ("%.1fm"):format(n / 1000000)
  elseif n >= 1000 then
    return ("%.1fk"):format(n / 1000)
  else
    return tostring(math.floor(n + 0.5))
  end
end

local function fmtPercent(p)
  return ("%d%%"):format(math.floor((p or 0) * 100 + 0.5))
end

local function pickColor(percent)
  if percent >= 0.90 then
    return colors.red
  elseif percent >= 0.75 then
    return colors.orange
  elseif percent >= 0.55 then
    return colors.yellow
  else
    return colors.lime
  end
end

local function drawRule(y)
  local w = select(1, monitor.getSize())
  writeAt(2, y, string.rep("-", math.max(1, w - 3)), colors.gray, colors.black)
end

local function drawBar(x, y, w, percent, fillColor, emptyColor)
  local p = math.max(0, math.min(1, percent or 0))
  local filled = math.floor(w * p + 0.5)

  if filled > 0 then
    writeAt(x, y, string.rep(" ", filled), colors.white, fillColor)
  end
  if filled < w then
    writeAt(x + filled, y, string.rep(" ", w - filled), colors.white, emptyColor or colors.gray)
  end
end

local function drawSplash(progress, current, total, label)
  local w, h = monitor.getSize()
  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()

  local titleY = math.max(2, math.floor(h / 2) - 3)
  local textY = titleY + 2
  local barY = textY + 2
  local infoY = barY + 2

  centerText(titleY, "Storage Dashboard", colors.cyan, colors.black)
  centerText(textY, "Scanning storage...", colors.lightGray, colors.black)

  local barW = math.max(10, math.min(w - 10, 40))
  local barX = math.floor((w - barW) / 2) + 1

  local p = math.max(0, math.min(1, progress or 0))
  local filled = math.floor(barW * p + 0.5)

  writeAt(barX - 1, barY, "[", colors.gray, colors.black)
  writeAt(barX + barW, barY, "]", colors.gray, colors.black)

  if filled > 0 then
    writeAt(barX, barY, string.rep(" ", filled), colors.white, colors.lime)
  end
  if filled < barW then
    writeAt(barX + filled, barY, string.rep(" ", barW - filled), colors.white, colors.gray)
  end

  local pctText = fmtPercent(p)
  centerText(infoY, ("%d/%d  (%s)"):format(current or 0, total or 0, pctText), colors.white, colors.black)

  if label and label ~= "" then
    centerText(infoY + 2, clip(label, math.max(10, w - 4)), colors.gray, colors.black)
  elseif CFG.chests and CFG.chests.input then
    centerText(infoY + 2, "Input: " .. tostring(CFG.chests.input), colors.gray, colors.black)
  end
end

local function scanChestMeta(name)
  if not peripheral.isPresent(name) or not peripheral.hasType(name, "inventory") then
    chestMeta[name] = {
      present = false,
      inv = nil,
      totalSlots = 0,
      maxItems = 0
    }
    return chestMeta[name]
  end

  local inv = peripheral.wrap(name)
  local totalSlots = inv.size()
  local firstSlotLimit = 0

  if totalSlots > 0 then
    firstSlotLimit = inv.getItemLimit(1) or 0
  end

  local maxItems = totalSlots * firstSlotLimit

  chestMeta[name] = {
    present = true,
    inv = inv,
    totalSlots = totalSlots,
    maxItems = maxItems
  }

  return chestMeta[name]
end

local function ensureChestMeta(name)
  local meta = chestMeta[name]
  if not meta then
    return scanChestMeta(name)
  end

  if not peripheral.isPresent(name) or not peripheral.hasType(name, "inventory") then
    return scanChestMeta(name)
  end

  if not meta.present then
    return scanChestMeta(name)
  end

  return meta
end

local function getChestUsage(name)
  local meta = ensureChestMeta(name)

  if not meta.present then
    return {
      present = false,
      usedItems = 0,
      usedSlots = 0,
      totalSlots = 0,
      maxItems = 0
    }
  end

  local ok, items = pcall(function()
    return meta.inv.list()
  end)

  if not ok then
    meta = scanChestMeta(name)
    if not meta.present then
      return {
        present = false,
        usedItems = 0,
        usedSlots = 0,
        totalSlots = 0,
        maxItems = 0
      }
    end
    items = meta.inv.list()
  end

  local usedItems = 0
  local usedSlots = 0

  for _, item in pairs(items) do
    usedItems = usedItems + item.count
    usedSlots = usedSlots + 1
  end

  return {
    present = true,
    usedItems = usedItems,
    usedSlots = usedSlots,
    totalSlots = meta.totalSlots,
    maxItems = meta.maxItems
  }
end

local function getCategoryStats(category)
  local usedItems = 0
  local maxItems = 0
  local usedSlots = 0
  local totalSlots = 0
  local missing = 0

  for _, chestName in ipairs(category.chests or {}) do
    local s = getChestUsage(chestName)

    if not s.present then
      missing = missing + 1
    end

    usedItems = usedItems + s.usedItems
    maxItems = maxItems + s.maxItems
    usedSlots = usedSlots + s.usedSlots
    totalSlots = totalSlots + s.totalSlots
  end

  local slotFullness = 0
  if totalSlots > 0 then
    slotFullness = usedSlots / totalSlots
  end

  local itemFullness = 0
  if maxItems > 0 then
    itemFullness = usedItems / maxItems
  end

  return {
    key = category.key or category.label,
    label = category.label or "Unknown",
    chestCount = #(category.chests or {}),
    missing = missing,
    usedItems = usedItems,
    maxItems = maxItems,
    usedSlots = usedSlots,
    totalSlots = totalSlots,
    freeSlots = math.max(0, totalSlots - usedSlots),
    slotFullness = slotFullness,
    itemFullness = itemFullness
  }
end

local function getRowsPerPage()
  return ROWS_PER_PAGE
end

local function getPageCount()
  local rowsPerPage = getRowsPerPage()
  return math.max(1, math.ceil(#categoryList / rowsPerPage))
end

local function getPageCategories(page)
  local rowsPerPage = getRowsPerPage()
  local startIndex = ((page - 1) * rowsPerPage) + 1
  local out = {}

  for i = startIndex, math.min(#categoryList, startIndex + rowsPerPage - 1) do
    out[#out + 1] = categoryList[i]
  end

  return out
end

local function getRowLayout(rowCount)
  local _, h = monitor.getSize()
  local top = 4
  local bottom = h - 1
  local areaH = bottom - top + 1

  local rowH = 4
  local usedH = rowH * rowCount
  local spare = areaH - usedH
  local startY = top + math.max(0, math.floor(spare / 2))

  local rows = {}
  local y = startY

  for i = 1, rowCount do
    rows[i] = { y = y, h = rowH }
    y = y + rowH
  end

  return rows
end

local function buildDisplayRow(stats)
  local line2Left = ("%d/%d chests  %d/%d slots  %d free"):format(
    stats.chestCount - stats.missing,
    stats.chestCount,
    stats.usedSlots,
    stats.totalSlots,
    stats.freeSlots
  )

  local line2Right = ("%s/%s items (%s)"):format(
    fmtCompact(stats.usedItems),
    fmtCompact(stats.maxItems),
    fmtPercent(stats.itemFullness)
  )

  local status
  if stats.slotFullness >= 0.90 then
    status = "Status: critical slot pressure"
  elseif stats.slotFullness >= 0.75 then
    status = "Status: getting tight"
  elseif stats.slotFullness >= 0.55 then
    status = "Status: moderate usage"
  else
    status = "Status: healthy"
  end

  if stats.missing > 0 then
    status = status .. (" | missing: %d chest(s)"):format(stats.missing)
  end

  return {
    key = stats.key,
    label = stats.label,
    percentText = fmtPercent(stats.slotFullness),
    infoLeft = line2Left,
    infoRight = line2Right,
    status = status,
    barPercent = math.floor(stats.slotFullness * 1000 + 0.5) / 1000,
    barColor = pickColor(stats.slotFullness)
  }
end

local function rowsEqual(a, b)
  if not a or not b then return false end
  return
    a.key == b.key and
    a.label == b.label and
    a.percentText == b.percentText and
    a.infoLeft == b.infoLeft and
    a.infoRight == b.infoRight and
    a.status == b.status and
    a.barPercent == b.barPercent and
    a.barColor == b.barColor
end

local function drawNavButtons(page, pageCount)
  if pageCount <= 1 then
    return
  end

  local w, h = monitor.getSize()

  writeAt(2, h, "< Prev", colors.black, colors.lightGray)
  local nextX = math.max(2, w - 6)
  writeAt(nextX, h, "Next >", colors.black, colors.lightGray)
end

local function drawFrame(page, pageCount)
  local _, h = monitor.getSize()

  monitor.setBackgroundColor(colors.black)
  monitor.setTextColor(colors.white)
  monitor.clear()

  centerText(1, "Storage Dashboard", colors.cyan, colors.black)

  local subtitle = "Input: " .. tostring(CFG.chests and CFG.chests.input or "?")
  if pageCount > 1 then
    subtitle = subtitle .. "   Page " .. page .. "/" .. pageCount
  end
  centerText(2, subtitle, colors.lightGray, colors.black)

  writeAt(2, 2, "Bar=slots  Text=items", colors.gray, colors.black)
  drawNavButtons(page, pageCount)
  drawRule(3)
  writeAt(2, 1, "Cats on page: " .. tostring(#getPageCategories(page)), colors.white, colors.black)
end

local function drawCategoryRow(displayRow, row)
  local w = select(1, monitor.getSize())
  local left = 3
  local right = w - 2
  local barW = math.max(10, right - left + 1)

  fillRect(1, row.y, w, row.h, colors.black)

  writeAt(left, row.y, clip(displayRow.label, math.max(8, barW - #displayRow.percentText - 2)), colors.white, colors.black)
  rightText(row.y, displayRow.percentText, colors.white, colors.black, 2)

  local leftMax = math.max(10, math.floor((w - 6) * 0.52))
  local rightMax = math.max(10, (w - 6) - leftMax)

  writeAt(left, row.y + 1, clip(displayRow.infoLeft, leftMax), colors.lightGray, colors.black)
  rightText(row.y + 1, clip(displayRow.infoRight, rightMax), colors.lightGray, colors.black, 2)

  drawBar(left, row.y + 2, barW, displayRow.barPercent, displayRow.barColor, colors.gray)
  writeAt(left, row.y + 3, clip(displayRow.status, barW), colors.gray, colors.black)
end

local function clearUnusedRows(oldRows, newCount, rowLayout)
  if not oldRows then return end
  local w = select(1, monitor.getSize())

  for i = newCount + 1, #oldRows do
    local row = rowLayout[i]
    if row then
      fillRect(1, row.y, w, row.h, colors.black)
    end
  end
end

local function scanAllChests()
  local unique = {}
  local ordered = {}

  for _, category in ipairs(categoryList) do
    for _, chestName in ipairs(category.chests or {}) do
      if not unique[chestName] then
        unique[chestName] = true
        ordered[#ordered + 1] = chestName
      end
    end
  end

  local total = #ordered

  if total == 0 then
    drawSplash(1, 0, 0, "No storage chests configured")
    return
  end

  local preloadCount = math.min(total, ROWS_PER_PAGE * 3)

  for i = 1, preloadCount do
    local chestName = ordered[i]
    drawSplash((i - 1) / preloadCount, i - 1, preloadCount, chestName)
    scanChestMeta(chestName)
    drawSplash(i / preloadCount, i, preloadCount, chestName)
  end
end

local function fullRedrawNeeded(w, h, page)
  return
    not renderState.frameDrawn or
    renderState.width ~= w or
    renderState.height ~= h or
    renderState.page ~= page
end

local function handleTouch(side, x, y, pageCount)
  if side ~= monitorName then
    return false
  end

  if pageCount <= 1 then
    return false
  end

  local w = select(1, monitor.getSize())
  local _, h = monitor.getSize()

  if y == h and x >= 2 and x <= 7 then
    currentPage = currentPage - 1
    if currentPage < 1 then
      currentPage = pageCount
    end
    renderState.frameDrawn = false
    return true
  end

  local nextX = math.max(2, w - 6)
  if y == h and x >= nextX and x <= w then
    currentPage = currentPage + 1
    if currentPage > pageCount then
      currentPage = 1
    end
    renderState.frameDrawn = false
    return true
  end

  return false
end

setScaleAndGetSize()
drawSplash(0, 0, 1, "Preparing scan...")
scanAllChests()
sleep(SPLASH_SECONDS)

while true do
  local w, h = setScaleAndGetSize()
  local pageCount = getPageCount()

  if currentPage > pageCount then
    currentPage = 1
  end

  local mustFullRedraw = fullRedrawNeeded(w, h, currentPage)
  local categories = getPageCategories(currentPage)
  local rowLayout = getRowLayout(#categories)
  local newRows = {}

  if mustFullRedraw then
    drawFrame(currentPage, pageCount)
  end

  for i, category in ipairs(categories) do
    local stats = getCategoryStats(category)
    local displayRow = buildDisplayRow(stats)
    newRows[i] = displayRow

    if mustFullRedraw or not rowsEqual(renderState.rows[i], displayRow) then
      drawCategoryRow(displayRow, rowLayout[i])
    end
  end

  renderState.width = w
  renderState.height = h
  renderState.page = currentPage
  renderState.rows = newRows
  renderState.frameDrawn = true

  local timer = os.startTimer(REFRESH_SECONDS)

  while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" and p1 == timer then
      break
    end

    if event == "monitor_touch" then
      local touchedMonitor = p1
      local x = p2
      local y = p3

      if handleTouch(touchedMonitor, x, y, pageCount) then
        break
      end
    end
  end
end
