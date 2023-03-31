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

assert(not _G.minetest)
_G.minetest = {
	is_fake = true,

	request_insecure_environment = function()
		return _G
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

_G.vector = {metatable = {}}
dofile("../../builtin/common/vector.lua") -- TODO: don't do this here

dofile("init.lua")

-- keep _G.minetest, as some modules require it to load
--~ _G.minetest = nil
