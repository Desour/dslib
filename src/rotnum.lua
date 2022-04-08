
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
-- For every rotation or other transformation, there is one unique rotnum. So,
-- one can compare rotnums using `==` and use rotnums as table keys.
--
--
-- How they work
-- -------------
--
-- Rotnums are actually a compact representation for a special kind of 3x3 matrices,
-- which have in each row only one element that is non-zero, and this element is
-- either `1` or `-1`, for example:
--    ( 0 -1  0 )
--    ( 0  1  0 ) is equivalent to 0x415
--    (-1  0  0 )
--
-- `comp` and `apply` are just matrix multiplication.
--
-- See also [Bit representation] for details.
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

local band     = bit.band
local bxor     = bit.bxor
local blshift  = bit.lshift
local brshift  = bit.rshift
local math_floor = math.floor
local two_pi_th  = 2.0/math.pi
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
	-- `1 - 2` is -1, `1 - 0` is 1
	-- => We get -1 if sx==1, else 1.
	return vector_new(
		vec[xyz[band(        n    , 0x3) + 1]] * (1 - band(brshift(n, 1), 0x2)),
		vec[xyz[band(brshift(n, 4), 0x3) + 1]] * (1 - band(brshift(n, 5), 0x2)),
		vec[xyz[band(brshift(n, 8), 0x3) + 1]] * (1 - band(brshift(n, 9), 0x2))
	)
end

--- The inverse.
--
-- Applying the result undoes the given rotnum's transformation.
--
-- **Warning:** Not all rotnums have an inverse (see `can_inv` for details).
-- If the given rotnum has no inverse, the output is some integral number with
-- undefined properties.
--
-- Example:
--    assert(rotnum.id() == rotnum.comp(rn, rotnum.inv(rn)))
--    assert(rotnum.inv(rotnum.comp(rn1, rn2)) == rotnum.comp(rotnum.inv(rn2), rotnum.inv(rn1)))
--
-- This operation just transposes the rotnum (because invertible rotnums are
-- orthonormal).
--
-- This function can also be used to find out where each of the `+x`, `+y` and
-- `+z` would be transformed to by the given rotnum:
--
-- * In the input rotnum, `sw w1 w0` says from what the `w`-component will be created.
-- * In the output rotnum, `sw w1 w0` says to what the `w`-component will be transformed.
--
-- @tparam rotnum rn
-- @treturn rotnum
function rotnum.inv(rn)
	-- We just have to transpose:
	-- Take x, y and z as 0x0, 0x1 and 0x2, add their sign change, and then blshift
	-- it to its place (given by bits at 0x333 (0xc because shift *4)).
	return blshift(band(        rn    , 0x4)      , band(blshift(rn, 2), 0xc))
	     + blshift(band(brshift(rn, 4), 0x4) + 0x1, band(brshift(rn, 2), 0xc))
	     + blshift(band(brshift(rn, 8), 0x4) + 0x2, band(brshift(rn, 6), 0xc))
end

--- Checks whether a rotnum is invertible.
--
-- The following statements are equivalent:
--
-- * `rn` is invertible.
-- * `rn` is a rotation, a mirroring or a composition of those.
-- * The matrix represented by `rn` has `1` or `-1` in each column.
-- * The matrix represented by `rn` is orthonormal.
-- * The inverse of `rn` is its transposed.
-- * The transposed of the matrix represented by `rn` can be represented by a rotnum.
-- * The matrix represented by `rn` has full rank.
-- * The determinant of the matrix represented by `rn` is either `1` or `-1`.
--
-- @tparam rotnum rn The rotnum to check.
-- @treturn bool `true` if `rn` is invertible, `false` otherwise.
function rotnum.can_inv(rn)
	-- lshift 0x1 into the lowest 3 bits, depending on `w1 w0` values
	-- iff they don't overlap, the popcnt will be 3: 0b111 (=0x7)
	return (blshift(0x1, band(        rn,     0x3))
	      + blshift(0x1, band(brshift(rn, 4), 0x3))
	      + blshift(0x1, band(brshift(rn, 8), 0x3))) == 0x7
end

