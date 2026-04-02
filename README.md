# CC:Tweaked Storage System

A modular storage setup for a modded Minecraft server using **CC:Tweaked**.

This project is built around a central sorter computer, multiple categorized storage chests, and monitor-based dashboards/labels. It is designed to be easy to update, easy to expand, and practical for real in-game usage.

## Features

- Automatic item sorting into storage categories
- Config-driven chest and monitor layout
- Dashboard monitor showing storage usage by category
- Slot-based fullness tracking for more realistic storage pressure
- Label monitors for category naming
- Updater script for pulling the latest files from a remote source
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
Downloads updated script files from the configured remote source.

### `updater_config.lua`
Tells the updater which files to download and where to save them.

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

## Repository Structure

```text
labels.lua
dashboard.lua
sorter.lua
sorter_config.lua
updater.lua
updater_config.lua
