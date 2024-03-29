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

--- The init.
-- This module is already loaded as global `dslib`.
-- Other modules can be loaded via `dslib.mrequire`.
-- @module dslib

local IE = minetest.request_insecure_environment()
local has_IE = IE ~= nil

dslib = {}
local dslib_version = "0.3.0"
dslib.version = dslib_version
dslib.internal = {}

if has_IE then
	IE.dslib_ie = {} -- _G == IE is possible, therefore not IE.dslib
	IE.dslib_ie.version = dslib_version
	IE.dslib_ie.internal = {}
end

-- The submodules that can be `.mrequire()`d.
-- If the insecure env is needed, the sha256sum of the file must match. (This is
-- needed because minetest provides no way to securely get the correct modpath.)
local submodules = {
	["dslib:raw_buffer"] = {
		path = "src/raw_buffer.lua",
		needs_IE = true,
		sha256sum = "5baf39067bb42b7ddacbb413db5ec11a785f4e990005f6a9a6336ca014127811",
		experimental = true,
	},
	["dslib:endian_helpers"] = {
		path = "src/endian_helpers.lua",
		needs_IE = false,
		experimental = true,
	},
	["dslib:new_luajit_stuff"] = {
		path = "src/new_luajit_stuff.lua",
		needs_IE = true,
		sha256sum = "33a70464f995aa4280e942d4bd1bdf368145c9580ef973eacd46ffe43de32ac2",
		experimental = true,
	},
	["dslib:start_end"] = {
		path = "src/start_end.lua",
		needs_IE = false,
		experimental = true,
	},
	["dslib:rotnum"] = {
		path = "src/rotnum.lua",
		needs_IE = false,
		experimental = true,
	},
	["dslib:fmt"] = {
		path = "src/fmt.lua",
		needs_IE = false,
		experimental = true,
	},
}

-- Only set to true while you are developing.
local skip_sha256_sums = false

-- Same here. But unittests and co. may set this.
if has_IE then -- luacheck: ignore
	--~ IE.dslib_ie.internal.load_experimental_trusted_modules = true
end

dslib.internal.load_experimental_untrusted_modules = true

if skip_sha256_sums then
	minetest.log("warning", "dslib: skip_sha256_sums is set to true.")
end
if has_IE and IE.dslib_ie.internal.load_experimental_trusted_modules then
	minetest.log("warning", "dslib: load_experimental_trusted_modules is set to true.")
end

local error  = has_IE and IE.error  or _G.error -- does not return. _G.error can return
local assert = has_IE and IE.assert or _G.assert
local pairs  = has_IE and IE.pairs  or _G.pairs
local type   = has_IE and IE.type   or _G.type
local string_format = has_IE and IE.string.format or _G.string.format

-- the mmodules module
local dslib_modpath = minetest.get_modpath("dslib")
assert(type(dslib_modpath) == "string")
local mmodules = _G.dofile(dslib_modpath .. "/src/mmodules.lua")
mmodules.add_module_by_value("dslib:mmodules", mmodules)

--- Loads a module. Can be used like `require`.
--
-- A module can return one value.
-- Module return values are cached.
--
-- For registering modules use the `dslib:mmodules` module:
-- `local mmodules = dslib.mrequire("dslib:mmodules")`
--
-- @tparam string name The name of the module.
-- @return The return value of the module.
-- @function dslib.mrequire
dslib.mrequire = mmodules.mrequire