--- Checks whether something is a valid rotnum.
--
-- @param obj Some value.
-- @treturn bool `true` if `obj` is a rotnum, `false` otherwise.
function rotnum.is_rotnum(obj)
	return type(obj) == "number"
		and obj == math_floor(obj)
		and obj >= 0
		and obj <= 0x666
		and band(obj, 0x088) == 0x000 -- padding is 0
		and band(obj, 0x300) ~= 0x300 -- `w1 w0` is not 3
		and band(obj, 0x030) ~= 0x300
		and band(obj, 0x003) ~= 0x003
end

do
	local comp = rotnum.comp
	local apply = rotnum.apply

	--- Composition of `j` rotnums.
	--
	-- Read this as a template. The `compj()` function doesn't exist itself.
	-- `j` can be any of `2, 3, 4, 5`.
	--
	-- These functions can be used as shortcut for multiple calls of `comp`,
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
	-- These functions can be used as shortcut for multiple calls of `comp`,
	-- followed by a call to `apply`, ie.:
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
-- Hence, it's a **left-handed rotation** in Minetest's left-handed system.
-- (Left-handed rotation is clockwise if you look from the `+w` side.)
--
-- @treturn rotnum A constant.
-- @function rotnum.rjw

function rotnum.r1x()
	-- z=y, y=-z, x=x
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
-- The `l` stands for left-handed rotation in a left-handed coordinate system.
--
-- Example: `rotnum.rl1x == rotnum.r1x`
--
-- @function rotnum.rljw

--- Alias for `rotnum.r(4-j)w()`.
--
-- The second `r` stands for right-handed rotation in a left-handed coordinate system.
--
-- Example: `rotnum.rr1x == rotnum.r3x`
--
-- @function rotnum.rrjw

rotnum.rl1x = rotnum.r1x
rotnum.rl2x = rotnum.r2x
rotnum.rl3x = rotnum.r3x
rotnum.rr1x = rotnum.r3x
rotnum.rr2x = rotnum.r2x
rotnum.rr3x = rotnum.r1x

rotnum.rl1y = rotnum.r1y
rotnum.rl2y = rotnum.r2y
rotnum.rl3y = rotnum.r3y
rotnum.rr1y = rotnum.r3y
rotnum.rr2y = rotnum.r2y
rotnum.rr3y = rotnum.r1y

rotnum.rl1z = rotnum.r1z
rotnum.rl2z = rotnum.r2z
rotnum.rl3z = rotnum.r3z
rotnum.rr1z = rotnum.r3z
rotnum.rr2z = rotnum.r2z
rotnum.rr3z = rotnum.r1z

--- Rotates a multiple of `90` degrees around the +w axis.
--
-- Read this as a template. The `rnw()` function doesn't exist itself.
-- `w` can be any of `x, y, z`.
-- Example: `rotnum.rnx()`
--
-- `n` will be taken modulo `4` and rounded to the nearest integer.
--
-- @tparam number n How often to rotate.
-- @treturn rotnum One of `rotnum.rjw()`'s return values, depending on `n`.
-- @function rotnum.rnw

local rx_by_n = {rotnum.id(), rotnum.r1x(), rotnum.r2x(), rotnum.r3x(), rotnum.id()}
local ry_by_n = {rotnum.id(), rotnum.r1y(), rotnum.r2y(), rotnum.r3y(), rotnum.id()}
local rz_by_n = {rotnum.id(), rotnum.r1z(), rotnum.r2z(), rotnum.r3z(), rotnum.id()}

function rotnum.rnx(n)
	return rx_by_n[math_floor(n % 4 + 1.5)]
end

function rotnum.rny(n)
	return ry_by_n[math_floor(n % 4 + 1.5)]
end

function rotnum.rnz(n)
	return rz_by_n[math_floor(n % 4 + 1.5)]
end

--- Alias for `rotnum.rnw(n)`.
--
-- Example: `rotnum.rlnx == rotnum.rnx`
--
-- @tparam number n
-- @treturn rotnum
-- @function rotnum.rlnw

rotnum.rlnx = rotnum.rnx
rotnum.rlny = rotnum.rny
rotnum.rlnz = rotnum.rnz

--- Alias for `rotnum.rnw(-n)`.
--
-- Example: `rotnum.rrnx`
--
-- @tparam number n
-- @treturn rotnum
-- @function rotnum.rrnw

function rotnum.rrnx(n)
	return rx_by_n[math_floor((-n) % 4 + 1.5)]
