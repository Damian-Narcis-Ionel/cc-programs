# CC:Tweaked Programs Suite

A repository of **CC:Tweaked** programs with a shared installer/updater and per-app configs.

The repo is no longer structured as a storage-only project. Storage is now one app under `apps/storage`, and new unrelated programs can be added as their own apps without inheriting storage-specific assumptions.

## Layout

```text
apps/
  mining/
    README.md
    hole.lua
  storage/
    README.md
    dashboard.lua
    labels.lua
    setup_storage.lua
    sorter.lua

configs/
  storage/
    sorter_config.lua

updater.lua
updater_config.lua
```

## Install Model

Programs are installed onto the floppy disk, usually under `disk/apps/<app>/`.

Bootstrap files and configs are installed onto the computer itself, for example:
- `/updater.lua`
- `/updater_config.lua`
- `/sorter_config.lua`

This keeps machine-local state on the computer while allowing portable program disks.

Apps can define their own monitor layouts. The storage app now supports multiple dashboard monitors through `monitors.dashboards`.

## Updating In Game

Bootstrap the updater on the CC computer:

```lua
wget https://raw.githubusercontent.com/Damian-Narcis-Ionel/cc-programs/main/updater.lua /updater.lua
wget https://raw.githubusercontent.com/Damian-Narcis-Ionel/cc-programs/main/updater_config.lua /updater_config.lua
```

Then install everything:

```lua
/updater.lua all
```

Or install a single app:

```lua
/updater.lua storage
```

You can also install a single app target:

```lua
/updater.lua storage:setup_storage
/updater.lua storage:sorter_config
```

## Adding New Apps

To add a non-storage program:
1. Create a new folder under `apps/<app-name>/`.
2. Put that app's program files there.
3. Add config templates under `configs/<app-name>/` if needed.
4. Register the app in `updater_config.lua`.

Each app gets:
- its own disk install directory
- its own optional configs on the computer
- its own docs

## Current Apps

- `mining`: turtle excavation utilities
- `storage`: categorized chest storage, dashboard, labels, and setup flow

Storage-specific details live in [apps/storage/README.md](apps/storage/README.md).
Mining-specific details live in [apps/mining/README.md](apps/mining/README.md).

## Repo Rename

The structure now matches a general program suite more than a storage-only repo, so renaming the repo is reasonable.

Good candidates:
- `cc-programs`
- `cc-tools`
- `cc-toolkit`

If you rename the remote repo, update the `github.repo` field in [updater_config.lua](updater_config.lua).
