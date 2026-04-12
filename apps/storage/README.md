# Storage App

The storage app provides:
- automatic item sorting into storage categories
- a dashboard monitor with slot-based fullness stats
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

Workflow:
- stop the dashboard first if it is running
- choose the input chest
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
