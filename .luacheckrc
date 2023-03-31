
ignore = {}

read_globals = {
	"minetest",
	"INIT",
	"vector",
	"dslib",
	table = {fields = {"key_value_swap"}},
}

globals = {}

local files_with_insec_env = {"init.lua", "src/raw_buffer.lua", "src/new_luajit_stuff.lua"}

for _, f in ipairs(files_with_insec_env) do
	files[f] = {
		-- do _G.fun() explicitly instead of fun()
		std = {
			read_globals = {"_G"},
		},
		-- TODO: forbid using global dslib (instead _G.dslib), to avoid confusion with IE.dslib
	}
end

files["init.lua"].globals = {"dslib"}
