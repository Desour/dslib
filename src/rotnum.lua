
--- Numbers for 90 degree rotations.
--
-- This module provides so-called rotnums: numbers that can represent rotations
-- of multiples of 90°, mirrorings and compositions of those.
--
-- Rotnums can be used to rotate arbitrary spatial vectors. They can be
-- converted to and from facedir and wallmounted values and euler angles.
--
-- **Note:** Rotnums are numbers, not tables, so you can't do method calls and
-- similar on them.
--
-- Bit representation
-- ------------------
--
-- A rotnum is a 11-bit integral number that the following bits (in MSBF (most
-- significant bit first) notation):
--    sz z1 z0 0 sy y1 y0 0 sx x1 x0
--
-- A vector `v_in` is transformed to a vector `v_out` using these bits in the
-- following way:
--
-- * The `0`-bits are padding.
-- * Let `w` be any of `x, y, z`.
-- * `w1 w0` says for `v_out.w` which component of `v_in` it should be:
--   `0b00` for `x`, `0b01` for `y` and `0b10` for `z`.
-- * If `sw == 1`, the `w` component in `v_out` is negated.
-- * Example: For `0 sx x1 x0 == 0b0110`, `v_out.x = -v_in.z`.
--
-- You may assume that the representation of rotnums stays the same (until a major
-- version change, see Versioning.md). Hence, storing rotnums in meta and similar is
-- valid.
--
--
-- Caching
-- -------
--
-- Some functions, such as `rotnum.rjw()`, are documented to return a constant.
--
-- You can cache the return values instead of the functions:
--    local r2x = rotnum.r2x -- what you would normally do
--    local r2x = rotnum.r2x() -- valid
--
--
-- @module dslib:rotnum

local rotnum = {}
rotnum.version = "0.1.0"

local bnot     = bit.bnot
local band     = bit.band
local bxor     = bit.bxor
local blshift  = bit.lshift
local brshift  = bit.rshift
local vector_new = vector.new

local xyz = {"x", "y", "z"}

--- Composition of two rotnums.
--
-- Applying the returned rotnum is the same as first applying `b` and then `a`.
--
-- This operation is:
--
-- * associative: `rotnum.comp(a, rotnum.comp(b, c)) == rotnum.comp(rotnum.comp(a, b), c)`
-- * **not** commutative: `rotnum.comp(a, b) ~= rotnum.comp(b, a)`
--
-- @tparam rotnum a
-- @tparam rotnum b
-- @treturn rotnum The composition (`a` after `b`).
function rotnum.comp(a, b)
	-- use `x1 x0 * 4 = x1 x0 << 2` from `a` as index into `b`
	local x = band(brshift(b, band(blshift(a, 2), 0xc)), 0x7)
	local y = band(brshift(b, band(brshift(a, 2), 0xc)), 0x7)
	local z = band(brshift(b, band(brshift(a, 6), 0xc)), 0x7)
	-- xor the signs
	x = bxor(x, band(        a,     0x4))
	y = bxor(y, band(brshift(a, 4), 0x4))
	z = bxor(z, band(brshift(a, 8), 0x4))
	-- shift to the right places
	return blshift(z, 8) + blshift(y, 4) + x
end

--- Apply a rotnum to a vector.
--
-- This operation is:
--
-- * associative with `rotnum.comp`: `rotnum.apply(a, rotnum.apply(b, v)) == rotnum.apply(rotnum.comp(a, b), v)`
-- * distributive with vector addition: `rotnum.apply(a, v1 + v2) == rotnum.apply(a, v1) + rotnum.apply(a, v2)`
--
-- @tparam rotnum n The rotnum to apply.
-- @tparam vector vec The vector to transform.
-- @treturn vector The transformed vector.
function rotnum.apply(n, vec)
	-- The sign bit calculation does a bit magic:
	-- `band(brshift(n, 1), 0x2)` is 2 if sx==1, else 0.
	-- `bnot(2)` is -3, `bnot(0)` is -1
	-- => If we add 2, we get -1 if sx==1, else 1.
	return vector_new(
		vec[xyz[band(        n    , 0x3) + 1]] * (bnot(band(brshift(n, 1), 0x2)) + 2),
		vec[xyz[band(brshift(n, 4), 0x3) + 1]] * (bnot(band(brshift(n, 5), 0x2)) + 2),
		vec[xyz[band(brshift(n, 8), 0x3) + 1]] * (bnot(band(brshift(n, 9), 0x2)) + 2)
	)
end

