
--- Secure wrapper for raw cdata buffers.
--
-- Note: This is very experimental.
--
-- See `RawBuffer`.
--
-- @module dslib:raw_buffer

-- TODO: fill, memcpy, memmove, write_and_append_buf
-- TODO: string buffers (read and copy from)
-- TODO: fixed-size buffer with faster, non-atomar functions

local load_vars = ...
local IE = load_vars.IE
_G.assert(IE ~= nil, "This module needs the insecure environment.")

local ffi = IE.dslib_ie.internal.require_with_IE_env("ffi") -- TODO: use IE.dslib_ie.internal.ffi, for luajit or cffi
IE.assert(ffi ~= nil, "This module needs the ffi (ie. from LuaJIT).")

IE.assert(ffi.istype("size_t", 1ULL), "Non 64-bit systems are currently not supported.")

ffi.cdef([[
	void *malloc(size_t size);
	void free(void *ptr);
	void *calloc(size_t nmemb, size_t size);
	void *realloc(void *ptr, size_t size);

	void *memmove(void *dest, const void *src, size_t n);
]])

local ctype_uint8_t_ptr = ffi.typeof("uint8_t *")
local ctype_uint64_t    = ffi.typeof("uint64_t")
local ctype_int64_t     = ffi.typeof("int64_t")

local int_ranges_mins = {uint8_t = 0, uint16_t = 0, uint32_t = 0, uint64_t = 0ULL,
		int8_t = -0x1p7, int16_t = -0x1p15, int32_t = -0x1p31, int64_t = -0x1p63+0LL}
local int_ranges_maxs = {uint8_t = 0x1p8-1, uint16_t = 0x1p16-1, uint32_t = 0x1p32-1, uint64_t = 0x1p64-1ULL,
		int8_t = 0x1p7-1, int16_t = 0x1p15-1, int32_t = 0x1p31-1, int64_t = 0x1p63-1LL}

local C = ffi.C
local ffi_cast   = ffi.cast
local ffi_gc     = ffi.gc
local ffi_fill   = ffi.fill
local ffi_copy   = ffi.copy
local ffi_sizeof = ffi.sizeof
local ffi_istype = ffi.istype
local ffi_string = ffi.string
local ffi_NULL   = nil

local assert = IE.assert
local error  = IE.error
local type   = IE.type

local math_floor = IE.math.floor
local math_huge  = IE.math.huge

local string_format = IE.string.format

local bor = IE.bit.bor

-- the module table
local raw_buffer = {}
raw_buffer.version = "0.1.0"

local RawBuffer_methods = {}
local RawBuffer_metatable = {__index = RawBuffer_methods}

-- holds secret objects per buffer
-- Note: hiding something in the buffer's metatable wouldn't work because mods
-- have `debug.g/setmetatable`. If you have suggestions on how to do it better
-- (or differently) than with a key-weak static table, please tell me.
local s_RawBuffer_secrets = IE.setmetatable({}, {__mode = "k"})

-- checks that arg:
-- * is a number or 64 bit cdata
-- * is not NaN
-- * is integral
-- * is in the range [min_incl, max_incl] (TODO: remove this)
--
-- Note: do not remove the type check. if arg is set to some arbitrary user-controlled
-- value, most operators (ie. `<`) are compromised
local function check_int(arg, min_incl, max_incl, new_type)
	local is_number = type(arg) == "number"
	if not (is_number or ffi_istype(arg, ctype_uint64_t)
			or ffi_istype(arg, ctype_int64_t)) then
		error(string_format("arg is not number, but %s", type(arg)))
	end
	if is_number then
		if arg ~= arg then
			error("arg is NaN")
		end
		if arg ~= math_floor(arg) or arg == math_huge or arg == -math_huge then
			error(string_format("arg is not integral (%f)", arg))
		end
	end
	-- cast now to avoid wrong implicit cast at comparison (ie. min_incl to u64 at
	-- write_i64 with arg=1ULL)
	local ret_arg = ffi_cast(new_type, arg)
	if ret_arg < min_incl or ret_arg > max_incl then
		-- (use tostring because string.format with %d doesn't add the LL and ULL,
		-- but seems to cast to int64_t first, which can be confusing when trying
		-- to write a uint64_t >=0x1p63 as i64)
		error(string_format("arg is outside of range (%s is not in [%s, %s])",
				IE.tostring(arg), IE.tostring(min_incl), IE.tostring(max_incl)))
	end
	return ret_arg
