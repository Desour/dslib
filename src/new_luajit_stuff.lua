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

--- Exposes secure parts of extensions from new LuaJIT versions.
--
-- See <https://repo.or.cz/luajit-2.0.git/blob_plain/refs/heads/v2.1:/doc/extensions.html>
-- for details of individual functions.
--
-- @module dslib:new_luajit_stuff

local load_vars = ...
local IE = load_vars.IE
_G.assert(IE ~= nil, "This module needs the insecure environment.")

local new_luajit_stuff = {}
new_luajit_stuff.version = "0.1.0"

IE.pcall(IE.dslib_ie.internal.require_with_IE_env, "table.new")

--- The `table.new` function.
--
-- Returns an empty new table if `table.new` was not found.
-- @function table_new
new_luajit_stuff.table_new = IE.table.new or function() return {} end

return new_luajit_stuff
