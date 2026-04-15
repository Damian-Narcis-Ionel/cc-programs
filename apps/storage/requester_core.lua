local M = {}

function M.loadConfig()
  local cfg = dofile("/sorter_config.lua")

  if type(cfg) ~= "table" then
    error("sorter_config.lua did not return a table")
  end

  if type(cfg.chests) ~= "table" then
    error("sorter_config.lua is missing CFG.chests")
  end

  if type(cfg.categories) ~= "table" then
    error("sorter_config.lua is missing CFG.categories")
  end

  if type(cfg.requester) ~= "table" then
    error("sorter_config.lua is missing CFG.requester")
  end

  if type(cfg.chests.output) ~= "string" or cfg.chests.output == "" then
    error("sorter_config.lua is missing CFG.chests.output")
  end

  if type(cfg.requester.inventory_manager) ~= "string" or cfg.requester.inventory_manager == "" then
    error("sorter_config.lua is missing CFG.requester.inventory_manager")
  end

  if type(cfg.requester.output_direction) ~= "string" or cfg.requester.output_direction == "" then
    error("sorter_config.lua is missing CFG.requester.output_direction")
  end

  return cfg
end

function M.trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.normalize(text)
  return string.lower(M.trim(text))
end

function M.contains(haystack, needle)
  return string.find(haystack, needle, 1, true) ~= nil
end

function M.clip(text, maxLen)
  text = tostring(text or "")
  if #text <= maxLen then
    return text
  end
  if maxLen <= 3 then
    return text:sub(1, maxLen)
  end
  return text:sub(1, maxLen - 3) .. "..."
end

local function requireInventory(name, label)
  if not peripheral.isPresent(name) then
    error(label .. " not found: " .. tostring(name))
  end

  if not peripheral.hasType(name, "inventory") then
    error(label .. " is not an inventory: " .. tostring(name))
  end

  return peripheral.wrap(name)
end

local function requirePeripheral(name, label)
  if not peripheral.isPresent(name) then
    error(label .. " not found: " .. tostring(name))
  end

  return peripheral.wrap(name)
end