end

function rotnum.rrny(n)
	return ry_by_n[math_floor((-n) % 4 + 1.5)]
end

function rotnum.rrnz(n)
	return rz_by_n[math_floor((-n) % 4 + 1.5)]
end

local rw_by_n_by_dir = {x = rx_by_n, y = ry_by_n, z = rz_by_n}

--- Rotate a multiple of `90` degrees around the given axis.
--
-- The semantics for `n` are the same as in `rotnum.rnw`.
--
-- @tparam number n How often to rotate.
-- @tparam string dir `"x"`, `"y"` or `"z"`.
-- @treturn rotnum An output of `rotnums.rjw`, depending on `n` and `dir`.
function rotnum.rn_around(n, dir)
	return rw_by_n_by_dir[dir][math_floor(n % 4 + 1.5)]
end

--- Alias for `rotnum.rn_around(n, dir)`.
-- @tparam number n
-- @tparam string dir
-- @treturn rotnum
-- @function rotnum.rln_around
rotnum.rln_around = rotnum.rn_around

--- Alias for `rotnum.rn_around(-n, dir)`.
-- @tparam number n
-- @tparam string dir
-- @treturn rotnum
function rotnum.rrn_around(n, dir)
	return rw_by_n_by_dir[dir][math_floor((-n) % 4 + 1.5)]
end

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

local mirror_rotnums_per_dir = {x = rotnum.mirror_x(), y = rotnum.mirror_y(), z = rotnum.mirror_z()}

--- Mirror along given axis.
-- @tparam string dir `"x"`, `"y"` or `"z"`.
-- @treturn rotnum One of `rotnum.mirror_w()`'s return values, depending on `dir`.
function rotnum.mirror_along(dir)
	return mirror_rotnums_per_dir[dir]
end

local lut_facedir_to_rotnum = {}
local lut_rotnum_to_facedir = {}

do
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
		lut_facedir_to_rotnum[facedir] = rn
		-- do not overwrite (invalid facedir values result in duplicates)
		lut_rotnum_to_facedir[rn] = lut_rotnum_to_facedir[rn] or facedir
	end
end

--- Converts a facedir number to a rotnum.
-- @tparam int facedir The facedir number.
-- @treturn rotnum The rotnum.
function rotnum.from_facedir(facedir)
	return lut_facedir_to_rotnum[facedir]
end

--- Tries to convert a rotnum to a facedir number.
--
-- Facedir values can represent any compositions of 90° rotations, but not
-- mirrorings for example. Hence, this can fail.
--
-- @tparam rotnum rn The rotnum.
-- @return Facedir number or `false` on failure.
function rotnum.to_facedir(rn)
	return lut_rotnum_to_facedir[rn] or false
end

-- copied from src/util/directiontables.cpp
local lut_wallmounted_to_facedir = {
	[0] = 20,
	0,
	16 + 1,
	12 + 3,
	8,
	4 + 2
}

local lut_facedir_to_wallmounted = {}
do
	-- fill with `false`
	for facedir = 0, 0x19 do
		lut_facedir_to_wallmounted[facedir] = false
	end
	for wallmounted = 0, 5 do
		local facedir = lut_wallmounted_to_facedir[wallmounted]
		lut_facedir_to_wallmounted[facedir] = lut_facedir_to_wallmounted[facedir]
				or wallmounted
	end
end

--- Converts a wallmounted number to a facedir number.
-- @tparam int wallmounted The wallmounted value.
-- @treturn int The facedir value.
function rotnum.wallmounted_to_facedir(wallmounted)
	return lut_wallmounted_to_facedir[wallmounted]
end

--- Tries to convert a facedir number to a wallmounted number.
-- @tparam int facedir The facedir value.
-- @return The wallmounted value or `false` on failure.
function rotnum.facedir_to_wallmounted(facedir)
	return lut_facedir_to_wallmounted[facedir] or false
end

-- make a shortcut for rotnum.from_wallmounted()
local lut_wallmounted_to_rotnum = {}
for wallmounted = 0, 6 do
	lut_wallmounted_to_rotnum[wallmounted] =
			rotnum.from_facedir(lut_wallmounted_to_facedir[wallmounted])
end

