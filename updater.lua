local args = { ... }

local ok, CFG = pcall(dofile, "/updater_config.lua")
if not ok then
  error("Could not load /updater_config.lua: " .. tostring(CFG))
end

local DISK_MOUNT = CFG.disk_mount or "disk"
local BOOTSTRAP = CFG.bootstrap or {}
local APPS = CFG.apps or {}
local GITHUB = CFG.github or {}

local function sortedKeys(tbl)
  local keys = {}
  for key in pairs(tbl) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function joinPath(a, b)
  if a:sub(-1) == "/" then
    return a .. b
  end
  return a .. "/" .. b
end

local function ensureParentDir(path)
  local dir = fs.getDir(path)
  if dir ~= "" and not fs.exists(dir) then
    fs.makeDir(dir)
  end
end

local function ensureDiskMounted()
  if not fs.exists(DISK_MOUNT) or not fs.isDir(DISK_MOUNT) then
    error("Disk mount '" .. DISK_MOUNT .. "' not found. Insert the floppy first.")
  end
end

local function buildGitHubRawUrl(entry)
  if type(entry.url) == "string" and entry.url ~= "" then
    return entry.url
  end

  local owner = entry.owner or GITHUB.owner
  local repo = entry.repo or GITHUB.repo
  local branch = entry.branch or GITHUB.branch or "main"
  local path = entry.path or entry.file

  if type(owner) ~= "string" or owner == "" then
    return nil, "Missing GitHub owner"
  end

  if type(repo) ~= "string" or repo == "" then
    return nil, "Missing GitHub repo"
  end

  if type(path) ~= "string" or path == "" then
    return nil, "Missing GitHub file path"
  end

  return ("https://raw.githubusercontent.com/%s/%s/%s/%s"):format(owner, repo, branch, path)
end

local function downloadUrl(url, label)
  if not http then
    error("HTTP API is not available.")
  end

  local response, err = http.get(url)
  if not response then
    error("Failed to download " .. label .. ": " .. tostring(err))
  end

  local text = response.readAll()
  response.close()

  if not text or text == "" then
    error("Downloaded empty content from " .. label .. ".")
  end

  return text
end

local function writeFile(path, text)
  ensureParentDir(path)

  local file = fs.open(path, "w")
  if not file then
    error("Could not open " .. path .. " for writing.")
  end

  file.write(text)
  file.close()
end

local function installEntry(label, targetPath, entry)
  local tempPath = targetPath .. ".new"
  local preserve = entry.preserve_existing == true
  local existed = fs.exists(targetPath)

  if preserve and existed then
    print("Keeping existing " .. label .. " -> " .. targetPath)
    return
  end

  if existed then
    print("Updating " .. label .. " -> " .. targetPath)
  else
    print("Installing " .. label .. " -> " .. targetPath)
  end

  local githubUrl, githubErr = buildGitHubRawUrl(entry)
  local text

  if githubUrl then
    text = downloadUrl(githubUrl, githubUrl)
  elseif type(entry.code) == "string" and entry.code ~= "" then
    local pasteUrl = "https://pastebin.com/raw/" .. entry.code
    text = downloadUrl(pasteUrl, pasteUrl)
  else
    error(label .. " is missing a GitHub source and Pastebin code" .. (githubErr and (": " .. githubErr) or "."))
  end

  if fs.exists(tempPath) then
    fs.delete(tempPath)
  end

  writeFile(tempPath, text)

  if existed then
    fs.delete(targetPath)
  end

  fs.move(tempPath, targetPath)

  if existed then
    print("Updated " .. label)
  else
    print("Installed " .. label)
  end
end

local function makeBootstrapJob(name, entry)
  return {
    kind = "bootstrap",
    name = name,
    label = "bootstrap:" .. name,
    targetPath = entry.target or ("/" .. (entry.file or (name .. ".lua"))),
    entry = entry,
    needsDisk = false,
  }
end

local function makeProgramJob(appName, app, name, entry)
  local diskDir = app.disk_dir or ("apps/" .. appName)
  local fileName = entry.file or (name .. ".lua")
  return {
    kind = "program",
    name = appName .. ":" .. name,
    label = appName .. ":" .. name,
    targetPath = joinPath(DISK_MOUNT, joinPath(diskDir, fileName)),
    entry = entry,
    needsDisk = true,
  }
