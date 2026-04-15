# Storage App

The storage app provides:
- automatic item sorting into storage categories
- a dashboard monitor with slot-based fullness stats
- paged dual-dashboard support across two large monitors
- per-category label monitors
- an interactive setup flow for chest and label monitor assignment
- a permanent requester terminal for searching storage and pulling items to the player through Advanced Peripherals
- a rednet requester server and pocket client for remote item requests

## Programs

- `sorter.lua`: main sorting loop
- `dashboard.lua`: dashboard display
- `labels.lua`: category label display
- `requester.lua`: terminal-based item search and retrieval
- `requester_server.lua`: rednet server for remote requests from pocket computers
- `requester_pocket.lua`: pocket client for remote search and request
- `requester_core.lua`: shared requester logic
- `setup_storage.lua`: interactive storage setup

## Config

The live config for this app is stored on the computer at:

```text
/sorter_config.lua
```

The template shipped in the repo lives at:

```text
configs/storage/sorter_config.lua
```

`setup_storage.lua` reads and writes `/sorter_config.lua`.

The requester also expects:

```lua
chests = {
  input = "minecraft:chest_input",
  output = "minecraft:chest_output",
}

requester = {
  inventory_manager = "inventoryManager_0",
  output_direction = "front",
  rednet_protocol = "cc_storage_requester",
}
```

`output` must be a dedicated retrieval chest.
Do not reuse the sorter input chest for requester output while the sorter is running.

`inventory_manager` must be an Advanced Peripherals `inventoryManager`.
`output_direction` is the side of the chest relative to the inventory manager peripheral, not the computer.
`rednet_protocol` is the protocol name used between the base computer and pocket client.

Dashboard monitors are configured in:

```lua
monitors = {
  dashboards = {
    "monitor_left",
    "monitor_right",
  },
  dashboard = "monitor_left",
}
```

`dashboard.lua` uses `monitors.dashboards` when present and falls back to `monitors.dashboard` for older configs.

## Installation

Install the whole app:

```lua
/updater.lua storage
```

That installs the programs to:

```text
disk/apps/storage/
```

It also installs `/sorter_config.lua` if it does not already exist.

## Interactive Setup

Run:

```lua
disk/apps/storage/setup_storage.lua
```

Or force the setup monitor explicitly:

```lua
disk/apps/storage/setup_storage.lua monitor_1
```

Workflow:
- stop the dashboard first if it is running
- choose the input chest
- tap `Set Dash 2`, then touch the second big dashboard monitor if you are using one
- tap a category on the dashboard monitor
- tap `Next Label` until the desired top monitor name is shown
- tap `Set Label`
- activate the modems for the chests in that category bank
- the selected category count updates live as new inventories are detected
- tap `Confirm Category`
- tap `Save` when finished

Important:
- setup can capture newly connected inventory peripherals live while a category is selected
- labels only render for categories with assigned monitor mappings
- label assignment no longer depends on monitor touch support, so normal and advanced monitors can be mixed
- with two dashboard monitors, the left screen shows page 1 and the right screen shows page 2, then navigation advances as page pairs

## Requester

Run:

```lua
disk/apps/storage/requester.lua
```

Workflow:
- type part of an item name or registry id
- pick the matching item
- enter the amount
- the requester pulls matching stacks from storage chests into the configured output chest
- it then calls `inventoryManager.addItemToPlayer(...)` to deliver the item to the player

Commands:
- `/refresh`: rebuild the item index
- `/quit`: stop the requester

## Pocket Requester

Base computer setup:
- connect the storage computer to the wired chest network as before
- place an Advanced Peripherals `inventoryManager`
- place a dedicated output chest touching the `inventoryManager`
- set `requester.output_direction` to the side of that output chest relative to the `inventoryManager`
- attach a wireless modem to the base computer
- run:

```lua
disk/apps/storage/requester_server.lua
```

Pocket computer setup:
- use an advanced pocket computer with a wireless modem upgrade
- copy the pocket client onto the pocket computer
- run:

```lua
requester_pocket.lua
```

Pocket workflow:
- the pocket client finds the base server over `rednet`
- search by item name or registry id
- pick a match and amount
- the base computer stages the item and tries to deliver it to the player
- if direct player delivery fails, the item remains in the output chest
