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

local rotnum = dslib.mrequire("dslib:rotnum")

describe("rotnum", function()
	it("id()", function()
		assert.equals(rotnum.id(), rotnum.comp(rotnum.id(), rotnum.id()))
		local v = vector.new(1, 2, 3)
		assert.equals(v, rotnum.apply(rotnum.id(), v))
	end)

	it("comp()", function()
		assert.equals(0x000, rotnum.comp(0x000, 0x000))
		assert.equals(0x002, rotnum.comp(0x001, 0x020))
		assert.equals(0x440, rotnum.comp(0x004, 0x004))
		assert.equals(0x666, rotnum.comp(0x000, 0x006))
		assert.equals(0x006, rotnum.comp(0x001, 0x060))
		assert.equals(0x060, rotnum.comp(0x010, 0x060))
		assert.equals(0x020, rotnum.comp(0x050, 0x060))
	end)

	it("inv()", function()
		assert.equals(rotnum.r1x(), rotnum.inv(rotnum.r3x()))
		assert.equals(rotnum.r2x(), rotnum.inv(rotnum.r2x()))
		assert.equals(rotnum.r1y(), rotnum.inv(rotnum.r3y()))
		assert.equals(rotnum.r2y(), rotnum.inv(rotnum.r2y()))
		assert.equals(rotnum.r1z(), rotnum.inv(rotnum.r3z()))
		assert.equals(rotnum.r2z(), rotnum.inv(rotnum.r2z()))

		local rn1, rn2 = rotnum.r1x(), rotnum.r1y()
		assert.equals(rotnum.inv(rotnum.comp(rn1, rn2)),
				rotnum.comp(rotnum.inv(rn2), rotnum.inv(rn1)))

		assert.equals(rotnum.id(), rotnum.comp(rn1, rotnum.inv(rn1)))
	end)

	it("can_inv()", function()
		assert.True(rotnum.can_inv(rotnum.r1x()))
		assert.True(rotnum.can_inv(rotnum.r2x()))
		assert.True(rotnum.can_inv(rotnum.r3x()))
		assert.True(rotnum.can_inv(rotnum.r1y()))
		assert.True(rotnum.can_inv(rotnum.comp(rotnum.r1y(), rotnum.r3x())))
		assert.True(rotnum.can_inv(rotnum.comp(rotnum.r1y(), rotnum.mirror_z())))
	end)

	it("rjw()", function()
		assert.equals(rotnum.r1x(), rotnum.comp(rotnum.id(),  rotnum.r1x()))
		assert.equals(rotnum.r1x(), rotnum.comp(rotnum.r1x(), rotnum.id()))
		assert.equals(rotnum.r2x(), rotnum.comp(rotnum.r1x(), rotnum.r1x()))
		assert.equals(rotnum.r3x(), rotnum.comp(rotnum.r1x(), rotnum.r2x()))
		assert.equals(rotnum.r3x(), rotnum.comp(rotnum.r2x(), rotnum.r1x()))
		assert.equals(rotnum.id(),  rotnum.comp(rotnum.r1x(), rotnum.r3x()))
		assert.equals(rotnum.id(),  rotnum.comp(rotnum.r3x(), rotnum.r1x()))

		assert.equals(rotnum.r1y(), rotnum.comp(rotnum.id(),  rotnum.r1y()))
		assert.equals(rotnum.r2y(), rotnum.comp(rotnum.r1y(), rotnum.r1y()))
		assert.equals(rotnum.r3y(), rotnum.comp(rotnum.r1y(), rotnum.r2y()))
		assert.equals(rotnum.id(),  rotnum.comp(rotnum.r1y(), rotnum.r3y()))

		assert.equals(rotnum.r1z(), rotnum.comp(rotnum.id(),  rotnum.r1z()))
		assert.equals(rotnum.r2z(), rotnum.comp(rotnum.r1z(), rotnum.r1z()))
		assert.equals(rotnum.r3z(), rotnum.comp(rotnum.r1z(), rotnum.r2z()))
		assert.equals(rotnum.id(),  rotnum.comp(rotnum.r1z(), rotnum.r3z()))
	end)

	it("mirror_w()", function()
		assert.equals(rotnum.id(), rotnum.comp(rotnum.mirror_x(), rotnum.mirror_x()))
		assert.equals(rotnum.id(), rotnum.comp(rotnum.mirror_y(), rotnum.mirror_y()))
		assert.equals(rotnum.id(), rotnum.comp(rotnum.mirror_z(), rotnum.mirror_z()))
	end)
end)
