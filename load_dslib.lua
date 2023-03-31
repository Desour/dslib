#!/bin/env luajit

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
