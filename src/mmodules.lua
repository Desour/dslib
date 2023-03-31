-- Copyright (C) 2023 DS
--
-- SPDX-License-Identifier: Apache-2.0
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

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

local function try_mrequire(name)
	-- check module status
	local status = module_stati[name]

	if status == "loaded" then
		local retval = module_retvals[name]
		if not retval then
			return retval, "Loading failed in earlier attempt."
		end
		return retval
	elseif status == "loading" then
		return nil, "require-loop detected"
	end
	assert(status == nil)

	-- get the loader
	local loader = lookup_module_loader(name)
	if not loader then
		return nil, "no loader for module"
	end

	-- load it
	module_stati[name] = "loading"
	local retval, errmsg = loader(name)
	if retval == nil then
		module_stati[name] = nil
		return retval, errmsg
	end

	module_retvals[name] = retval
	module_stati[name] = "loaded"

	return retval, errmsg
end


-- ------------------------------------------------------------------------------
-- the mmodules module
-- ===================
-- more module stuff needs to be mrequired first

local mmodules = {}
mmodules.version = "0.2.0"

--- An alias for `dslib.mrequire`.
-- @param name See `dslib.mrequire`.
function mmodules.mrequire(name)
	local retval, errmsg = try_mrequire(name)
	if not retval then
		error(string.format("Failed to mrequire module '%s': %s", name, errmsg))
	end
	return retval
end

--- Tries to load a module.
--
-- Use this instead of `pcall`ing `mrequire`.
--
-- @param name See `mrequire`.
-- @return The module's retval, or `nil` or `false` on failure.
-- @return `nil` on success, otherwise the error message (a string).
-- @function mmodules.try_mrequire
mmodules.try_mrequire = try_mrequire

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
-- a loader function.
--
-- Semantics of a loader function `l`:
--
-- * `retval, errmsg = l(module_name)` will be used by `try_mrequire` and `mrequire`
--   to load the module.
-- * If `retval` is `nil`, the loading fails, but `l` will be called again on
--   another `try_mrequire` or `mrequire` call.
-- * If `retval` is `false`, the loading fails, and no more attempts for loading
--   the respective module will be made.
-- * If `retval` is any other value, the loading succeeds and `retval` is the module's
--   retval.
-- * Iff the loading fails, `errmsg` should be a string indicating the error.
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
-- See `add_module_loader_uplooker` for details on loader functions.
--
-- @tparam string name The name of the module.
-- @tparam function loader Will be called to load the module.
function mmodules.add_module_by_loader(name, loader)
	named_module_loaders[name] = loader
end

--- Adds a value as a module.
--
-- When loading, `value` will be returned.
--
-- @tparam string name The name of the module.
-- @param value The return value of the module. Must not be `nil` or `false`.
function mmodules.add_module_by_value(name, value)
	mmodules.add_module_by_loader(name, function()
		return value
	end)
end

--- Adds a module via its source code.
--
-- When loading, the code will be loaded and used as loader function.
-- See `add_module_loader_uplooker` for details on loader functions.
--
-- @tparam string name The name of the module.
-- @tparam string code_str The code.
function mmodules.add_module_by_string(name, code_str)
	mmodules.add_module_by_loader(name, function()
		return assert(loadstring(code_str, string.format("mmodule `%s`", name)))()
	end)
end

--- Adds a module via its file.
--
-- When loading, the code in the file will be loaded and used as loader function.
-- See `add_module_loader_uplooker` for details on loader functions.
--
-- @tparam string name The name of the module.
-- @tparam string path The path of the file.
function mmodules.add_module_by_file(name, path)
	mmodules.add_module_by_loader(name, function()
		return dofile(path)
	end)
end


return mmodules
