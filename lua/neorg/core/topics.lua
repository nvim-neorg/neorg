---@meta


---@alias neorg.event.module_loaded string
---Informs that a new module has been loaded and added to Neorg's environment.
---Since only the module's name is published, a module that would like to gather
---more information about the newly loaded module should retrieve it by calling
---`neorg.modules.get()`.
---TODO: Make this a reality!


---@alias neorg.event.neorg_started nil
---Informs that Neorg has finished loaded. Its payload is empty.
