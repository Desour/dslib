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

--- Helper functions for endianness.
-- @module dslib:endian_helpers

local raw_buffer = dslib.mrequire("dslib.raw_buffer")

local endian_helpers = {}
endian_helpers.version = "0.1.0"

-- find out the endian-ness via duck-typing
-- TODO: just use ffi.abi
local endian
do
	local buf = raw_buffer.new()
	buf:append_u64(0x8877665544332211ULL)

	local bytes_little = {[0] = 0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88}
	local bytes_big    = {[0] = 0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11}
	local is_little_endian = true
	local is_big_endian    = true
	for i = 0, 7 do
		local byte = buf:read_u8(i)
		if byte ~= bytes_little[i] then
			is_little_endian = false
		end
		if byte ~= bytes_big[i] then
			is_big_endian = false
		end
	end

	if is_little_endian then
		endian = "little"
	elseif is_big_endian then
		endian = "big" -- not tested
	else
		error("Your system has a weird endian-ness.")
		-- from now on, assume that no other enian-nesses exist
	end
end

--- Returns the native endian-ness of the system.
-- @return `"little"` for little-endian, `"big"` for big-endian. Anything else is not supported.
function endian_helpers.get_endian()
	return endian
end

local function identity_func(a)
	return a
end

--- Converts a number from one endian-ness to another.
--
-- `X` and `Y` can be any of `n`, `l` and `b`, for native-, little- and big endian-ness respectively.
--
-- The numbers can also be LuaJIT 64 bit cdata numbers.
--
-- If a number is used, it may be interpreted as signed 32-bit integer. (`bit.bswap`
-- is used.)
--
-- TODO: Auto-create doc for all, instead of the templates in the name.
--
-- @tparam int num The number to convert in endian-ness `X`.
-- @treturn int The number in endian-ness `Y`.
-- @function endian_helpers.Xe_to_Ye

endian_helpers.ne_to_le = endian == "big" and bit.bswap or identity_func
endian_helpers.ne_to_be = endian == "big" and identity_func or bit.bswap
endian_helpers.le_to_ne = endian == "big" and bit.bswap or identity_func
endian_helpers.be_to_ne = endian == "big" and identity_func or bit.bswap
endian_helpers.le_to_be = bit.bswap
endian_helpers.be_to_le = bit.bswap
endian_helpers.ne_to_ne = identity_func
endian_helpers.le_to_le = identity_func
endian_helpers.be_to_be = identity_func

--- Alias for `ne_to_le()`.
-- @tparam int num
-- @treturn int
-- @function endian_helpers.to_le
endian_helpers.to_le = endian_helpers.ne_to_le
--- Alias for `ne_to_be()`.
-- @tparam int num
-- @treturn int
-- @function endian_helpers.to_be
endian_helpers.to_be = endian_helpers.ne_to_be
--- Alias for `le_to_ne()`.
-- @tparam int num
-- @treturn int
-- @function endian_helpers.from_le
endian_helpers.from_le = endian_helpers.le_to_ne
--- Alias for `be_to_ne()`.
-- @tparam int num
-- @treturn int
-- @function endian_helpers.from_be
endian_helpers.from_be = endian_helpers.be_to_ne

--- Alias for `ne_to_ne()` and similar (identity).
-- @tparam int num
-- @treturn int
-- @function endian_helpers.identity
endian_helpers.identity = identity_func
--- Alias for `le_to_be()` and `be_to_le()` (`bit.bswap`).
-- @tparam int num
-- @treturn int
-- @function endian_helpers.bswap
endian_helpers.bswap = bit.bswap

return endian_helpers
