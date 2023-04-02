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

local fmt = dslib.mrequire("dslib:fmt")

describe("fmt", function()
	it("escape_fmtstr()", function()
		assert.equals("foo {{}}}}", fmt.escape_fmtstr("foo {}}"))
	end)

	it("fmt()", function()
		assert.equals("foo bla bard 1.4nil", fmt.fmt("foo {} bard {}{}", "bla", 1.4))
		assert.equals("foo {}}", fmt.fmt("foo {{}}}}"))
		assert.equals("foo 1 1 nil nil 2 nil 2", fmt.fmt("foo {1} {} {0} {-1} {2} {3} {2}", 1, 2))
	end)

	it("fmtt()", function()
		assert.equals("foo 1 1 nil nil 2 nil 2", fmt.fmtt("foo {1} {} {0} {-1} {2} {3} {2}", {1, 2}))
		assert.equals("foo 1 2", fmt.fmtt("foo {a} {}", {2, a = 1}))
	end)

	it("fmtnt()", function()
		assert.equals("foo 1 1 nil nil 2 nil 2", fmt.fmtnt("foo {1} {} {0} {-1} {2} {3} {2}", {1, 2}))
		assert.equals("foo 1 2", fmt.fmtnt("foo {a} {}", {2, a = 1}))
		assert.equals("foo 1 2", fmt.fmtnt("foo {a.1} {}", {2, a = {1}}))
		assert.equals("foo nil 2 nil", fmt.fmtnt("foo {asd.1.3} {asd.bar} {asd.baz.1}", {asd = {{}, bar = 2}}))
	end)

	it("formatter", function()
		_G.dump = function(val)
			return string.format("<dump(%s)>", val)
		end
		_G.dump2 = function(val)
			return string.format("<dump2(%s)>", val)
		end

		assert.equals("0x12", fmt.fmt("{:f(%#x)}", 18))
		assert.equals("<dump(foo)>", fmt.fmt("{:dump()}", "foo"))
		assert.equals("<dump2(foo)>", fmt.fmt("{:dump2()}", "foo"))

		assert.equals("foo{42}", fmt.fmt("{}",
				setmetatable({42}, {
					dslib_fmt_format = function(self) return string.format("foo{%s}", self[1]) end
				})))

		-- ideas that is probably too compilcated and not useful enough
		if false then
			-- luacheck: ignore (unreachable code)
			assert.equals("1", fmt.fmt("{:ifnil(lit(bla))}", 1))
			assert.equals("bla", fmt.fmt("{:ifnil(lit(bla))}", nil))
			assert.equals("bla", fmt.fmt("{:ifnil(lit(bla))}"))

			assert.equals("bar ", fmt.fmt("bar {:lit()}"))
			assert.equals("bar (", fmt.fmt("bar {:lit((()}"))
			assert.equals("bar )", fmt.fmt("bar {:lit()))}"))
			assert.equals("bar ,", fmt.fmt("bar {:lit(,)}"))
			assert.equals("bar {", fmt.fmt("bar {:lit({{)}"))

			assert.equals("bar baz", fmt.fmt("bar {:lit(baz)lit(bim)}"))
			assert.equals("bar y", fmt.fmt("bar {:if(,lit(y))}", "foo"))
			assert.equals("bar foo", fmt.fmt("bar {:if(not(),lit(y))}", "foo"))
			assert.equals("bar true", fmt.fmt("bar {:if(not(),lit(y))}", true))
			assert.equals("bar ", fmt.fmt("bar {:if(not(),lit(y))lit()}", true))
			assert.equals("bar y", fmt.fmt("bar {:if(not(),lit(y))}", nil))
			assert.equals("bar n", fmt.fmt("bar {:if(,lit(y))lit(n)}", nil))

			assert.equals("bar n", fmt.fmt("bar {:if(idx(1),idx(2))lit(n)}", {}))
			assert.equals("bar y", fmt.fmt("bar {:if(idx(1),idx(2))lit(n)}", {true,"y"}))
			assert.equals("bar true", fmt.fmt("bar {:idx(1)}", {true}))
			assert.equals("bar true", fmt.fmt("bar {:idx(a)}", {a = true}))
			assert.equals("bar boolean", fmt.fmt("bar {:type(boolean)}", true))
			assert.equals("bar y", fmt.fmt("bar {:if(type(boolean),lit(y))lit(n)}", true))
			assert.equals("bar n", fmt.fmt("bar {:if(type(boolean),lit(y))lit(n)}", nil))
		end
	end)
end)
