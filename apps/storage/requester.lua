local core = dofile("disk/apps/storage/requester_core.lua")

local cfg = core.loadConfig()
local state = core.createState(cfg)

local function printHeader(items)
  term.clear()
  term.setCursorPos(1, 1)
  print("Storage Requester")
  print("Type part of an item name. Commands: /refresh /quit")
  print(("Indexed %d unique items across %d chests."):format(#items, #state.storageChests))
  print("")
end

local function prompt(label)
  write(label)
  return read()
end

local function chooseMatch(matches)
  local shown = math.min(#matches, 9)

  for i = 1, shown do
    local item = matches[i].item
    print(("%d. %s x%d"):format(i, core.clip(item.displayName, 28), item.total))
    print("   " .. core.clip(item.name, 46))
  end

  if #matches > shown then
    print(("Showing first %d of %d matches. Narrow the search if needed."):format(shown, #matches))
  end

  print("")
  local answer = core.trim(prompt("Pick 1-" .. shown .. " or blank to cancel: "))
  if answer == "" then
    return nil
  end

  local index = tonumber(answer)
  if not index or index < 1 or index > shown then
    print("Invalid selection.")
    sleep(1)
    return nil
  end

  return matches[index].item
end

local function askCount(maxCount)
  local answer = core.trim(prompt("Amount (default 1, 'all' for " .. maxCount .. "): "))

  if answer == "" then
    return 1
  end

  if string.lower(answer) == "all" then
    return maxCount
  end

  local count = tonumber(answer)
  if not count or count < 1 then
    print("Invalid amount.")
    sleep(1)
    return nil
  end

  return math.min(math.floor(count), maxCount)
end

local function runOnce(items)
  printHeader(items)
  local query = core.trim(prompt("Search: "))

  if query == "" then
    return items, true
  end

  if query == "/quit" then
    return items, false
  end

  if query == "/refresh" then
    print("")
    print("Refreshing item index...")
    sleep(0.4)
    return core.scanItems(state), true
  end

  local matches = core.searchItems(items, query)
  print("")

  if #matches == 0 then
    print("No matching items found.")
    sleep(1)
    return items, true
  end

  local selected = matches[1].item
  if #matches > 1 then
    selected = chooseMatch(matches)
    if not selected then
      return items, true
    end
  else
    print(("Match: %s (%s) x%d"):format(selected.displayName, selected.name, selected.total))
  end

  print("")
  local requested = askCount(selected.total)
  if not requested then
    return items, true
  end

  print("")
  print(("Requesting %d x %s"):format(requested, selected.displayName))
  local result = core.requestItem(state, selected.name, requested)

  print(("Available now: %d"):format(result.available))
  print(("Moved to output chest: %d"):format(result.staged))
  print(("Delivered to player: %d"):format(result.delivered))

  if result.waiting > 0 then
    print(("Still in output chest: %d"):format(result.waiting))
  end

  if not result.ok then
    print(result.message)
  end

  sleep(2)
  return core.scanItems(state), true
end

print("Requester starting...")
sleep(0.2)

local items = core.scanItems(state)
local continueRunning = true

while true do
  items, continueRunning = runOnce(items)
  if not continueRunning then
    term.clear()
    term.setCursorPos(1, 1)
    print("Requester stopped.")
    break
  end
end
