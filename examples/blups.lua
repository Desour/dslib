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