end

--- Creates a new `RawBuffer`.
-- @treturn RawBuffer The new buffer.
-- @function new_RawBuffer
raw_buffer.new_RawBuffer = function()
	local buf = IE.setmetatable({}, RawBuffer_metatable)
	s_RawBuffer_secrets[buf] = {
		m_buffer = ffi_gc(ffi_cast(ctype_uint8_t_ptr, ffi_NULL), C.free),
		m_capacity = 0ULL,
		m_size = 0ULL,
		m_next_lock_owner = nil, -- see set_lock(), unset_lock() for details
		m_locked = false,
	}
	return buf
end

--- A byte-addressable secure wrapper for a cdata buffer.
--
-- Maximum size is currently about `0x1p60` bytes.
--
-- Integer types can be numbers or 64 bit LuaJIT cdata integers (ie. 1ULL).
--
-- Note: The API is very unstable.
--
-- @type RawBuffer

--[[

Security notes on debug hooks and pcall:
========================================

Untrusted mods have access to debug.sethook, coroutines and pcall. This means:

* Buffers can still be used after calls to error and assert (removing them from
  s_RawBuffer_secrets would not help because of hooks).
* Any function can stopped and later continued at every function call, function
  return or new line. The only exception to this is if the debug hook is removed
  before (via `IE.debug.sethook()`), but that's a NYI. (One could try to check in
  the registry whether there's a hook set from lua (see luajit src), but that's
  even more ugly, and I'm not sure if it works with coroutines.)

We must therefore ensure that: (you can actually skip this list because of the locking)

* The capacity *never* decreases. Otherwise an attacker could stop execution of a
  writing function after capacity checks, then decrease the capacity, and then
  write outside of the buffer.
* `m_capacity` is *always* smaller or equal to the actual buffer capacity. We
  therefore write the capacity *after* the realloc.
* `m_size` is updated *after* the write (or other initialization) happened.
* Read operations must only be able to read initialized data. Checks of old `m_size`
  values are ok here because the size of initialized data also never shrinks.
* Allocated memory blocks must always stay valid as long as can be accessed by any
  function. Hence, `C.realloc()` can not be used.

As we do use `C.realloc()`, we instead have to make sure, that only one function
invocation is in a critical section (a code section that accesses the C buffer)
at all time, we call these functions then atomar.
The `set_lock()` and `unset_lock()` functions below are used to ensure this.
Note: The lock is not unset if an error happens. This causes lock poisoning, which
means that buffers can't be used anymore after an error happened, this is a good
thing.

]]

-- sets the lock on s. if not possible, raises an error and possibly poisons the
-- lock. (this is just for detection of atomarity violations, not for synchronization)
-- TODO: try if a ffi call is faster
local function set_lock(s)
	local me = {}

	s.m_next_lock_owner = me

	assert(not s.m_locked, "set_lock() failed: already locked")

	-- Anyone who wants to lock, must have conquered the assert above, and hence
	-- also set themselves as owner *before* the next line happens.

	s.m_locked = true

	-- Nobody can set themselves to m_next_lock_owner and enter this section now
	-- anymore.
	-- And anyone in this section can no longer modify m_next_lock_owner.
	-- Hence, only one can pass the next assert.

	assert(s.m_next_lock_owner == me, "set_lock() failed: someone else locked")

	-- Now nobody is the next owner.
	s.m_next_lock_owner = nil
end

local function unset_lock(s)
	s.m_locked = false
end

