# CC:Tweaked Storage System

A modular storage setup for a modded Minecraft server using **CC:Tweaked**.

This project is built around a central sorter computer, multiple categorized storage chests, and monitor-based dashboards/labels. It is designed to be easy to update, easy to expand, and practical for real in-game usage.

## Features

- Automatic item sorting into storage categories
- Config-driven chest and monitor layout
- Dashboard monitor showing storage usage by category
- Slot-based fullness tracking for more realistic storage pressure
- Label monitors for category naming
- Updater script for pulling the latest files from GitHub
- Interactive setup script for remapping chests with monitor buttons
- Easy to expand with new categories and storage lines

## Current Scripts

### `labels.lua`
Draws category labels on the small monitors.

### `dashboard.lua`
Displays storage statistics on the main dashboard monitor.

The dashboard currently shows:
- category name
- chests connected in that category
- used slots / total slots
- free slots
- stored items / max theoretical item capacity
- a progress bar based on **slot usage**, not item count

This makes it much more accurate for mixed and unstackable items.

### `sorter.lua`
Main sorting logic. Reads incoming items and routes them into the correct category chests.

### `sorter_config.lua`
Main configuration file.

This defines:
- input inventory
- category chest assignments
- monitor assignments
- category order
- labels used by the dashboard

### `updater.lua`
Downloads updated script files from configured GitHub raw URLs.

### `updater_config.lua`
Tells the updater which files to download and where to save them.

### `setup_storage.lua`
Interactive storage mapping tool.

It uses the dashboard monitor for a clickable setup flow, can auto-load the current config, and lets you assign chests category-by-category using monitor buttons.

## Install Layout

Programs are intended to live on the floppy disk mount, usually `disk/`.

Config files are intended to live on the computer itself:
- `/sorter_config.lua`
- `/updater_config.lua`

This means:
- the updater installs programs to the disk
- the setup script writes the live sorter config to `/sorter_config.lua`
- the runtime programs load config from `/sorter_config.lua`

## Why slot-based fullness?

A category can look "low" on item count while actually being close to full if many slots are occupied by low-stack or unstackable items.

Example:
- armor
- tools
- enchanted books
- random modded loot

Because of that, the dashboard uses:

- **main fullness:** used slots / total slots
- **secondary metric:** used items / max theoretical item capacity

This gives a much more realistic picture of whether a category is close to jamming.

## Updating In Game

Bootstrap the updater on the CC computer:

```lua
wget https://raw.githubusercontent.com/Damian-Narcis-Ionel/cc-storage/main/updater.lua updater.lua
wget https://raw.githubusercontent.com/Damian-Narcis-Ionel/cc-storage/main/updater_config.lua updater_config.lua
```

Then update everything:

```lua
updater all
```

This installs:
- `labels.lua`
- `setup_storage.lua`
- `sorter.lua`
- `dashboard.lua`
- `updater.lua`
- `updater_config.lua`

Notes:
- `updater_config.lua` is stored on the computer at `/updater_config.lua`
- `sorter_config.lua` is stored on the computer at `/sorter_config.lua`
- `update all` will not overwrite an existing `/sorter_config.lua`

## Interactive Setup

Run:

```lua
setup_storage
```

The setup script takes over the dashboard monitor for configuration.

Workflow:
- stop the dashboard first if it is running
- choose the input chest
- tap a category on the monitor
- add or remove one temporary item in a chest from that category
- tap `Find Marked`
- tap `Assign Label`, then touch the small monitor for that category
- repeat until that category has all of its chests
- tap `Confirm Category`
- tap `Save` when finished

Important:
- opening a chest is not enough for detection
- the script identifies a chest by inventory content changes

## Repository Structure

```text
labels.lua
setup_storage.lua
dashboard.lua
sorter.lua
sorter_config.lua
updater.lua
updater_config.lua
