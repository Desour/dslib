#!/bin/env luajit

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

-- Use this if you want to use dslib without minetest.
-- (For now, this pollutes the global env. And you have to set PATH_TO_MINETEST_VECTOR.
-- So, this is sadly not too well suited for anything but the unittests.)

assert(not _G.minetest)
_G.minetest = {
	is_fake = true,
	-- DSlib requires ssl and luajit if it has the IE.
	-- (Unittests are run with on and off.)
	dslib_dont_use_ie = os.getenv("DSLIB_DONT_USE_IE") == "1",

	request_insecure_environment = function()
		return (not _G.minetest.dslib_dont_use_ie) and _G or nil
	end,

	get_modpath = function(modname)
		assert(modname == "dslib") -- otherwise not implemented
		return "."
	end,

	log = function()
	end,

	settings = {
		get = function() return nil end,
	},

	formspec_escape = function(str)
		return str
	end
}

_G.table.key_value_swap = function(t)
	local ret = {}
	for k, v in pairs(t) do
		ret[v] = k
	end
	return ret
end

local path_to_minetest_vector = os.getenv("DSLIB_PATH_TO_MINETEST_VECTOR") or "../../builtin/common/vector.lua"
_G.vector = {metatable = {}}
dofile(path_to_minetest_vector)

dofile("init.lua")

-- keep _G.minetest, as some modules require it to load
--~ _G.minetest = nil