end

local function makeConfigJob(appName, name, entry)
  return {
    kind = "config",
    name = appName .. ":" .. name,
    label = appName .. ":" .. name,
    targetPath = entry.target or ("/" .. (entry.file or (name .. ".lua"))),
    entry = entry,
    needsDisk = false,
  }
end

local function extendWithAppJobs(jobs, appName)
  local app = APPS[appName]
  if not app then
    error("Unknown app: " .. tostring(appName))
  end

  for _, name in ipairs(sortedKeys(app.programs or {})) do
    jobs[#jobs + 1] = makeProgramJob(appName, app, name, app.programs[name])
  end

  for _, name in ipairs(sortedKeys(app.configs or {})) do
    jobs[#jobs + 1] = makeConfigJob(appName, name, app.configs[name])
  end
end

local function resolveTarget(arg)
  local jobs = {}

  if BOOTSTRAP[arg] then
    jobs[#jobs + 1] = makeBootstrapJob(arg, BOOTSTRAP[arg])
    return jobs
  end

  if APPS[arg] then
    extendWithAppJobs(jobs, arg)
    return jobs
  end

  local appName, targetName = string.match(arg, "^([^:]+):(.+)$")
  if not appName or not targetName then
    error("Unknown target: " .. tostring(arg))
  end

  local app = APPS[appName]
  if not app then
    error("Unknown app: " .. tostring(appName))
  end

  if app.programs and app.programs[targetName] then
    jobs[#jobs + 1] = makeProgramJob(appName, app, targetName, app.programs[targetName])
    return jobs
  end

  if app.configs and app.configs[targetName] then
    jobs[#jobs + 1] = makeConfigJob(appName, targetName, app.configs[targetName])
    return jobs
  end

  error("Unknown target '" .. targetName .. "' in app '" .. appName .. "'")
end

local function usage()
  print("Usage:")
  print("  updater all")
  print("  updater <app>")
  print("  updater <app>:<target>")
  print("  updater <bootstrap>")
  print("")

  if next(BOOTSTRAP) then
    print("Bootstrap targets:")
    for _, name in ipairs(sortedKeys(BOOTSTRAP)) do
      local entry = BOOTSTRAP[name]
      print("  " .. name .. " -> " .. (entry.target or ("/" .. (entry.file or (name .. ".lua")))))
    end
    print("")
  end

  print("Apps:")
  for _, appName in ipairs(sortedKeys(APPS)) do
    local app = APPS[appName]
    print("  " .. appName .. " -> " .. (app.label or appName))

    for _, name in ipairs(sortedKeys(app.programs or {})) do
      local entry = app.programs[name]
      local diskDir = app.disk_dir or ("apps/" .. appName)
      local fileName = entry.file or (name .. ".lua")
      print("    " .. appName .. ":" .. name .. " -> " .. joinPath(DISK_MOUNT, joinPath(diskDir, fileName)))
    end

    for _, name in ipairs(sortedKeys(app.configs or {})) do
      local entry = app.configs[name]
      print("    " .. appName .. ":" .. name .. " -> " .. (entry.target or ("/" .. (entry.file or (name .. ".lua")))))
    end
  end
end

if #args == 0 then
  usage()
  return
end

local jobs = {}

if #args == 1 and args[1] == "all" then
  for _, name in ipairs(sortedKeys(BOOTSTRAP)) do
    jobs[#jobs + 1] = makeBootstrapJob(name, BOOTSTRAP[name])
  end

  for _, appName in ipairs(sortedKeys(APPS)) do
    extendWithAppJobs(jobs, appName)
  end
else
  for i = 1, #args do
    local resolved = resolveTarget(args[i])
    for _, job in ipairs(resolved) do
      jobs[#jobs + 1] = job
    end
  end
end

local needsDisk = false
for _, job in ipairs(jobs) do
  if job.needsDisk then
    needsDisk = true
    break
  end
end

if needsDisk then
  ensureDiskMounted()
end

for _, job in ipairs(jobs) do
  installEntry(job.label, job.targetPath, job.entry)
end

print("")
print("Done.")
print("Restart any running programs to use the new version.")
