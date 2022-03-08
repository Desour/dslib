#!/bin/env luajit

dofile("load_dslib.lua")

local raw_buffer = dslib.mrequire("dslib:raw_buffer")

--~ assert(buffer.get_endian() == "little")

local rbuf = raw_buffer.new_RawBuffer()

rbuf:resize(3)
print(rbuf:read_i8(0))

--~ rbuf:append_i64(-math.huge+0ULL)
rbuf:append_i64(1ULL)
print(rbuf:read_i64(3))

rbuf:append_f32(-1.25)
print(string.format("%#x", rbuf:read_u32(11)))

--~ local t0 = os.clock()
--~ rbuf:reserve(0x1p60+0ULL-1)
--~ print(("it took: %f s"):format(os.clock() - t0))

--~ dslib.keep_my_global = rbuf
