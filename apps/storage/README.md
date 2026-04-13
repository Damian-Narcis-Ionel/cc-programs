# Storage App

The storage app provides:
- automatic item sorting into storage categories
- a dashboard monitor with slot-based fullness stats
- paged dual-dashboard support across two large monitors
- per-category label monitors
- an interactive setup flow for chest and label monitor assignment

## Programs

- `sorter.lua`: main sorting loop
- `dashboard.lua`: dashboard display
- `labels.lua`: category label display
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
- add or remove one temporary item in one or more chests from that category
- tap `Find Marked`
- tap `Assign Label`, then touch the small monitor for that category
- tap `Confirm Category`
- tap `Save` when finished

Important:
- opening a chest is not enough for detection
- the script identifies a chest by inventory content changes
- labels only render for categories with assigned monitor mappings
- with two dashboard monitors, the left screen shows page 1 and the right screen shows page 2, then navigation advances as page pairs