local function wrap_secret_and_atomar(func)
	return function(self, ...)
		local s = assert(s_RawBuffer_secrets[self])
		set_lock(s)
		local ret = func(s, ...)
		unset_lock(s)
		return ret
	end
end

--- Returns the size of a buffer.
-- You can not read or write outside of this size.
-- @treturn int The size.
-- @function size
function RawBuffer_methods:size()
	local s = assert(s_RawBuffer_secrets[self])
	return s.m_size
end

--- Returns the capacity of a buffer.
-- @treturn int The capacity.
-- @function capacity
function RawBuffer_methods:capacity()
	local s = assert(s_RawBuffer_secrets[self])
	return s.m_capacity
end

--- Increases the capacity of the buffer.
-- Size is not influenced.
-- Capacity is never decreased.
-- @tparam int new_capacity The requested minimal new capacity.
-- @function reserve
local function RawBuffer_methods_reserve(s, new_capacity)
	if s.m_capacity >= new_capacity then
		return
	end

	-- be more restrictive than 0x1p64 to avoid negative numbers in int64_t, even
	-- after we multiply by 4
	new_capacity = check_int(new_capacity, 0ULL, 0x1p60-1ULL, ctype_uint64_t)

	-- increase capacity by factor 2 (TODO: choose better factor?)
	local actual_new_capacity = s.m_capacity * 2ULL
	-- increase more if it was not enough
	if new_capacity > actual_new_capacity then
		-- round to multiple of 0x10 (TODO: remove premature opti)
		-- (new_capacity - 1 >= 0 holds because of 0 <= s.m_capacity < new_capacity)
		actual_new_capacity = bor(new_capacity - 1, 0xfULL) + 1
	end

	local new_buf = C.realloc(ffi_gc(s.m_buffer, nil), actual_new_capacity)
	if new_buf == ffi_NULL then
		-- realloc() failed. the original buffer is untouched
		ffi_gc(s.m_buffer, C.free)
		error("realloc() failed")
	end

	s.m_buffer = ffi_gc(ffi_cast(ctype_uint8_t_ptr, new_buf), C.free)

	s.m_capacity = actual_new_capacity
end

RawBuffer_methods.reserve = wrap_secret_and_atomar(RawBuffer_methods_reserve)

--- In- or decreases the size of the buffer.
-- If size is increased, new data is filled with `0`s.
-- @tparam int new_size The new size.
-- @function resize
RawBuffer_methods.resize = wrap_secret_and_atomar(function(s, new_size)
	new_size = check_int(new_size, 0ULL, 0x1p60-1ULL, ctype_uint64_t)

	if s.m_size >= new_size then
		s.m_size = new_size
		return
	end

	-- Note: doing self:reserve(...) or RawBuffer_methods.reserve(...) would be
	-- insecure
	RawBuffer_methods_reserve(s, new_size)

	ffi_fill(s.m_buffer + s.m_size, new_size - s.m_size)
	s.m_size = new_size
end)

local function check_offset(s, offset, value_size)
	assert(s.m_size >= value_size, "calculation would overflow. Are you trying to read from / write to empty buffer?")
	return check_int(offset, 0ULL, s.m_size - value_size, ctype_uint64_t)
end