do
	local comp = rotnum.comp
	local apply = rotnum.apply

	--- Composition of `j` rotnums.
	--
	-- Read this as a template. The `compj()` function doesn't exist itself.
	-- `j` can be any of `2, 3, 4, 5`.
	--
	-- These functions can be used as shortcut for multiple calls of `rotnum.comp()`,
	-- ie.:
	--    -- both do the same:
	--    rotnum.comp(rotnum.comp(rn1, rn2), rn3)
	--    rotnum.comp3(rn1, rn2, rn3)
	--
	-- @tparam rotnum rn1
	-- @tparam rotnum ... More rotnums. Number depends on `j`.
	-- @treturn rotnum The compositon of all rotnums.
	-- @function rotnum.compj

	rotnum.comp2 = comp

	function rotnum.comp3(rn1, rn2, rn3)
		return comp(comp(rn1, rn2), rn3)
	end

	function rotnum.comp4(rn1, rn2, rn3, rn4)
		return comp(comp(comp(rn1, rn2), rn3), rn4)
	end

	function rotnum.comp5(rn1, rn2, rn3, rn4, rn5)
		return comp(comp(comp(comp(rn1, rn2), rn3), rn4), rn5)
	end

	--- Composition of many rotnums.
	--
	-- Example:
	--    rotnum.compn{rn1, rn2, ...}
	--
	-- @tparam table rns List of rotnums (can be empty).
	-- @treturn rotnum The compositon of all rotnums.
	function rotnum.compn(rns)
		local rn = rotnum.id()
		for i = 1, #rns do
			rn = comp(rn, rns[i])
		end
		return rn
	end

	--- Composition of `j` rotnums and application on a vector.
	--
	-- Read this as a template. The `compjapply()` function doesn't exist itself.
	-- `j` can be any of `2, 3, 4, 5`.
	--
	-- These functions can be used as shortcut for multiple calls of `rotnum.comp()`,
	-- followed by a call to `rotnum.apply()`, ie.:
	--    -- both do the same:
	--    rotnum.apply(rotnum.comp(rn1, rn2), vec)
	--    rotnum.comp2apply(rn1, rn2, vec)
	--
	-- @tparam rotnum rn1
	-- @tparam rotnum ... More rotnums. Number depends on `j`.
	-- @tparam vector vec The vector to transform.
	-- @treturn vector The transformed vector.
	-- @function rotnum.compjapply

	function rotnum.comp2apply(rn1, rn2, vec)
		return apply(comp(rn1, rn2), vec)
	end

	function rotnum.comp3apply(rn1, rn2, rn3, vec)
		return apply(comp(comp(rn1, rn2), rn3), vec)
	end

	function rotnum.comp4apply(rn1, rn2, rn3, rn4, vec)
		return apply(comp(comp(comp(rn1, rn2), rn3), rn4), vec)
	end

	function rotnum.comp5apply(rn1, rn2, rn3, rn4, rn5, vec)
		return apply(comp(comp(comp(comp(rn1, rn2), rn3), rn4), rn5), vec)
	end

	local compn = rotnum.compn

	--- Composition of many rotnums and application on a vector.
	--
	-- Example:
	--    rotnum.compnapply({rn1, rn2, ...}, vector.new(1, 0, 0))
	--
	-- @tparam table rns List of rotnums (can be empty).
	-- @tparam vector vec The vector to transform.
	-- @treturn vector The transformed vector.
	function rotnum.compnapply(rns, vec)
		return apply(compn(rns), vec)
	end
end

--- Identity.
--
-- A vector stays unmodified if you apply the returned rotnum to it.
--
-- @treturn rotnum A constant.
function rotnum.id()
	return 0x210
end

--- Rotates `j*90` degrees around the +w axis.
--
-- Read this as a template. The `rjw()` function doesn't exist itself.
-- `j` can be any of `1, 2, 3`. `w` can be any of `x, y, z`.
-- Example: `rotnum.r1x()`
--
-- This is a left-handed rotation in left-handed coord system (equals right-handed
-- rotation in right-handed system).
-- Hence, it's a **left-handed (clockwise) rotation** in Minetest's left-handed system.
--
-- @treturn rotnum A constant.
-- @function rotnum.rjw

function rotnum.r1x()
	-- z=+y, y=-z, x=x
	return 0x160
end

function rotnum.r2x()
	-- z=-z, y=-y, x=x
	return 0x650
end

function rotnum.r3x()
	-- z=-y, y=z, x=x
	return 0x520
end

function rotnum.r1y()
	-- z=-x, y=y, x=z
	return 0x412
end

function rotnum.r2y()
	-- z=-z, y=y, x=-x
	return 0x614
end

function rotnum.r3y()
	-- z=x, y=y, x=-z
	return 0x016
end

function rotnum.r1z()
	-- z=z, y=x, x=-y
	return 0x205
end

function rotnum.r2z()
	-- z=z, y=-y, x=-x
	return 0x254
end

function rotnum.r3z()
	-- z=z, y=-x, x=y
	return 0x241
end

--- Alias for `rotnum.rjw()`.
--
-- @function rotnum.rcwjw

--- Alias for `rotnum.r(4-j)w()`.
--
-- Example: `rotnum.rccw1x == rotnum.r3x`
--
-- @function rotnum.rccwjw

