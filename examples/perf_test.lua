#!/bin/env luajit

dofile("load_dslib.lua")

_G.dslib_ie.internal.load_experimental_trusted_modules = true

local raw_buffer = dslib.mrequire("dslib:raw_buffer")
local new_luajit_stuff = dslib.mrequire("dslib:new_luajit_stuff")
local ffi = require("ffi")

local counter_max = 100000000
local typ = "int32_t"
local typ_size = ffi.sizeof(typ)

local rbuf1 = raw_buffer.new_RawBuffer()
rbuf1:reserve(counter_max * typ_size)
local rbuf2 = raw_buffer.new_RawBuffer()
rbuf2:resize(counter_max * typ_size)
--~ local t = {}
local t = new_luajit_stuff.table_new(counter_max, 0)
local ffi_buf = ffi.new(typ.."["..counter_max.."]")

--~ local append_i32 = rbuf1.append_i32
--~ local function append_i32_rbuf1(i)
	--~ append_i32(rbuf1, i)
--~ end

--~ local function table_set(t, k, v)
	--~ t[k] = v
--~ end

--~ local jv = require("jit.v")
--~ local jv = require("jit.dump")
--~ jv.on()
local t0 = os.clock()

for i = 0, counter_max-1 do
	rbuf1:append_i32(i)

	--~ rbuf1:resize(i*typ_size+typ_size)
	--~ rbuf1:write_i32(i*typ_size, i)

	--~ rbuf2:write_i32(i*typ_size, i)

	--~ t[i] = i
	--~ table_set(t, i, i)
	--~ table.insert(t, i)

	--~ ffi_buf[i] = i
end

local dt = os.clock() - t0
--~ jv.off()

-- eat them with some C func
debug.getregistry(t, rbuf1, rbuf2, ffi_buf)

print(("it took: %f s"):format(dt))
