local args = { ... }
local PROTOCOL = args[1] or "cc_storage_requester"

local function trim(text)
  return (tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function clip(text, maxLen)
  text = tostring(text or "")
  if #text <= maxLen then
    return text
  end
  if maxLen <= 3 then
    return text:sub(1, maxLen)
  end
  return text:sub(1, maxLen - 3) .. "..."
end

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
  error("No wireless modem found on pocket computer.")
end

if not rednet.isOpen(modemName) then
  rednet.open(modemName)
end

local function clear()
  term.clear()
  term.setCursorPos(1, 1)
end

local function prompt(label)
  write(label)
  return read()
end

local function await(action, timeout)
  local timer = os.startTimer(timeout or 4)

  while true do
    local event, p1, p2, p3 = os.pullEvent()

    if event == "rednet_message" then
      local senderId = p1
      local message = p2
      local protocol = p3

      if protocol == PROTOCOL and type(message) == "table" and message.action == action then
        return senderId, message
      end
    elseif event == "timer" and p1 == timer then
      return nil, nil
    end
  end
end

local function findServer()
  rednet.broadcast({ action = "ping" }, PROTOCOL)
  return await("pong", 2)
end

local function chooseMatch(matches)
  local shown = math.min(#matches, 9)

  for i = 1, shown do
    local item = matches[i]
    print(("%d. %s x%d"):format(i, clip(item.displayName, 24), item.total))
    print("   " .. clip(item.name, 30))
  end

  if #matches > shown then
    print(("Showing first %d matches. Narrow the search if needed."):format(shown))
  end

  print("")
  local answer = trim(prompt("Pick 1-" .. shown .. " or blank: "))
  if answer == "" then
    return nil
  end

  local index = tonumber(answer)
  if not index or index < 1 or index > shown then
    return nil
  end

  return matches[index]
end

local function askCount(maxCount)
  local answer = trim(prompt("Amount (default 1, all): "))

  if answer == "" then
    return 1
  end

  if string.lower(answer) == "all" then
    return maxCount
  end

  local count = tonumber(answer)
  if not count or count < 1 then
    return nil
  end

  return math.min(math.floor(count), maxCount)
end

local function sendAndWait(serverId, payload, expectedAction, timeout)
  rednet.send(serverId, payload, PROTOCOL)
  local senderId, message = await(expectedAction, timeout)

  if not senderId then
    return nil, "Timed out waiting for server response."
  end

  if senderId ~= serverId then
    return nil, "Received response from unexpected computer."
  end

  return message
end

local function performRequest(serverId, selected, count)
  local result, err = sendAndWait(serverId, {
    action = "request",
    name = selected.name,
    count = count,
  }, "request_result", 12)

  clear()
  if not result then
    print(err or "Timed out waiting for request result.")
    sleep(2)
    return
  end

  print(("Requested %d x %s"):format(result.requested or count, selected.displayName))
  print(("Staged: %d"):format(result.staged or 0))
  print(("Delivered: %d"):format(result.delivered or 0))
  if (result.waiting or 0) > 0 then
    print(("Waiting in output chest: %d"):format(result.waiting))
  end
  if result.message then
    print(result.message)
  end
  sleep(2)
end

local function run(serverId, serverInfo)
  while true do
    clear()
    print("Pocket Requester")
    print(("Server: %s (%d)"):format(serverInfo.label or "unnamed", serverId))
    print("Commands: /refresh /quit")
    print("")

    local query = trim(prompt("Search: "))
    if query == "" then
      -- continue
    elseif query == "/quit" then
      return
    elseif query == "/refresh" then
      local response, err = sendAndWait(serverId, { action = "refresh" }, "refresh_result", 8)
      clear()
      if not response then
        print(err)
      else
        print(("Refreshed. Indexed %d unique items."):format(response.count or 0))
      end
      sleep(1.2)
    else
      local response, err = sendAndWait(serverId, {
        action = "search",
        query = query,
        limit = 8,
      }, "search_result", 8)

      clear()

      if not response then
        print(err)
        sleep(1.5)
      elseif not response.matches or #response.matches == 0 then
        print("No matching items found.")
        sleep(1.2)
      else
        print(("Matches for '%s': %d"):format(response.query or query, response.total_matches or #response.matches))
        print("")

        local selected = response.matches[1]
        if #response.matches > 1 then
          selected = chooseMatch(response.matches)
          if not selected then
            sleep(0.2)
          else
            local count = askCount(selected.total)
            if count then
              performRequest(serverId, selected, count)
            end
          end
        else
          local count = askCount(selected.total)
          if count then
            performRequest(serverId, selected, count)
          end
        end
      end
    end
  end
end

clear()
print("Pocket Requester")
print("Searching for server...")

local serverId, serverInfo = findServer()
if not serverId then
  error("No requester server responded on rednet.")
end

run(serverId, serverInfo or {})