function M.createState(cfg)
  local output = requireInventory(cfg.chests.output, "Output chest")
  local manager = requirePeripheral(cfg.requester.inventory_manager, "Inventory manager")

  if type(manager.addItemToPlayer) ~= "function" then
    error("Configured inventory manager does not support addItemToPlayer: " .. tostring(cfg.requester.inventory_manager))
  end

  local seen = {
    [cfg.chests.input] = true,
    [cfg.chests.output] = true,
  }
  local storageChests = {}

  for _, category in ipairs(cfg.categories) do
    for _, chestName in ipairs(category.chests or {}) do
      if type(chestName) == "string" and chestName ~= "" and not seen[chestName] then
        seen[chestName] = true
        storageChests[#storageChests + 1] = chestName
      end
    end
  end

  table.sort(storageChests)

  return {
    cfg = cfg,
    output = output,
    manager = manager,
    storageChests = storageChests,
  }
end

function M.scanItems(state)
  local byName = {}

  for _, chestName in ipairs(state.storageChests) do
    if peripheral.isPresent(chestName) and peripheral.hasType(chestName, "inventory") then
      local inv = peripheral.wrap(chestName)
      local ok, items = pcall(function()
        return inv.list()
      end)

      if ok then
        for _, item in pairs(items) do
          local entry = byName[item.name]
          if not entry then
            entry = {
              name = item.name,
              displayName = item.displayName or item.name,
              total = 0,
            }
            byName[item.name] = entry
          end

          entry.total = entry.total + (tonumber(item.count) or 0)
          if item.displayName and item.displayName ~= "" then
            entry.displayName = item.displayName
          end
        end
      end
    end
  end

  local out = {}
  for _, entry in pairs(byName) do
    out[#out + 1] = entry
  end

  table.sort(out, function(a, b)
    local left = string.lower(a.displayName .. "|" .. a.name)
    local right = string.lower(b.displayName .. "|" .. b.name)
    if left ~= right then
      return left < right
    end
    return a.total > b.total
  end)

  return out
end

function M.searchItems(items, query)
  local q = M.normalize(query)
  local matches = {}

  for _, item in ipairs(items) do
    local nameLower = string.lower(item.name)
    local displayLower = string.lower(item.displayName or item.name)
    local score = nil

    if q == "" then
      score = 4
    elseif item.name == query then
      score = 0
    elseif nameLower == q or displayLower == q then
      score = 0
    elseif string.sub(nameLower, 1, #q) == q or string.sub(displayLower, 1, #q) == q then
      score = 1
    elseif M.contains(nameLower, q) or M.contains(displayLower, q) then
      score = 2
    end

    if score then
      matches[#matches + 1] = {
        score = score,
        item = item,
      }
    end
  end

  table.sort(matches, function(a, b)
    if a.score ~= b.score then
      return a.score < b.score
    end

    if a.item.total ~= b.item.total then
      return a.item.total > b.item.total
    end

    local left = string.lower(a.item.displayName .. "|" .. a.item.name)
    local right = string.lower(b.item.displayName .. "|" .. b.item.name)
    return left < right
  end)

  return matches
end

function M.gatherItemSources(state, targetName)
  local sources = {}
  local total = 0

  for _, chestName in ipairs(state.storageChests) do
    if peripheral.isPresent(chestName) and peripheral.hasType(chestName, "inventory") then
      local inv = peripheral.wrap(chestName)
      local ok, items = pcall(function()
        return inv.list()
      end)

      if ok then
        for slot, item in pairs(items) do
          if item.name == targetName then
            local count = tonumber(item.count) or 0
            if count > 0 then
              sources[#sources + 1] = {
                chest = chestName,
                slot = slot,
                count = count,
              }
              total = total + count
            end
          end
        end
      end
    end
  end

  table.sort(sources, function(a, b)
    if a.chest ~= b.chest then
      return a.chest < b.chest
    end
    return a.slot < b.slot
  end)

  return sources, total
end

function M.moveItemToOutput(state, itemName, requested)
  local sources, totalAvailable = M.gatherItemSources(state, itemName)
  local remaining = math.min(requested, totalAvailable)
  local moved = 0

  for _, source in ipairs(sources) do
    if remaining <= 0 then
      break
    end

    local sourceInv = peripheral.wrap(source.chest)
    local take = math.min(remaining, source.count)
    local ok, pushed = pcall(function()
      return sourceInv.pushItems(state.cfg.chests.output, source.slot, take)
    end)

    if not ok then
      pushed = 0
    end

    if pushed > 0 then
      moved = moved + pushed
      remaining = remaining - pushed
    end
  end

  return moved, totalAvailable
end

function M.countItemInOutput(state, itemName)
  local total = 0
  local ok, items = pcall(function()
    return state.output.list()
  end)

  if not ok then
    return 0
  end

  for _, item in pairs(items) do
    if item.name == itemName then
      total = total + (tonumber(item.count) or 0)
    end
  end

  return total
end

function M.deliverToPlayer(state, itemName, count)
  local ok, moved = pcall(function()
    return state.manager.addItemToPlayer(state.cfg.requester.output_direction, {
      name = itemName,
      count = count,
    })
  end)

  if not ok then
    return nil, moved
  end

  return tonumber(moved) or 0
end

function M.requestItem(state, itemName, requested)
  local staged, available = M.moveItemToOutput(state, itemName, requested)

  if staged <= 0 then
    return {
      ok = false,
      message = "Could not move the item into the output chest.",
      available = available,
      staged = 0,
      delivered = 0,
      waiting = 0,
    }
  end

  local delivered, err = M.deliverToPlayer(state, itemName, staged)
  if delivered == nil then
    local waiting = M.countItemInOutput(state, itemName)
    return {
      ok = false,
      message = "Inventory manager failed: " .. tostring(err),
      available = available,
      staged = staged,
      delivered = 0,
      waiting = waiting,
    }
  end

  local waiting = M.countItemInOutput(state, itemName)

  return {
    ok = true,
    message = "Request complete.",
    available = available,
    staged = staged,
    delivered = delivered,
    waiting = waiting,
  }
end

return M
