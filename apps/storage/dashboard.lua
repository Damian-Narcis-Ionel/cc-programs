local CFG = dofile("/sorter_config.lua")

if type(CFG) ~= "table" then
  error("sorter_config.lua did not return a table")
end

if not CFG.monitors then
  error("Missing CFG.monitors")
end

if not CFG.categories or type(CFG.categories) ~= "table" then
  error("Missing CFG.categories")
end

local function getDashboardNames(monitors)
  local out = {}
  local seen = {}

  if type(monitors.dashboards) == "table" then
    for _, name in ipairs(monitors.dashboards) do
      if type(name) == "string" and name ~= "" and not seen[name] then
        out[#out + 1] = name
        seen[name] = true
      end
    end
  end

  if #out == 0 and type(monitors.dashboard) == "string" and monitors.dashboard ~= "" then
    out[#out + 1] = monitors.dashboard
  end

  if #out == 0 then
    error("Missing CFG.monitors.dashboard or CFG.monitors.dashboards")
  end

  return out
end

local dashboardNames = getDashboardNames(CFG.monitors)
local dashboardStates = {}

for _, monitorName in ipairs(dashboardNames) do
  local monitor = peripheral.wrap(monitorName)
  if not monitor then
    error("Dashboard monitor not found: " .. tostring(monitorName))
  end

  dashboardStates[#dashboardStates + 1] = {
    name = monitorName,
    term = monitor,
    render = {
      width = nil,
      height = nil,
      page = nil,
      rows = {},
      frameDrawn = false,
    },
  }
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

local function chooseTextScale()
  return 1
end

local function setScaleAndGetSize(termObj)
  termObj.setTextScale(chooseTextScale())
  return termObj.getSize()
end

local function writeAt(termObj, x, y, text, fg, bg)
  if fg then termObj.setTextColor(fg) end
  if bg then termObj.setBackgroundColor(bg) end
  termObj.setCursorPos(x, y)
  termObj.write(text)
end

local function fillRect(termObj, x, y, w, h, bg)
  termObj.setBackgroundColor(bg or colors.black)
  for yy = y, y + h - 1 do
    termObj.setCursorPos(x, yy)
    termObj.write(string.rep(" ", w))
  end
end

local function centerText(termObj, y, text, fg, bg)
  local w = select(1, termObj.getSize())
  local x = math.max(1, math.floor((w - #text) / 2) + 1)
  writeAt(termObj, x, y, text, fg or colors.white, bg or colors.black)
end

local function rightText(termObj, y, text, fg, bg, margin)
  local w = select(1, termObj.getSize())
  local x = math.max(1, w - #text - (margin or 2) + 1)
  writeAt(termObj, x, y, text, fg or colors.white, bg or colors.black)
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

local function drawRule(termObj, y)
  local w = select(1, termObj.getSize())
  writeAt(termObj, 2, y, string.rep("-", math.max(1, w - 3)), colors.gray, colors.black)
end

local function drawBar(termObj, x, y, w, percent, fillColor, emptyColor)
  local p = math.max(0, math.min(1, percent or 0))
  local filled = math.floor(w * p + 0.5)

  if filled > 0 then
    writeAt(termObj, x, y, string.rep(" ", filled), colors.white, fillColor)
  end
  if filled < w then
    writeAt(termObj, x + filled, y, string.rep(" ", w - filled), colors.white, emptyColor or colors.gray)
  end
end

local function drawSplash(termObj, progress, current, total, label)
  local w, h = termObj.getSize()
  termObj.setBackgroundColor(colors.black)
  termObj.setTextColor(colors.white)
  termObj.clear()

  local titleY = math.max(2, math.floor(h / 2) - 3)
  local textY = titleY + 2
  local barY = textY + 2
  local infoY = barY + 2

  centerText(termObj, titleY, "Storage Dashboard", colors.cyan, colors.black)
  centerText(termObj, textY, "Scanning storage...", colors.lightGray, colors.black)

  local barW = math.max(10, math.min(w - 10, 40))
  local barX = math.floor((w - barW) / 2) + 1

  local p = math.max(0, math.min(1, progress or 0))
  local filled = math.floor(barW * p + 0.5)

  writeAt(termObj, barX - 1, barY, "[", colors.gray, colors.black)
  writeAt(termObj, barX + barW, barY, "]", colors.gray, colors.black)

  if filled > 0 then
    writeAt(termObj, barX, barY, string.rep(" ", filled), colors.white, colors.lime)
  end
  if filled < barW then
    writeAt(termObj, barX + filled, barY, string.rep(" ", barW - filled), colors.white, colors.gray)
  end

  centerText(termObj, infoY, ("%d/%d  (%s)"):format(current or 0, total or 0, fmtPercent(p)), colors.white, colors.black)

  if label and label ~= "" then
    centerText(termObj, infoY + 2, clip(label, math.max(10, w - 4)), colors.gray, colors.black)
  elseif CFG.chests and CFG.chests.input then
    centerText(termObj, infoY + 2, "Input: " .. tostring(CFG.chests.input), colors.gray, colors.black)
  end
end

local function scanChestMeta(name)
  if not peripheral.isPresent(name) or not peripheral.hasType(name, "inventory") then
    chestMeta[name] = {
      present = false,
      inv = nil,
      totalSlots = 0,
      maxItems = 0,
    }
    return chestMeta[name]
  end

  local inv = peripheral.wrap(name)
  local totalSlots = inv.size()
  local firstSlotLimit = 0

  if totalSlots > 0 then
    firstSlotLimit = inv.getItemLimit(1) or 0
  end

  chestMeta[name] = {
    present = true,
    inv = inv,
    totalSlots = totalSlots,
    maxItems = totalSlots * firstSlotLimit,
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
      maxItems = 0,
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
        maxItems = 0,
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
    maxItems = meta.maxItems,
  }
end

local function getCategoryStats(category)
  local usedItems = 0
  local maxItems = 0
  local usedSlots = 0
  local totalSlots = 0
  local missing = 0

  for _, chestName in ipairs(category.chests or {}) do
    local usage = getChestUsage(chestName)

    if not usage.present then
      missing = missing + 1
    end

    usedItems = usedItems + usage.usedItems
    maxItems = maxItems + usage.maxItems
    usedSlots = usedSlots + usage.usedSlots
    totalSlots = totalSlots + usage.totalSlots
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
    itemFullness = itemFullness,
  }
end

local function getRowsPerPage()
  return ROWS_PER_PAGE
end

local function getPageCount()
  return math.max(1, math.ceil(#categoryList / getRowsPerPage()))
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

local function getRowLayout(termObj, rowCount)
  local _, h = termObj.getSize()
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
    barColor = pickColor(stats.slotFullness),
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

local function drawNavButtons(termObj, pageCount)
  if pageCount <= 1 then
    return
  end

  local w, h = termObj.getSize()
  writeAt(termObj, 2, h, "< Prev", colors.black, colors.lightGray)
  writeAt(termObj, math.max(2, w - 6), h, "Next >", colors.black, colors.lightGray)
end

local function drawFrame(termObj, page, pageCount)
  local _, h = termObj.getSize()

  termObj.setBackgroundColor(colors.black)
  termObj.setTextColor(colors.white)
  termObj.clear()

  centerText(termObj, 1, "Storage Dashboard", colors.cyan, colors.black)

  local subtitle = "Input: " .. tostring(CFG.chests and CFG.chests.input or "?")
  if pageCount > 1 then
    subtitle = subtitle .. "   Page " .. page .. "/" .. pageCount
  end
  centerText(termObj, 2, subtitle, colors.lightGray, colors.black)

  writeAt(termObj, 2, 2, "Bar=slots  Text=items", colors.gray, colors.black)
  drawNavButtons(termObj, pageCount)
  drawRule(termObj, 3)
  writeAt(termObj, 2, 1, "Cats on page: " .. tostring(#getPageCategories(page)), colors.white, colors.black)
end

local function drawNoPage(termObj, pageCount)
  local _, h = termObj.getSize()

  termObj.setBackgroundColor(colors.black)
  termObj.setTextColor(colors.white)
  termObj.clear()

  centerText(termObj, 1, "Storage Dashboard", colors.cyan, colors.black)
  centerText(termObj, 2, "No more category pages", colors.lightGray, colors.black)
  if pageCount > 0 then
    centerText(termObj, 4, ("Total pages: %d"):format(pageCount), colors.white, colors.black)
  end
  drawNavButtons(termObj, pageCount)
  centerText(termObj, h, "Use Prev/Next to change page pair", colors.gray, colors.black)
end

local function drawCategoryRow(termObj, displayRow, row)
  local w = select(1, termObj.getSize())
  local left = 3
  local right = w - 2
  local barW = math.max(10, right - left + 1)

  fillRect(termObj, 1, row.y, w, row.h, colors.black)

  writeAt(termObj, left, row.y, clip(displayRow.label, math.max(8, barW - #displayRow.percentText - 2)), colors.white, colors.black)
  rightText(termObj, row.y, displayRow.percentText, colors.white, colors.black, 2)

  local leftMax = math.max(10, math.floor((w - 6) * 0.52))
  local rightMax = math.max(10, (w - 6) - leftMax)

  writeAt(termObj, left, row.y + 1, clip(displayRow.infoLeft, leftMax), colors.lightGray, colors.black)
  rightText(termObj, row.y + 1, clip(displayRow.infoRight, rightMax), colors.lightGray, colors.black, 2)

  drawBar(termObj, left, row.y + 2, barW, displayRow.barPercent, displayRow.barColor, colors.gray)
  writeAt(termObj, left, row.y + 3, clip(displayRow.status, barW), colors.gray, colors.black)
end

local function clearUnusedRows(termObj, oldRows, newCount, rowLayout)
  if not oldRows then return end
  local w = select(1, termObj.getSize())

  for i = newCount + 1, #oldRows do
    local row = rowLayout[i]
    if row then
      fillRect(termObj, 1, row.y, w, row.h, colors.black)
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
    for _, state in ipairs(dashboardStates) do
      drawSplash(state.term, 1, 0, 0, "No storage chests configured")
    end
    return
  end

  local preloadCount = math.min(total, ROWS_PER_PAGE * 3)

  for i = 1, preloadCount do
    local chestName = ordered[i]
    for _, state in ipairs(dashboardStates) do
      drawSplash(state.term, (i - 1) / preloadCount, i - 1, preloadCount, chestName)
    end
    scanChestMeta(chestName)
    for _, state in ipairs(dashboardStates) do
      drawSplash(state.term, i / preloadCount, i, preloadCount, chestName)
    end
  end
end

local function fullRedrawNeeded(renderState, w, h, page)
  return
    not renderState.frameDrawn or
    renderState.width ~= w or
    renderState.height ~= h or
    renderState.page ~= page
end

local function renderPageOnMonitor(state, page, pageCount)
  local termObj = state.term
  local renderState = state.render
  local w, h = setScaleAndGetSize(termObj)

  if page > pageCount then
    drawNoPage(termObj, pageCount)
    renderState.width = w
    renderState.height = h
    renderState.page = page
    renderState.rows = {}
    renderState.frameDrawn = true
    return
  end

  local mustFullRedraw = fullRedrawNeeded(renderState, w, h, page)
  local categories = getPageCategories(page)
  local rowLayout = getRowLayout(termObj, #categories)
  local newRows = {}

  if mustFullRedraw then
    drawFrame(termObj, page, pageCount)
  end

  for i, category in ipairs(categories) do
    local displayRow = buildDisplayRow(getCategoryStats(category))
    newRows[i] = displayRow

    if mustFullRedraw or not rowsEqual(renderState.rows[i], displayRow) then
      drawCategoryRow(termObj, displayRow, rowLayout[i])
    end
  end

  clearUnusedRows(termObj, renderState.rows, #newRows, rowLayout)

  renderState.width = w
  renderState.height = h
  renderState.page = page
  renderState.rows = newRows
  renderState.frameDrawn = true
end

local function getPagesPerView()
  return math.max(1, #dashboardStates)
end

local function getLastPageGroupStart(pageCount)
  local pagesPerView = getPagesPerView()
  return math.max(1, (math.floor((pageCount - 1) / pagesPerView) * pagesPerView) + 1)
end

local function invalidateAllFrames()
  for _, state in ipairs(dashboardStates) do
    state.render.frameDrawn = false
  end
end

local function handleTouch(side, x, y, pageCount)
  if pageCount <= 1 then
    return false
  end

  local touchedState = nil
  for _, state in ipairs(dashboardStates) do
    if state.name == side then
      touchedState = state
      break
    end
  end

  if not touchedState then
    return false
  end

  local w = select(1, touchedState.term.getSize())
  local _, h = touchedState.term.getSize()

  if y == h and x >= 2 and x <= 7 then
    currentPage = currentPage - getPagesPerView()
    if currentPage < 1 then
      currentPage = getLastPageGroupStart(pageCount)
    end
    invalidateAllFrames()
    return true
  end

  local nextX = math.max(2, w - 6)
  if y == h and x >= nextX and x <= w then
    currentPage = currentPage + getPagesPerView()
    if currentPage > pageCount then
      currentPage = 1
    end
    invalidateAllFrames()
    return true
  end

  return false
end

for _, state in ipairs(dashboardStates) do
  setScaleAndGetSize(state.term)
  drawSplash(state.term, 0, 0, 1, "Preparing scan...")
end

scanAllChests()
sleep(SPLASH_SECONDS)
print("Dashboard is active !")

while true do
  local pageCount = getPageCount()

  if currentPage > pageCount then
    currentPage = 1
  end

  for index, state in ipairs(dashboardStates) do
    renderPageOnMonitor(state, currentPage + (index - 1), pageCount)
  end

  local timer = os.startTimer(REFRESH_SECONDS)

  while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "timer" and p1 == timer then
      break
    end

    if event == "monitor_touch" and handleTouch(p1, p2, p3, pageCount) then
      break
    end
  end
end
