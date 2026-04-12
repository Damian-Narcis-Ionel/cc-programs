local CFG = dofile("/sorter_config.lua")

if not CFG or type(CFG) ~= "table" then
  error("sorter_config.lua did not return a table")
end

if not CFG.chests or not CFG.chests.input then
  error("sorter_config.lua is missing CFG.chests.input")
end

if not CFG.categories or type(CFG.categories) ~= "table" then
  error("sorter_config.lua is missing CFG.categories")
end

local INPUT = CFG.chests.input

local TARGETS = {}
for _, category in ipairs(CFG.categories) do
  if category.key and category.chests then
    TARGETS[category.key] = category.chests
  end
end

if not TARGETS.misc then
  error("Missing misc category in sorter_config.lua")
end

if not TARGETS.armory then
  error("Missing armory category in sorter_config.lua")
end

local function requireInventory(name, label)
  if not peripheral.isPresent(name) then
    error(label .. " not found: " .. name)
  end

  if not peripheral.hasType(name, "inventory") then
    error(label .. " is not an inventory: " .. name)
  end

  return peripheral.wrap(name)
end

local input = requireInventory(INPUT, "Input")

for category, chestList in pairs(TARGETS) do
  for i, name in ipairs(chestList) do
    requireInventory(name, category .. " chest #" .. i)
  end
end

local function contains(s, part)
  return string.find(s, part, 1, true) ~= nil
end

local farmExact = {
  ["minecraft:wheat_seeds"] = true,
  ["minecraft:beetroot_seeds"] = true,
  ["minecraft:pumpkin_seeds"] = true,
  ["minecraft:melon_seeds"] = true,

  ["minecraft:wheat"] = true,
  ["minecraft:carrot"] = true,
  ["minecraft:potato"] = true,
  ["minecraft:beetroot"] = true,
  ["minecraft:melon_slice"] = true,
  ["minecraft:apple"] = true,
  ["minecraft:cocoa_beans"] = true,
  ["minecraft:sugar_cane"] = true,
  ["minecraft:cactus"] = true,
  ["minecraft:honeycomb"] = true,
  ["minecraft:honey_bottle"] = true,

  ["minecraft:bucket"] = true,
  ["minecraft:water_bucket"] = true,
  ["minecraft:lava_bucket"] = true,
  ["minecraft:milk_bucket"] = true,
}

local oreExact = {
  ["minecraft:coal"] = true,
  ["minecraft:charcoal"] = true,
  ["minecraft:diamond"] = true,
  ["minecraft:emerald"] = true,
  ["minecraft:redstone"] = true,
  ["minecraft:lapis_lazuli"] = true,
  ["minecraft:quartz"] = true,
  ["minecraft:raw_iron"] = true,
  ["minecraft:raw_gold"] = true,
  ["minecraft:raw_copper"] = true,
  ["minecraft:iron_ingot"] = true,
  ["minecraft:gold_ingot"] = true,
  ["minecraft:copper_ingot"] = true,
  ["minecraft:netherite_ingot"] = true,
  ["minecraft:iron_nugget"] = true,
  ["minecraft:gold_nugget"] = true,
  ["minecraft:ancient_debris"] = true,
}

local mobExact = {
  ["minecraft:rotten_flesh"] = true,
  ["minecraft:bone"] = true,
  ["minecraft:string"] = true,
  ["minecraft:gunpowder"] = true,
  ["minecraft:spider_eye"] = true,
  ["minecraft:ender_pearl"] = true,
  ["minecraft:feather"] = true,
  ["minecraft:leather"] = true,
  ["minecraft:slime_ball"] = true,
  ["minecraft:phantom_membrane"] = true,
  ["minecraft:ghast_tear"] = true,
  ["minecraft:magma_cream"] = true,
  ["minecraft:blaze_rod"] = true,
  ["minecraft:blaze_powder"] = true,
  ["minecraft:prismarine_shard"] = true,
  ["minecraft:prismarine_crystals"] = true,
  ["minecraft:shulker_shell"] = true,
  ["minecraft:ink_sac"] = true,
  ["minecraft:glow_ink_sac"] = true,
  ["minecraft:nautilus_shell"] = true,
  ["minecraft:rabbit_hide"] = true,
  ["minecraft:rabbit_foot"] = true,
  ["minecraft:scute"] = true,
  ["minecraft:armadillo_scute"] = true,
  ["minecraft:turtle_scute"] = true,

  ["minecraft:porkchop"] = true,
  ["minecraft:cooked_porkchop"] = true,
  ["minecraft:beef"] = true,
  ["minecraft:cooked_beef"] = true,
  ["minecraft:chicken"] = true,
  ["minecraft:cooked_chicken"] = true,
  ["minecraft:mutton"] = true,
  ["minecraft:cooked_mutton"] = true,
  ["minecraft:rabbit"] = true,
  ["minecraft:cooked_rabbit"] = true,
  ["minecraft:cod"] = true,
  ["minecraft:cooked_cod"] = true,
  ["minecraft:salmon"] = true,
  ["minecraft:cooked_salmon"] = true,
  ["minecraft:tropical_fish"] = true,
  ["minecraft:pufferfish"] = true,
}

local function isArmory(name)
  return contains(name, "_pickaxe")
    or contains(name, "_axe")
    or contains(name, "_shovel")
    or contains(name, "_hoe")
    or contains(name, "_sword")
    or contains(name, "_helmet")
    or contains(name, "_chestplate")
    or contains(name, "_leggings")
    or contains(name, "_boots")
    or contains(name, "shield")
    or contains(name, "bow")
    or contains(name, "crossbow")
    or contains(name, "trident")
    or contains(name, "spear")
    or contains(name, "arrow")
    or contains(name, "bundle")
    or contains(name, "horse_armor")
