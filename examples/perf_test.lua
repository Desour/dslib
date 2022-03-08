#!/bin/env luajit

dofile("load_dslib.lua")

_G.dslib_ie.internal.load_experimental_trusted_modules = true

local raw_buffer = dslib.mrequire("dslib:raw_buffer")

local rbuf = raw_buffer.new_RawBuffer()
local t = {}

local jv = require("jit.v")
--~ local jv = require("jit.dump")
jv.on()
local t0 = os.clock()

rbuf:reserve(4000000)
for i = 1, 1000000 do
	rbuf:append_i32(i)
	--~ t[i] = i
end

local dt = os.clock() - t0
jv.off()

print(#t)
print(("it took: %f s"):format(dt))
