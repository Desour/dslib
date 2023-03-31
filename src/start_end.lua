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
