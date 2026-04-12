return {
  disk_mount = "disk",
  github = {
    owner = "Damian-Narcis-Ionel",
    repo = "cc-suite",
    branch = "main",
  },

  bootstrap = {
    updater = {
      file = "updater.lua",
      path = "updater.lua",
      target = "/updater.lua",
    },

    updater_config = {
      file = "updater_config.lua",
      path = "updater_config.lua",
      target = "/updater_config.lua",
    },
  },

  apps = {
    mining = {
      label = "Mining Turtles",
      disk_dir = "apps/mining",

      programs = {
        hole = {
          file = "hole.lua",
          path = "apps/mining/hole.lua",
        },
      },
    },

    storage = {
      label = "Storage System",
      disk_dir = "apps/storage",

      programs = {
        dashboard = {
          file = "dashboard.lua",
          path = "apps/storage/dashboard.lua",
        },

        labels = {
          file = "labels.lua",
          path = "apps/storage/labels.lua",
        },

        setup_storage = {
          file = "setup_storage.lua",
          path = "apps/storage/setup_storage.lua",
        },

        sorter = {
          file = "sorter.lua",
          path = "apps/storage/sorter.lua",
        },
      },

      configs = {
        sorter_config = {
          file = "sorter_config.lua",
          path = "configs/storage/sorter_config.lua",
          target = "/sorter_config.lua",
          preserve_existing = true,
        },
      },
    },
  },
}