while has_IE do -- luacheck: ignore (no loop)
	-- the same as `IE.require(...)`, but sets the env to IE
	function IE.dslib_ie.internal.require_with_IE_env(...)
		-- be sure that there is no hook, otherwise one could get IE via getfenv
		IE.debug.sethook()

		local old_thread_env = IE.getfenv(0)
		local old_string_metatable = IE.debug.getmetatable("")

		-- set env of thread
		-- (the loader used by IE.require will probably use the thread env for
		-- the loaded functions)
		IE.setfenv(0, IE)

		-- also set the string metatable because the lib might use it while loading
		-- (actually, we probably have to do this every time we call a `require()`d
		-- function, but for performance reasons we only do it if the function
		-- uses the string metatable)
		-- (Maybe it would make sense to set the string metatable __index field
		-- to a function that grabs the string table from the thread env.)
		IE.debug.setmetatable("", {__index = IE.string})

		-- (IE.require's env is neither _G, nor IE. we need to leave it like this,
		-- otherwise it won't find the loaders (it uses the global `loaders`, not
		-- `package.loaders` btw. (see luajit/src/lib_package.c)))

		-- we might be pcall()ed, so we need to pcall to make sure that we reset
		-- the thread env afterwards
		local ok, ret = IE.pcall(IE.require, ...)

		-- reset env of thread
		IE.setfenv(0, old_thread_env)

		-- also reset the string metatable
		IE.debug.setmetatable("", old_string_metatable)

		if not ok then
			error(ret)
		end
		return ret
	end

	-- Note: we know that "ffi" is not implemented in lua, so we do not need to
	-- set the environment or similar, probably.
	local ffi = IE.dslib_ie.internal.require_with_IE_env("ffi") -- TODO: also use cffi
	if not ffi then
		break
	end
	IE.dslib_ie.internal.ffi = ffi

	-- load openssl
	-- but not into global namespace to not conflict with mintest, because it
	-- has some stuff of it in src/util/sha256.c and co.
	-- (in a minetest mod, we could also use ffi.C (if symbols aren't stripped))
	local ssl = ffi.load("ssl", false)

	ffi.cdef([[
	unsigned char *SHA256(const unsigned char *d, size_t n, unsigned char *md);
	]])

	local SHA256_DIGEST_LENGTH = 32

	-- returns the sha256sum of str as hex
	function IE.dslib_ie.internal.sha256sum(str)
		IE.assert(IE.type(str) == "string")
		-- (s_sum is a static variable in C)
		local s_sum = ssl.SHA256(str, #str, nil)
		local sum_t = {}
		for i = 0, SHA256_DIGEST_LENGTH - 1 do
			sum_t[i+1] = IE.bit.tohex(s_sum[i], 2)
		end
		return IE.table.concat(sum_t)
	end

	break
end

local function my_module_loader(module_name)
	local module_info = submodules[module_name]
	if not module_info then
		error("can not happen")
	end

	if module_info.experimental then
		if not module_info.needs_IE then
			if not dslib.internal.load_experimental_untrusted_modules then
				return false, "Tried to load (untrusted) experimental module."
			end
		else
			if not IE.dslib_ie.internal.load_experimental_trusted_modules then
				return false, "Tried to load (trusted) experimental module."
			end
		end
	end

	local path = dslib_modpath .. "/" .. module_info.path

	if not module_info.needs_IE then
		-- raising an error if loadfile fails is ok, because it is very fatal
		return assert(_G.loadfile(path))({})
	end

	-- remove any debug hook
	IE.debug.sethook()

	if not has_IE then
		return false, "Module needs the insecure environment, but dslib hasn't."
	end

	local file = IE.io.open(path, "r")
	local code = file:read("*a")
	file:close()
	assert(type(code) == "string") -- I'm not sure if file.read can be overwritten.

	if not skip_sha256_sums then
		if not module_info.sha256sum then
			error(string_format("sha256-sum missing for trusted module.",
				module_name))
		end
		local hash = IE.dslib_ie.internal.sha256sum(code)
		if hash ~= module_info.sha256sum then
			error(string_format("Wrong sha256-sum (%s instead of %s).",
				hash, module_info.sha256sum))
		end
	end

	-- loadstring seems to cut off the chunkname at the end if it's too long,
	-- which hides the exact file. to avoid this, we cut ourself at the front
	local chunkname_path = path
	if #chunkname_path > 20 then
		chunkname_path = "..."..IE.string.sub(chunkname_path, -20)
	end
	local chunkname = string_format("[%s] %s", module_name, chunkname_path)

	return assert(IE.loadstring(code, chunkname))({IE = IE})
end

for module_name, _ in pairs(submodules) do
	mmodules.add_module_by_loader(module_name, my_module_loader)
end

--~ -- TODO: remove
--~ unpack({}, 0, 2^31-1)

--~ minetest.after(1, function()
	--~ local mt = debug.getmetatable(minetest.get_player_by_name("singleplayer"))
	--~ print(dump(mt))
	--~ assert(mt.__gc)
--~ end)

--~ print(dump(minetest.deserialize([[return ("fa.ads"):split(".")]])))