-- read methods
do
	local function make_read_func(type_str)
		local type_size = ffi_sizeof(type_str)
		local ctype_ptr = ffi.typeof(type_str.." *")

		return wrap_secret_and_atomar(function(s, offset)
			offset = check_offset(s, offset, type_size)

			return ffi_cast(ctype_ptr, s.m_buffer + offset)[0]
		end)
	end

	for _, i in IE.ipairs({1, 2, 4, 8}) do
		local type_str = string_format("int%d_t", i * 8)
		RawBuffer_methods["read_u"..(8*i)] = make_read_func("u"..type_str)
		RawBuffer_methods["read_i"..(8*i)] = make_read_func(type_str)
	end

	--- Reads an unsigned 8-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `u8` value at the given offset.
	-- @function read_u8

	--- Reads an unsigned 16-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `u16` value at the given offset.
	-- @function read_u16

	--- Reads an unsigned 32-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `u32` value at the given offset.
	-- @function read_u32

	--- Reads an unsigned 64-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `u64` value at the given offset. It is a `uint64_t` cdata value.
	-- @function read_u64

	--- Reads a signed 8-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `i8` value at the given offset.
	-- @function read_i8

	--- Reads a signed 16-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `i16` value at the given offset.
	-- @function read_i16

	--- Reads a signed 32-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn int The `i32` value at the given offset.
	-- @function read_i32

	--- Reads a signed 64-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @treturn int The `i64` value at the given offset. It is an `int64_t` cdata value.
	-- @function read_i64

	--- Reads a 32-bit floating-point number (a `float`) at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn number The `f32` value at the given offset.
	-- @function read_f32
	RawBuffer_methods.read_f32 = make_read_func("float")

	--- Reads a 64-bit floating-point number (a `double`) at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @treturn number The `f64` value at the given offset.
	-- @function read_f64
	RawBuffer_methods.read_f64 = make_read_func("double")

	--- Reads a string of a given length at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer.
	-- @tparam int len Length of the string. Must not exceed buffer size.
	-- @treturn string A copy of the data as string.
	-- @function read_string
	RawBuffer_methods.read_string = wrap_secret_and_atomar(function(s, offset, len)
		len = check_int(len, 0ULL, int_ranges_maxs.uint64_t, ctype_uint64_t)
		offset = check_offset(s, offset, len)

		return ffi_string(s.m_buffer + offset, len)
	end)
end

-- TODO: remove append and make write to:
-- * resize until offset if big
-- * reserve
-- * write and possibly increase size
-- or not?

-- write methods
do
	local function make_write_func(type_str, value_checker)
		local type_size = ffi_sizeof(type_str)
		local ctype_ptr = ffi.typeof(type_str.." *")
		value_checker = value_checker or function(v) return v end

		return wrap_secret_and_atomar(function(s, offset, value)
			offset = check_offset(s, offset, type_size)
			value = value_checker(value)

			ffi_cast(ctype_ptr, s.m_buffer + offset)[0] = value
		end)
	end

	local function make_int_write_func(type_str)
		local min = assert(int_ranges_mins[type_str])
		local max = assert(int_ranges_maxs[type_str])
		return make_write_func(type_str, function(value)
			return check_int(value, min, max, ffi.typeof(type_str))
		end)
	end

	for _, i in IE.ipairs({1, 2, 4, 8}) do
		local type_str = string_format("int%d_t", i * 8)
		RawBuffer_methods["write_u"..(8*i)] = make_int_write_func("u"..type_str)
		RawBuffer_methods["write_i"..(8*i)] = make_int_write_func(type_str)
	end

	--- Writes an unsigned 8-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `u8` value to write.
	-- @function write_u8

	--- Writes an unsigned 16-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `u16` value to write.
	-- @function write_u16

	--- Writes an unsigned 32-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `u32` value to write.
	-- @function write_u32

	--- Writes an unsigned 64-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `u64` value to write. Can be a `uint64_t` cdata value.
	-- @function write_u64

	--- Writes a signed 8-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `i8` value to write.
	-- @function write_i8

	--- Writes a signed 16-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `i16` value to write.
	-- @function write_i16

	--- Writes a signed 32-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `i32` value to write.
	-- @function write_i32

	--- Writes a signed 64-bit integer at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam int value The `i64` value to write. Can be an `int64_t` cdata value.
	-- @function write_i64

	--- Writes a 32-bit floating-point number (a `float`) at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam number value The `f32` value to write.
	-- @function write_f32
	RawBuffer_methods.write_f32 = make_write_func("float")

	--- Writes a 64-bit floating-point number (a `double`) at a given byte-offset.
	-- @tparam int offset Byte-offset in the buffer
	-- @tparam number value The `f64` value to write.
	-- @function write_f64
	RawBuffer_methods.write_f64 = make_write_func("double")

	--- TODO
	-- @function copy_from
	local function RawBuffer_methods_copy_from_inner(s_dst, dst_offset, s_src, src_offset, len)
		len = check_int(len, 0ULL, int_ranges_maxs.uint64_t, ctype_uint64_t)
		dst_offset = check_offset(s_dst, dst_offset, len)
		src_offset = check_offset(s_src, src_offset, len)

		if s_dst == s_src
				-- if they overlap, each start must be before the other's end
				-- if they don't overlap, one comes after the other
				and dst_offset < src_offset + len and src_offset < dst_offset + len then
			C.memmove(s_dst.m_buffer + dst_offset, s_src.m_buffer + src_offset, len)
		else
			ffi_copy(s_dst.m_buffer + dst_offset, s_src.m_buffer + src_offset, len)
		end
	end
	function RawBuffer_methods:copy_from(dst_offset, src_buf, src_offset, len)
		local s_dst = assert(s_RawBuffer_secrets[self])
		local s_src = assert(s_RawBuffer_secrets[src_buf])
		set_lock(s_dst)
		set_lock(s_src)
		RawBuffer_methods_copy_from_inner(s_dst, dst_offset, s_src, src_offset, len)
		unset_lock(s_src)
		unset_lock(s_dst)
	end
