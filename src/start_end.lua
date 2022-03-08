
--- Nothing
-- @module dslib:start_end

local start_end = {}
start_end.version = "0.1.0"

--- Call this at the start of your `init.lua` file.
--
-- Does nothing for now, but might be useful in the future.
--
function start_end.report_mod_load_start()
end

--- Call this at the end of your `init.lua` file.
--
-- Does nothing for now, but will be useful in the future.
--
function start_end.report_mod_load_end()
end

return start_end
