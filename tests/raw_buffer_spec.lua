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

_G.dslib_ie.internal.load_experimental_trusted_modules = true

local raw_buffer = dslib.mrequire("dslib:raw_buffer")

describe("raw_buffer", function()
	it("new_RawBuffer()", function()
		assert(raw_buffer.new_RawBuffer())
	end)

	describe("RawBuffer", function()
		it("resize()", function()
			local rbuf = raw_buffer.new_RawBuffer()

			rbuf:resize(3)
			assert.equals(3, rbuf:size())
			assert.equals(0x10, rbuf:capacity())
			assert.equals(0, rbuf:read_i8(0))

			assert.has_error(function() rbuf:resize(0x1p60+1ULL) end)
		end)

		it("reserve()", function()
			local rbuf = raw_buffer.new_RawBuffer()

			rbuf:reserve(3)
			assert.equals(0, rbuf:size())
			assert.equals(0x10, rbuf:capacity())
			assert.has_error(function() rbuf:read_u8(0) end)

			assert.has_error(function() raw_buffer.new_RawBuffer():reserve(0x1p60+1ULL) end)
		end)

		it("read_...() checks offset", function()
			local function mkbuf_empty()
				return raw_buffer.new_RawBuffer()
			end

			assert.has_error(function() mkbuf_empty():read_i8(0) end)
			assert.has_error(function() mkbuf_empty():read_u64(3) end)

			local function mkbuf()
				local rbuf = mkbuf_empty()
				rbuf:append_u32(12312435)
				return rbuf
			end

			assert.has_error(function() mkbuf():read_u64(-1) end)
			assert.has_error(function() mkbuf():read_u64(0) end)
			assert.has_error(function() mkbuf():read_u64(1) end)

			assert.has_error(function() mkbuf():read_u32(-1) end)
			assert.has_no_error(function() mkbuf():read_u32(0) end)
			assert.has_error(function() mkbuf():read_u32(1) end)

			assert.has_error(function() mkbuf():read_u16(-1) end)
			assert.has_no_error(function() mkbuf():read_u16(0) end)
			assert.has_no_error(function() mkbuf():read_u16(1) end)
			assert.has_no_error(function() mkbuf():read_u16(2) end)
			assert.has_error(function() mkbuf():read_u16(3) end)
			assert.has_error(function() mkbuf():read_u16(4) end)
			assert.has_error(function() mkbuf():read_u16(5) end)
			assert.has_error(function() mkbuf():read_u16(6) end)
			assert.has_error(function() mkbuf():read_u16(7) end)
			assert.has_error(function() mkbuf():read_u16(8) end)

			assert.has_error(function() mkbuf():read_u16(0x1p64-1ULL) end)
			assert.has_error(function() mkbuf():read_u16(0x1p64-2ULL) end)
			assert.has_error(function() mkbuf():read_u16(0x1p64-3ULL) end)
			assert.has_error(function() mkbuf():read_u16(0x1p64-4ULL) end)
			assert.has_error(function() mkbuf():read_u16(0x1p64-5ULL) end)
			assert.has_error(function() mkbuf():read_u16(0x1p64-6ULL) end)

			assert.has_no_error(function() mkbuf():read_string(0, 0) end)
			assert.has_no_error(function() mkbuf():read_string(0, 3) end)
			assert.has_no_error(function() mkbuf():read_string(0, 4) end)
			assert.has_error(function() mkbuf():read_string(0, 5) end)
			assert.has_error(function() mkbuf():read_string(0, -1) end)
			assert.has_error(function() mkbuf():read_string(0, 0x1p64-1ULL) end)
			assert.has_no_error(function() mkbuf():read_string(4, 0) end)
			assert.has_error(function() mkbuf():read_string(5, 0) end)
			assert.has_no_error(function() mkbuf():read_string(3, 0) end)
			assert.has_no_error(function() mkbuf():read_string(3, 1) end)
			assert.has_error(function() mkbuf():read_string(3, 2) end)
		end)

		it("floats use IEEE 754", function()
			local rbuf = raw_buffer.new_RawBuffer()

			rbuf:append_f32(213.074)
			assert.equals(0x435512f2, rbuf:read_u32(0))
			rbuf:append_f64(213.074)
			assert.equals(0x406aa25e353f7ceeULL, rbuf:read_u64(4))
			rbuf:append_f64(-1.25)
			assert.equals(0xbff4000000000000ULL, rbuf:read_u64(12))
		end)

		it("TODO", function()
			local rbuf = raw_buffer.new_RawBuffer()

			rbuf:append_i64(-math.huge+0ULL)
			rbuf:append_i64(1ULL)

			assert.equals(1649267441664LL, rbuf:read_i64(3))

			rbuf:append_f32(-1.25)
			assert.equals(0, rbuf:read_u32(11))

			--~ rbuf:reserve(0x1p60+0ULL-1)
		end)
	end)
end)