end

-- append methods
do
	local function make_append_func(type_str, value_checker)
		local type_size = ffi_sizeof(type_str)
		local ctype_ptr = ffi.typeof(type_str.." *")
		value_checker = value_checker or function(v) return v end

		return wrap_secret_and_atomar(function(s, value)
			value = value_checker(value)

			RawBuffer_methods_reserve(s, s.m_size + type_size)

			ffi_cast(ctype_ptr, s.m_buffer + s.m_size)[0] = value
			s.m_size = s.m_size + type_size
		end)
	end

	local function make_int_append_func(type_str)
		local min = assert(int_ranges_mins[type_str])
		local max = assert(int_ranges_maxs[type_str])
		return make_append_func(type_str, function(value)
			return check_int(value, min, max, ffi.typeof(type_str))
		end)
	end

	for _, i in IE.ipairs({1, 2, 4, 8}) do
		local type_str = string_format("int%d_t", i * 8)
		RawBuffer_methods["append_u"..(8*i)] = make_int_append_func("u"..type_str)
		RawBuffer_methods["append_i"..(8*i)] = make_int_append_func(type_str)
	end

	--- Appends an unsigned 8-bit integer to the end of the buffer.
	-- @tparam int value The `u8` value to write.
	-- @function append_u8

	--- Appends an unsigned 16-bit integer to the end of the buffer.
	-- @tparam int value The `u16` value to write.
	-- @function append_u16

	--- Appends an unsigned 32-bit integer to the end of the buffer.
	-- @tparam int value The `u32` value to write.
	-- @function append_u32

	--- Appends an unsigned 64-bit integer to the end of the buffer.
	-- @tparam int value The `u64` value to write. Can be a `uint64_t` cdata value.
	-- @function append_u64

	--- Appends a signed 8-bit integer to the end of the buffer.
	-- @tparam int value The `i8` value to write.
	-- @function append_i8

	--- Appends a signed 16-bit integer to the end of the buffer.
	-- @tparam int value The `i16` value to write.
	-- @function append_i16

	--- Appends a signed 32-bit integer to the end of the buffer.
	-- @tparam int value The `i32` value to write.
	-- @function append_i32

	--- Appends a signed 64-bit integer to the end of the buffer.
	-- @tparam int value The `i64` value to write. Can be an `int64_t` cdata value.
	-- @function append_i64

	--- Appends a 32-bit floating-point number (a `float`) to the end of the buffer.
	-- @tparam number value The `f32` value to write.
	-- @function append_f32
	RawBuffer_methods.append_f32 = make_append_func("float")

	--- Appends a 64-bit floating-point number (a `double`) to the end of the buffer.
	-- @tparam number value The `f64` value to write.
	-- @function append_f64
	RawBuffer_methods.append_f64 = make_append_func("double")
end

return raw_buffer
