
--- A module for registering new modules.
--
-- As a convention, module names begin with `"<modname>:"`.
--
-- Furthermore, it is suggested to use `"<modname>:internal.<...>"` for mod-internal
-- stuff, and `"<modname>:api"` if the mod just wants to expose its api as a whole.
--
-- @module dslib:mmodules

-- nil
-- --register--> nil
-- --mrequire started--> "loading"
-- --mrequire finished--> "loaded"
local module_stati = {}

-- cached retvals of modules
-- (only one retval per module)
local module_retvals = {}

local module_loader_uplookers = {}

local function lookup_module_loader(name)
	for _, l in ipairs(module_loader_uplookers) do
		local r = l(name)
		if r then
			return r
		end
	end
	return nil
end

local function mrequire(name)
	-- check module status
	local status = module_stati[name]

	if status == "loaded" then
		return module_retvals[name]
	elseif status == "loading" then
		error("require-loop detected", 2)
	end
	assert(status == nil)

	-- get the loader
	local loader = lookup_module_loader(name)
	if not loader then
		error(string.format("module `%s` does not exist", name), 2)
	end

	-- load it
	module_stati[name] = "loading"
	local retval = loader(name)

	module_retvals[name] = retval
	module_stati[name] = "loaded"

	return retval
end


-- ------------------------------------------------------------------------------
-- the mmodules module
-- ===================
-- more module stuff needs to be mrequired first

local mmodules = {}
mmodules.version = "0.1.0"

--- An alias for `dslib.mrequire`.
-- @param name See `dslib.mrequire`.
-- @function mmodules.mrequire
mmodules.mrequire = mrequire

-- query functions

--- Checks if a module is loaded.
-- @tparam string name The name of the module.
-- @treturn bool Whether module `name` was loaded.
function mmodules.is_loaded(name)
	return module_stati[name] == "loaded"
end

--- Checks if a module is currently loading.
--
-- `dslib.mrequire(name)` was called, but didn't return yet.
-- @tparam string name The name of the module.
-- @treturn bool Whether module `name` is currently loading.
function mmodules.is_loading(name)
	return module_stati[name] == "loading"
end

--- Checks if a module was registered.
-- @tparam string name The name of the module.
-- @treturn bool Whether module `name` is registered.
function mmodules.exists(name)
	return module_stati[name] ~= nil or lookup_module_loader(name) ~= nil
end

-- stuff for adding new modules

--- Adds a function to look for module loaders.
--
-- `func(module_name)` must either return nothing (=> no loader found) or return
-- a loader function `l`, such that `ret = l(module_name)` can be used to load
-- the module.
--
-- You will very likely not need this. Try `mmodules.add_module_by_loader` first.
--
-- @tparam function func The uplooker function.
function mmodules.add_module_loader_uplooker(func)
	table.insert(module_loader_uplookers, func)
end

local named_module_loaders = {}
mmodules.add_module_loader_uplooker(function(name)
	local l = named_module_loaders[name]
	named_module_loaders[name] = nil -- free resources
	return l
end)

--- Adds a module with a loader function for it.
--
-- `loader(name)` will be called to load the module.
--
-- @tparam string name The name of the module.
-- @tparam function loader Will be called to load the module.
function mmodules.add_module_by_loader(name, loader)
	named_module_loaders[name] = loader
end

--- Adds a value as a module.
--
-- When loading, `value` will be returned.
-- @tparam string name The name of the module.
-- @param value The return value of the module.
function mmodules.add_module_by_value(name, value)
	mmodules.add_module_by_loader(name, function()
		return value
	end)
end

--- Adds a module via its source code.
--
-- When loading, the code will be loaded and executed.
-- @tparam string name The name of the module.
-- @tparam string code_str The code.
function mmodules.add_module_by_string(name, code_str)
	mmodules.add_module_by_loader(name, function()
		return assert(loadstring(code_str, string.format("mmodule `%s`", name)))()
	end)
end

--- Adds a module via its file.
--
-- When loading, the code in the file will be loaded and executed.
-- @tparam string name The name of the module.
-- @tparam string path The path of the file.
function mmodules.add_module_by_file(name, path)
	mmodules.add_module_by_loader(name, function()
		return dofile(path)
	end)
end


return mmodules
