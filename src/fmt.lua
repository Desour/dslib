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

---
-- Unfinished.
--
-- TODO: doc
-- TODO: caching
-- TODO: compiling
--
-- @module dslib:fmt

local fmt = {}
fmt.version = "0.1.0"

local function table_insert_all(t, ...)
	local s = #t
	for i = 1, select("#", ...) do
		t[s+i] = select(i, ...)
	end
end

local function table_insert_all_after_apply(f, t, ...)
	local s = #t
	for i = 1, select("#", ...) do
		t[s+i] = f(select(i, ...))
	end
end

local function my_string_split(s, c)
	local parts = {}
	local current_start = 0
	for i = 1, #s do
		if s:sub(i, i) == c then
			table.insert(parts, s:sub(current_start, i-1))
			current_start = i+1
		end
	end
	table.insert(parts, s:sub(current_start, -1))
	return parts
end

local log_level_ignored = (function()
		if minetest.is_fake then
			return {}
		end
		local log_levels = {"none", "error", "warning", "action", "info", "verbose"}
		local log_level_hierarchy = table.key_value_swap(log_levels)
		log_level_hierarchy[""] = 0
		log_level_hierarchy["trace"] = 7
		local log_level_min = math.max(math.max(
				log_level_hierarchy[minetest.settings:get("chat_log_level")],
				log_level_hierarchy[minetest.settings:get("debug_log_level")]),
				log_level_hierarchy[minetest.settings:get("dslib.fmt.nonignore_log_level") or "action"])
		local ignored = {}
		for h, level in ipairs(log_levels) do
			if h > log_level_min then
				ignored[level] = true
			end
		end
		return ignored
	end)()

local function parse_log_level_mappings()
	local err_prefix = "dslib:fmt: Failed to parse secure.dslib.fmt.log_level_mappings:"
	local valid_log_levels = table.key_value_swap({"none", "error", "warning", "action", "info", "verbose"})
	local valid_mappings   = table.key_value_swap({"none", "error", "warning", "action", "info", "verbose", "quiet"})

	local setting_str = minetest.settings:get("secure.dslib.fmt.log_level_mappings") or "{}"
	local define_vars_without_quotes = ""
	for _, level in ipairs({"none", "error", "warning", "action", "info", "verbose", "log"}) do
		define_vars_without_quotes = define_vars_without_quotes
				.. "local "..level.."=\"tried_to_use_variable\";"
	end
	local ret, errmsg = minetest.deserialize("return "..setting_str, true)
	if not ret then
		error(string.format("%s	Could not deserialize: %s", err_prefix, errmsg))
	end

	local global = ret.global or {}
	local mods = ret.mods or {}
	ret.global = nil
	ret.mods = nil
	if next(ret) then
		local k = next(ret)
		error(string.format("%s What's this '%s'?", err_prefix, k))
	end

	local function check_entry(entry, name)
		for k, v in pairs(entry) do
			if not valid_log_levels[k] then
				if k == "log" then
					error(string.format("%s 'log' is not a log level. Did you mean 'none'? (found in %s)", err_prefix, name))
				else
					error(string.format("%s '%s' is not a log level. (found in %s)", err_prefix, k, name))
				end
			end
			if not valid_mappings[k] then
				if k == "tried_to_use_variable" then
					error(string.format("%s You forgot the quotes. (found in %s.%s)", err_prefix, name, k))
				elseif k == "log" then
					error(string.format("%s 'log' is not a log level. Did you mean 'none'? (found in %s.%s)", err_prefix, name, k))
				else
					error(string.format("%s '%s' is not a log level. (found in %s.%s)", err_prefix, v, name, k))
				end
			end
		end
	end

	check_entry(global, "global")
	for k, v in pairs(mods) do
		check_entry(v, "mods."..k)
	end

	return {global = global, mods = mods}
end

local log_level_mappings
if minetest.is_fake then
	log_level_mappings = {global = {}, mods = {}}
else
	log_level_mappings = parse_log_level_mappings()
end

