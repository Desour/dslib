
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

--- The `table.new` function.
--
-- Returns an empty new table if `table.new` was not found.
-- @function table_new
new_luajit_stuff.table_new = IE.table.new or function() return {} end

return new_luajit_stuff
