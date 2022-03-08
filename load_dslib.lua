#!/bin/env luajit

-- Use this if you want to use dslib without minetest.

_G.minetest = {
	request_insecure_environment = function()
		return _G
	end,

	get_modpath = function(modname)
		assert(modname == "dslib") -- otherwise not implemented
		return "."
	end,

	log = function()
	end,
}

dofile("init.lua")

_G.minetest = nil
