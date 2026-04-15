local core = dofile("disk/apps/storage/requester_core.lua")

local cfg = core.loadConfig()
local state = core.createState(cfg)
local protocol = cfg.requester.rednet_protocol or "cc_storage_requester"

local function findWirelessModem()
  for _, name in ipairs(peripheral.getNames()) do
    if peripheral.hasType(name, "modem") then
      local modem = peripheral.wrap(name)
      if modem.isWireless and modem.isWireless() then
        return name
      end
    end
  end

  return nil
end

local modemName = findWirelessModem()
if not modemName then
  error("No wireless modem found for requester server.")
end

if not rednet.isOpen(modemName) then
  rednet.open(modemName)
end

local indexedItems = core.scanItems(state)

local function summarizeMatches(matches, limit)
  local out = {}
  local shown = math.min(#matches, limit or 8)

  for i = 1, shown do
    local item = matches[i].item
    out[#out + 1] = {
      name = item.name,
      displayName = item.displayName,
      total = item.total,
    }
  end

  return out
end

local function log(text)
  print(text)
end

local function handleMessage(senderId, message)
  if type(message) ~= "table" then
    return
  end

  if message.action == "ping" then
    rednet.send(senderId, {
      ok = true,
      action = "pong",
      label = os.getComputerLabel(),
      id = os.getComputerID(),
    }, protocol)
    return
  end

  if message.action == "refresh" then
    indexedItems = core.scanItems(state)
    rednet.send(senderId, {
      ok = true,
      action = "refresh_result",
      count = #indexedItems,
    }, protocol)
    log(("Refreshed index for pocket %d."):format(senderId))
    return
  end

  if message.action == "search" then
    local query = core.trim(message.query)
    local matches = core.searchItems(indexedItems, query)
    rednet.send(senderId, {
      ok = true,
      action = "search_result",
      query = query,
      total_matches = #matches,
      matches = summarizeMatches(matches, tonumber(message.limit) or 8),
    }, protocol)
    log(("Search from pocket %d: %s (%d matches)"):format(senderId, query, #matches))
    return
  end

  if message.action == "request" then
    local itemName = core.trim(message.name)
    local requested = tonumber(message.count) or 1
    requested = math.max(1, math.floor(requested))

    local result = core.requestItem(state, itemName, requested)
    indexedItems = core.scanItems(state)

    rednet.send(senderId, {
      ok = result.ok,
      action = "request_result",
      name = itemName,
      requested = requested,
      available = result.available,
      staged = result.staged,
      delivered = result.delivered,
      waiting = result.waiting,
      message = result.message,
    }, protocol)

    log(("Request from pocket %d: %d x %s -> staged %d, delivered %d"):format(
      senderId,
      requested,
      itemName,
      result.staged,
      result.delivered
    ))
  end
end

term.clear()
term.setCursorPos(1, 1)
print("Requester server running.")
print("Computer ID: " .. os.getComputerID())
print("Wireless modem: " .. modemName)
print("Protocol: " .. protocol)
print(("Indexed %d unique items across %d chests."):format(#indexedItems, #state.storageChests))
print("")

while true do
  local senderId, message = rednet.receive(protocol)
  handleMessage(senderId, message)
end
