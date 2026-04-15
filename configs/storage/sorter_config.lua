-- sorter_config.lua
local function chest(id)
  return ("minecraft:chest_%d"):format(id)
end

local chests = {
  input = chest(79),
  output = "minecraft:chest_output",
}

local monitors = {
  dashboards = {
    "monitor_0",
    "monitor_12",
  },

  dashboard = "monitor_0",

  stone = "monitor_6",
  wood = "monitor_7",
  farm = "monitor_8",
  ores = "monitor_9",
  mobs = "monitor_10",
  armory = "monitor_11",
  building = "monitor_5",
  blocks = "monitor_4",
  flowers = "monitor_3",
  misc = "monitor_2",
  dem = "monitor_1",
}

local requester = {
  inventory_manager = "inventoryManager_0",
  output_direction = "front",
  rednet_protocol = "cc_storage_requester",
}

return {
  chests = chests,
  monitors = monitors,
  requester = requester,

  categories = {
    { key = "stone", label = "Stone", desired = 7, chests = {
      chest(4), chest(3), chest(5), chest(6), chest(7), chest(9), chest(8)
    }},

    { key = "wood", label = "Wood", desired = 7, chests = {
      chest(16), chest(15), chest(14), chest(13), chest(12), chest(11), chest(10)
    }},

    { key = "farm", label = "Farm", desired = 7, chests = {
      chest(17), chest(18), chest(20), chest(19), chest(21), chest(23), chest(22)
    }},

    { key = "ores", label = "Ores", desired = 7, chests = {
      chest(24), chest(25), chest(26), chest(27), chest(28), chest(29), chest(30)
    }},

    { key = "mobs", label = "Mob", desired = 7, chests = {
      chest(31), chest(32), chest(33), chest(34), chest(35), chest(36), chest(37)
    }},

    { key = "armory", label = "Armory", desired = 7, chests = {
      chest(38), chest(39), chest(40), chest(41), chest(42), chest(43), chest(44)
    }},

    { key = "building", label = "Building", desired = 7, chests = {
      chest(45), chest(46), chest(47), chest(48), chest(49), chest(50), chest(51)
    }},

    { key = "blocks", label = "Blocks", desired = 7, chests = {
      chest(52), chest(53), chest(54), chest(55), chest(56), chest(57), chest(58)
    }},

    { key = "flowers", label = "Flowers", desired = 7, chests = {
      chest(59), chest(60), chest(61), chest(62), chest(63), chest(64), chest(65)
    }},

    { key = "misc", label = "Misc", desired = 7, chests = {
      chest(71), chest(2), chest(70), chest(69), chest(68), chest(67), chest(66)
    }},

    { key = "dem", label = "Dem", desired = 7, chests = {
      chest(72), chest(73), chest(74), chest(75), chest(76), chest(77), chest(78)
    }},
  }
}