--- Converts a wallmounted number to a rotnum.
-- @tparam int wallmounted The wallmounted number.
-- @treturn rotnum The rotnum.
function rotnum.from_wallmounted(wallmounted)
	return lut_wallmounted_to_rotnum[wallmounted]
end

--- Tries to convert a rotnum to a wallmounted number.
-- @tparam rotnum rn The rotnum.
-- @return Wallmounted number or `false` on failure.
function rotnum.to_wallmounted(rn)
	local facedir = lut_rotnum_to_facedir[rn]
	return facedir and lut_facedir_to_wallmounted[facedir] or false
end

--- Apply a facedir number to a vector.
--
-- Shortcut for:
--    rotnum.apply(rotnum.from_facedir(facedir), vec)
--
-- @tparam int facedir The facedir number.
-- @tparam vector vec The vector to transform.
-- @treturn vector The transformed vector.
function rotnum.apply_facedir(facedir, vec)
	return rotnum.apply(rotnum.from_facedir(facedir), vec)
end

--- Apply a wallmounted number to a vector.
--
-- Shortcut for:
--    rotnum.apply(rotnum.from_wallmounted(wallmounted), vec)
--
-- @tparam int wallmounted The wallmounted number.
-- @tparam vector vec The vector to transform.
-- @treturn vector The transformed vector.
function rotnum.apply_wallmounted(wallmounted, vec)
	return rotnum.apply(rotnum.from_wallmounted(wallmounted), vec)
end

--- (Rounds and) converts an euler angle vector to a rotnum.
-- @tparam vector euler_vec The euler vectors.
-- @treturn rotnum
function rotnum.from_euler(euler_vec)
	return rotnum.comp3(
			rotnum.rny(-euler_vec.y * two_pi_th),
			rotnum.rnx(-euler_vec.x * two_pi_th),
			rotnum.rnz(-euler_vec.z * two_pi_th)
		)
end

local lut_rotnum_to_euler = {}

do
	local function rotnum_to_euler_slow(rn)
		-- use inverse to find out in what directions backward(+z), up(+y) and left(+x)
		-- would be after rotation
		-- (the "backward", etc., are assuming that if one places a node with facedir,
		-- then its front face will look to the player)
		local rni = rotnum.inv(rn)

		local pitch, roll = 0, 0
		local bits_for_yaw = rni

		if band(rni, 0x300) == 0x100 then -- looking up or down
			local is_up = band(rni, 0x400) == 0x400
			--~ minetest.chat_send_all("looking "..(is_up and "up" or "down"))
			pitch = (is_up and -1 or 1) * (math.pi * 0.5)
			-- if looking down, use down as backward in yaw calculations,
			-- if looking up, use up
			bits_for_yaw = blshift(bxor(rni, is_up and 0x000 or 0x040), 4)

		elseif band(rni, 0x003) == 0x001 then -- roll is sideways
			local left_is_up = band(rni, 0x004) == 0x000
			--~ minetest.chat_send_all("roll is sideways: "..(left_is_up and
					--~ "left is up" or "right is up"))
			roll = (left_is_up and -1 or 1) * (math.pi * 0.5)

		elseif band(rni, 0x070) == 0x050 then -- roll makes upside down
			--~ minetest.chat_send_all("roll makes upside down")
			roll = math.pi
		end

		--~ minetest.chat_send_all(("bits_for_yaw: %#x"):format(bits_for_yaw))
		-- backward tells us the yaw
		local yaw = ({
				[0x200] = 0,
				[0x400] = math.pi * 0.5,
				[0x600] = math.pi,
				[0x000] = math.pi * 1.5,
			})[band(bits_for_yaw, 0x700)]

		return vector_new(pitch, yaw, roll)
	end

	-- fill lut_rotnum_to_euler by iterating over all valid facedirs (=> all rotations)
	for facedir = 0, 23 do
		local rn = rotnum.from_facedir(facedir)
		lut_rotnum_to_euler[rn] = rotnum_to_euler_slow(rn)
	end
end

--- Tries to convert a rotnum to euler angles.
--
-- Note: Euler angles can just rotate, hence this call can fail.
--
-- @tparam rotnum rn The rotnum to convert.
-- @return The vector of euler angles or `false` on failure.
function rotnum.to_euler(rn)
	local v = lut_rotnum_to_euler[rn]
	return v and vector.copy(v) or false
end

return rotnum