local function get_mod_log_level_mappings(modname)
	local for_global = log_level_mappings.global
	local for_mod = log_level_mappings.mods[modname]
	local mappings = {}
	for _, level in ipairs({"none", "error", "warning", "action", "info", "verbose"}) do
		mappings[level] = for_mod[level] or for_global[level] or level
	end
	return mappings
end

local function split_fmtstr(fmtstr)
	local result = {}
	local brace_depth = 0
	local current_start = 0
	local current_part_partly = "" -- used for unescaping {{ and }}
	local skip_one = false
	for i = 1, #fmtstr do
		if skip_one then
			skip_one = false
		else
			local c = fmtstr:sub(i, i)
			if c == "{" then
				if fmtstr:sub(i+1, i+1) == "{" then
					current_part_partly = current_part_partly..fmtstr:sub(current_start, i)
					current_start = i+2
					skip_one = true
				else
					if brace_depth == 0
							and (i > current_start or current_part_partly ~= "") then -- ignore ""
						table.insert(result, "raw")
						table.insert(result, current_part_partly..fmtstr:sub(current_start, i-1))
					end
					brace_depth = brace_depth + 1
					current_start = i+1
				end
			elseif c == "}" then
				if fmtstr:sub(i+1, i+1) == "}" then
					current_part_partly = current_part_partly..fmtstr:sub(current_start, i)
					current_start = i+2
					skip_one = true
				else
					brace_depth = brace_depth - 1
					if brace_depth == 0 then
						table.insert(result, "fmt")
						table.insert(result, current_part_partly..fmtstr:sub(current_start, i-1))
						current_start = i+1
					elseif brace_depth < 0 then
						error(string.format("Invalid fmtstr: Found unmatched } at %d in fmtstr: %s", i, fmtstr))
					end
				end
			end
		end
	end
	if brace_depth > 0 then
		error(string.format("Invalid fmtstr: Some { was not closed in fmtstr: %s", fmtstr))
	end
	if (#fmtstr >= current_start or current_part_partly ~= "") then -- ignore ""
		table.insert(result, "raw")
		table.insert(result, current_part_partly..fmtstr:sub(current_start, -1))
	end
	return result
end

-- parses the {:<fmt_spec>} thing
-- result is passed to formatter
function fmt.parse_fmt_spec(fmt_spec)
	return fmt_spec
end

function fmt.formatter(spec, arg) --TODO
	local arg_typ = type(arg)
	if arg_typ == "string" then
		assert(spec == "")
		return arg
	else
		assert(spec == "")
		return tostring(arg)
	end
end

local function make_fmt(escaper, do_nt)
	local my_table_insert_all = escaper
			and function(...) return table_insert_all_after_apply(escaper, ...) end
			or table_insert_all

	local parse_arg_key = do_nt
			and function(s)
				local parts = my_string_split(s, ".")
				for i = 1, #parts do
					parts[i] = tonumber(parts[i]) or parts[i]
				end
				return #parts == 1 and parts[1] or parts
			end
			or function(s)
				return tonumber(s) or s
			end

	local lookup_arg = do_nt
			and function(tabl, k)
				if type(k) ~= "table" then
					return tabl[k]
				end
				local arg = tabl[k[1]]
				for i = 2, #k do
					arg = arg and arg[k[i]]
				end
				return arg
			end
			or function(tabl, k)
				return tabl[k]
			end

	local function parse_fmtstr(fmtstr)
		local parts = split_fmtstr(fmtstr)
		local next_unnamed_arg_idx = 1
		for i = 1, #parts, 2 do
			if parts[i] == "fmt" then
				local f = parts[i+1]
				local j = f:find(":")
				local arg_name = j and f:sub(j-1) or f
				local fmt_spec = j and f:sub(j+1, -1) or ""
				local arg_key
				if arg_name == "" then
					arg_key = next_unnamed_arg_idx
					next_unnamed_arg_idx = next_unnamed_arg_idx + 1
				else
					arg_key = parse_arg_key(arg_name)
				end
				fmt_spec = fmt.parse_fmt_spec(fmt_spec)
				parts[i+1] = {arg_key, fmt_spec}
			end
		end
		return parts
	end

	return function(fmtstr, tabl)
		local instructions = parse_fmtstr(fmtstr)
		local result = {}
		for i = 1, #instructions, 2 do
			if instructions[i] == "raw" then
				table.insert(result, instructions[i+1])
			else -- instructions[i] == "fmt"
				local f = instructions[i+1]
				my_table_insert_all(result,
						fmt.formatter(f[2], lookup_arg(tabl, f[1])))
			end
		end
		return table.concat(result)
	end
end

--- Escapes characters that would be interpreted in a format string.
--
-- @tparam string str
-- @treturn string The escaped string.
function fmt.escape_fmtstr(str)
	return str:gsub("[{}]", "%0%0")
end

function fmt.fmt(fmtstr, ...)
	return fmt.fmtt(fmtstr, {...})
end

-- t for table
fmt.fmtt = make_fmt(nil, false)

-- nt for nested table
fmt.fmtnt = make_fmt(nil, true)

function fmt.print(fmtstr, ...)
	print(fmt.fmt(fmtstr, ...))
end

function fmt.printt(fmtstr, t)
	print(fmt.fmtt(fmtstr, t))
end

function fmt.printnt(fmtstr, nt)
	print(fmt.fmtnt(fmtstr, nt))
end

local log_func_per_level = {}
local logt_func_per_level = {}
local lognt_func_per_level = {}
for _, level in ipairs({"none", "error", "warning", "action", "info", "verbose"}) do
	if log_level_ignored[level] then
		log_func_per_level[level]   = function() end
		logt_func_per_level[level]  = function() end
		lognt_func_per_level[level] = function() end
	else
		log_func_per_level[level]   = function(...)
			minetest.log(level, fmt.fmt(...))
		end
		logt_func_per_level[level]  = function(...)
			minetest.log(level, fmt.fmtt(...))
		end
		lognt_func_per_level[level] = function(...)
			minetest.log(level, fmt.fmtnt(...))
		end
	end
	fmt["log_"  ..level] = log_func_per_level[level]
	fmt["logt_" ..level] = logt_func_per_level[level]
	fmt["lognt_"..level] = lognt_func_per_level[level]
end

log_func_per_level.log   = log_func_per_level.none
logt_func_per_level.log  = logt_func_per_level.none
lognt_func_per_level.log = lognt_func_per_level.none
fmt.log_log   = log_func_per_level.log
fmt.logt_log  = logt_func_per_level.log
fmt.lognt_log = lognt_func_per_level.log

-- note: level not optional if fmtstr is "warning" or similar
function fmt.log(level, ...)
	local f = log_func_per_level[level]
	if f then
		return f(...)
	else
		return fmt.log_log(level, ...)
	end
end

function fmt.logt(level, fmtstr, t)
	if t then
		return logt_func_per_level[level](fmtstr, t)
	else
		return fmt.logt_log(level, fmtstr)
	end
end

function fmt.lognt(level, fmtstr, t)
	if t then
		return lognt_func_per_level[level](fmtstr, t)
	else
		return fmt.lognt_log(level, fmtstr)
	end
end

function fmt.get_loggers_for_mod(modname)
	local log = {}

	local level_mappings = get_mod_log_level_mappings(modname)
	for _, level in ipairs({"none", "error", "warning", "action", "info", "verbose"}) do
		local mlevel = level_mappings[level]
		if mlevel == "quiet" then
			log[level]       = function() end
			log[level.."t"]  = function() end
			log[level.."nt"] = function() end
		else
			log[level]       = fmt["log_"..mlevel]
			log[level.."t"]  = fmt["logt_"..mlevel]
			log[level.."nt"] = fmt["lognt_"..mlevel]
		end
	end

	log.log   = log.none
	log.logt  = log.nonet
	log.lognt = log.nonent

	return log
end

function fmt.fmt_formspec(fmtstr, ...)
	return fmt.fmtt_formspec(fmtstr, {...})
end

fmt.fmtt_formspec = make_fmt(minetest.formspec_escape, false)

fmt.fmtnt_formspec = make_fmt(minetest.formspec_escape, true)

return fmt