end

local function isFlowers(name)
  if not contains(name, ":") then
    return false
  end

  if contains(name, "flora") then
    return true
  end

  return contains(name, "_flower")
    or contains(name, "flowering_")
    or contains(name, "flower")
    or contains(name, "petals")
    or contains(name, "grass")
    or contains(name, "fern")
    or contains(name, "bush")
    or contains(name, "blossom")
    or contains(name, "tulip")
    or contains(name, "dandelion")
    or contains(name, "poppy")
    or contains(name, "orchid")
    or contains(name, "allium")
    or contains(name, "azure_bluet")
    or contains(name, "oxeye_daisy")
    or contains(name, "cornflower")
    or contains(name, "lily_of_the_valley")
    or contains(name, "wither_rose")
    or contains(name, "sunflower")
    or contains(name, "lilac")
    or contains(name, "rose_bush")
    or contains(name, "peony")
    or contains(name, "pink_petals")
    or contains(name, "spore_blossom")
    or contains(name, "cactus_flower")
end

local function isFarm(name)
  if farmExact[name] then
    return true
  end

  return contains(name, "_seeds")
    or contains(name, "wheat")
    or contains(name, "carrot")
    or contains(name, "potato")
    or contains(name, "beetroot")
    or contains(name, "melon")
    or contains(name, "pumpkin")
    or contains(name, "tomato")
    or contains(name, "coffee")
    or contains(name, "pineapple")
    or contains(name, "cocoa")
    or contains(name, "sugar_cane")
    or contains(name, "apple")
    or contains(name, "berries")
    or contains(name, "onion")
    or contains(name, "bell_pepper")
    or contains(name, "honey")
    or contains(name, "pork")
    or contains(name, "beef")
    or contains(name, "chicken")
    or contains(name, "mutton")
    or contains(name, "rabbit")
    or contains(name, "cod")
    or contains(name, "salmon")
end

local function isMobs(name)
  if mobExact[name] then
    return true
  end

  return contains(name, "spawn_egg")
    or contains(name, "mob_head")
    or contains(name, "_head")
    or contains(name, "_horn")
end

local function isOre(name)
  if oreExact[name] then
    return true
  end

  return contains(name, "_ore")
    or contains(name, "raw_")
    or contains(name, "_ingot")
    or contains(name, "_nugget")
    or contains(name, "redstone")
    or contains(name, "lapis")
    or contains(name, "quartz")
end

local function isWood(name)
  return contains(name, "_log")
    or contains(name, "_wood")
    or contains(name, "_planks")
    or contains(name, "_stem")
    or contains(name, "_hyphae")
    or contains(name, "_slab")
    or contains(name, "_stairs")
    or contains(name, "_door")
    or contains(name, "_trapdoor")
    or contains(name, "_fence")
    or contains(name, "_fence_gate")
    or contains(name, "_pressure_plate")
    or contains(name, "_button")
    or contains(name, "_sign")
    or contains(name, "_hanging_sign")
    or contains(name, "_boat")
    or contains(name, "_chest_boat")
    or contains(name, "stick")
    or contains(name, "sapling")
    or contains(name, "ladder")
    or contains(name, "barrel")
    or contains(name, "crafting_table")
end

local function isBuilding(name)
  return contains(name, "dirt")
    or contains(name, "sand")
    or contains(name, "terracotta")
    or contains(name, "wool")
    or contains(name, "glass")
    or contains(name, "hay_block")
    or contains(name, "waxed_")
    or contains(name, "_candle")
    or contains(name, "honeycomb_block")
end

local function isStone(name)
  return contains(name, "cobble")
    or contains(name, "deepslate")
    or contains(name, "blackstone")
    or contains(name, "andesite")
    or contains(name, "granite")
    or contains(name, "diorite")
    or contains(name, "calcite")
    or contains(name, "basalt")
    or contains(name, "tuff")
    or contains(name, "stone")
    or contains(name, "brick")
end

local function classify(name)
  if isArmory(name) then
    return "armory"
  end

  if TARGETS.flowers and isFlowers(name) then
    return "flowers"
  end

  if TARGETS.mobs and isMobs(name) then
    return "mobs"
  end

  if isFarm(name) then
    return "farm"
  end

  if isOre(name) then
    return "ores"
  end

  if isWood(name) then
    return "wood"
  end

  if TARGETS.building and isBuilding(name) then
    return "building"
  end

  if isStone(name) then
    return "stone"
  end

  return "misc"
end

local function moveToAny(slot, chestList)
  for _, chestName in ipairs(chestList) do
    local moved = input.pushItems(chestName, slot)
    if moved > 0 then
      return moved, chestName
    end
  end

  return 0, nil
end

local function moveSlot(slot, item)
  local category = classify(item.name)
  local moved, target = moveToAny(slot, TARGETS[category])

  if moved == 0 and category ~= "misc" then
    moved, target = moveToAny(slot, TARGETS.misc)
    category = "misc"
  end

  if moved > 0 then
    print(("Moved %d x %s -> %s (%s)"):format(moved, item.name, category, target))
  else
    print(("No space for %s from slot %d"):format(item.name, slot))
  end
end

local function sortOnce()
  for slot, item in pairs(input.list()) do
    moveSlot(slot, item)
  end
end

print("Sorter running.")

while true do
  sortOnce()
  sleep(1)
end
