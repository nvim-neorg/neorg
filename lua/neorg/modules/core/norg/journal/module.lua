--[[
JOURNAL
This module will allow you to write a basic journal in neorg.
--]]

require("neorg.modules.base")

local module = neorg.modules.create("core.norg.journal")

module.setup = function()
  return {
    success = true,
    requires = {
      "core.norg.dirman",
      "core.keybinds",
      "core.neorgcmd",
    },
  }
end

module.private = {
  open_diary = function(date)
    local workspace = module.required["core.norg.dirman"].get_current_workspace()
    local folder_name = module.config.public.journal_folder
    local year = date:sub(1,4)
    local month = date:sub(6,7)
    local day = date:sub(9,10)
    if module.config.public.use_folders then
      vim.cmd([[e]]..workspace[2].."/"..folder_name.."/"..year.."/"..month.."/"..day..".norg")
    else
      vim.cmd([[e]]..workspace[2].."/"..folder_name.."/"..date..".norg")
    end
  end,

  diary_next = function()
    local date = os.date("%Y-%m-%d", os.time() + 24 * 60 * 60)
    module.private.open_diary(date)
  end,

  diary_previous = function()
    local date = os.date("%Y-%m-%d", os.time() - 24 * 60 * 60)
    module.private.open_diary(date)
  end,

  diary_today = function()
    local date = os.date("%Y-%m-%d", os.time())
    module.private.open_diary(date)
  end,
}



module.config.public = {
  workspace = "default",
  journal_folder = "/journal/",
  use_folders = true -- if true -> /2021/07/23
}

module.public = {
  version = "0.1",
}

module.load = function()
  module.required["core.neorgcmd"].add_commands_from_table({
    definitions = {
      journal = {
        next = {},
        previous = {},
        today = {},
        custom = {},
      },
    },
    data = {
      journal = {
        min_args = 1,
        max_args = 2,
        subcommands = {
          next = { args = 0, name = "journal.next" },
          previous = { args = 0, name = "journal.previous" },
          today = { args = 0, name = "journal.today" },
          custom = { args = 1, name = "journal.custom" }, -- format :yyyy-mm-dd
        },
      },
    },
  })
end

module.on_event = function(event)
  if vim.tbl_contains({ "core.keybinds", "core.neorgcmd" }, event.split_type[1]) then
    if event.split_type[2] == "journal.next" then
      diary_next()
    elseif event.split_type[2] == "journal.previous" then
      diary_previous()
    elseif event.split_type[2] == "journal.custom" then
      open_diary(event.content)
    elseif event.split_type[2] == "journal.today" then
    diary_today()
    end
  end
end

module.events.subscribed = {
  ["core.neorgcmd"] = {
    ["journal.previous"] = true,
    ["journal.next"] = true,
    ["journal.today"] = true,
    ["journal.custom"] = true,
  },
}



return module