rotnum.rcw1x = rotnum.r1x
rotnum.rcw2x = rotnum.r2x
rotnum.rcw3x = rotnum.r3x
rotnum.rccw1x = rotnum.r3x
rotnum.rccw2x = rotnum.r2x
rotnum.rccw3x = rotnum.r1x

rotnum.rcw1y = rotnum.r1y
rotnum.rcw2y = rotnum.r2y
rotnum.rcw3y = rotnum.r3y
rotnum.rccw1y = rotnum.r3y
rotnum.rccw2y = rotnum.r2y
rotnum.rccw3y = rotnum.r1y

rotnum.rcw1z = rotnum.r1z
rotnum.rcw2z = rotnum.r2z
rotnum.rcw3z = rotnum.r3z
rotnum.rccw1z = rotnum.r3z
rotnum.rccw2z = rotnum.r2z
rotnum.rccw3z = rotnum.r1z

--- Mirrors along the w axis.
--
-- Read this as a template. The `mirror_w()` function doesn't exist itself.
-- `w` can be any of `x, y, z`.
-- Example: `rotnum.mirror_x()`
--
-- @treturn rotnum A constant.
-- @function rotnum.mirror_w

function rotnum.mirror_x()
	return 0x214
end

function rotnum.mirror_y()
	return 0x250
end

function rotnum.mirror_z()
	return 0x610
end

local lookup_tbl_facedir_to_rotnum = {}
local lookup_tbl_rotnum_to_facedir = {}

-- fill up with `false` to make to array
-- TODO: save memory by removing padding?
for rn = 0, 0x6ff do
	lookup_tbl_rotnum_to_facedir[rn] = false
end

for facedir = 0, 0x19 do -- facedir only goes until 23, but including more does not hurt
	-- see rotateMeshBy6dFacedir() in src/client/mesh.cpp
	local axisdir = brshift(facedir, 2)
	local axisrot = band(facedir, 0x3)
	local rn = rotnum.comp(({
			[0] = rotnum.id(), -- y+
			[1] = rotnum.r1x(), -- z+
			[2] = rotnum.r3x(), -- z-
			[3] = rotnum.r3z(), -- x+
			[4] = rotnum.r1z(), -- x-
			[5] = rotnum.r2z(), -- y-
			[6] = rotnum.id(),
			[7] = rotnum.id(),
		})[axisdir], ({
			[0] = rotnum.id(),
			[1] = rotnum.r1y(),
			[2] = rotnum.r2y(),
			[3] = rotnum.r3y(),
		})[axisrot])
	lookup_tbl_facedir_to_rotnum[facedir] = rn
	-- do not overwrite (invalid facedir values result in duplicates)
	lookup_tbl_rotnum_to_facedir[rn] = lookup_tbl_rotnum_to_facedir[rn] or facedir
end

--- Converts a facedir number to a rotnum.
-- @tparam int facedir The facedir number.
-- @treturn rotnum The rotnum.
function rotnum.from_facedir(facedir)
	return lookup_tbl_facedir_to_rotnum[facedir]
end

--- Tries to convert a rotnum to a facedir number.
--
-- Facedir values can represent any compositions of 90° rotations, but not
-- mirrorings for example. Hence, this can fail.
--
-- @tparam rotnum rn The rotnum.
-- @return Facedir number or `false` on failure.
function rotnum.to_facedir(rn)
	return lookup_tbl_rotnum_to_facedir[rn]
end

-- copied from src/util/directiontables.cpp
local lookup_tbl_wallmounted_to_facedir = {
	[0] = 20,
	0,
	16 + 1,
	12 + 3,
	8,
	4 + 2
}

local lookup_tbl_facedir_to_wallmounted = {}
-- fill with `false`
for facedir = 0, 0x19 do
	lookup_tbl_facedir_to_wallmounted[facedir] = false
end
for wallmounted = 0, 5 do
	local facedir = lookup_tbl_wallmounted_to_facedir[wallmounted]
	lookup_tbl_facedir_to_wallmounted[facedir] = lookup_tbl_facedir_to_wallmounted[facedir]
			or wallmounted
end

-- make a shortcut for rotnum.from_wallmounted()
local lookup_tbl_wallmounted_to_rotnum = {}
for wallmounted = 0, 6 do
	lookup_tbl_wallmounted_to_rotnum[wallmounted] =
			rotnum.from_facedir(lookup_tbl_wallmounted_to_facedir[wallmounted])
end

--- Converts a wallmounted number to a rotnum.
-- @tparam int wallmounted The wallmounted number.
-- @treturn rotnum The rotnum.
function rotnum.from_wallmounted(wallmounted)
	return lookup_tbl_wallmounted_to_rotnum[wallmounted]
end

--- Tries to convert a rotnum to a wallmounted number.
-- @tparam rotnum rn The rotnum.
-- @return Wallmounted number or `false` on failure.
function rotnum.to_wallmounted(rn)
	local facedir = rotnum.to_facedir(rn)
	return facedir and lookup_tbl_facedir_to_wallmounted[facedir]
end

-- TODO: euler angles

return rotnum
