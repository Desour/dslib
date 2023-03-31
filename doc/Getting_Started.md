<!--
Copyright (C) 2023 DS

SPDX-License-Identifier: CC0-1.0
-->

Getting Started
===============

First, read `README.md`.

See "Index" at the left for a list of all available modules.


# What every mod should do

Every mod that wants to be a good, cooperative mod, and that depends on DSlib,
should call the functions from `dslib:start_end` when it starts and finishes
loading.

These functions should before/after *anything* is done by your mod, this includes
things such as loading time measurements or module require calls.

Here's some boilerplate code to copy:

```lua
dslib.mrequire("dslib:start_end").report_mod_load_start()

-- your code

dslib.mrequire("dslib:start_end").report_mod_load_end()
```

And here's the respective thing for optional dependents:

```lua
if minetest.global_exists("dslib") then
	dslib.mrequire("dslib:start_end").report_mod_load_start()
end

-- your code

if minetest.global_exists("dslib") then
	dslib.mrequire("dslib:start_end").report_mod_load_end()
end
```

It is not a bad idea to optionally depend on DSlib, just to do these things.

Currently, these functions do nothing.
But there are usecases such as:

* Measuring the load time of each mod.
* Allowing mutual dependencies: Both mods register their APIs, and add a callback
  for when the other one is finished. In this callback (still at load time), they
  can use each other's API. (This is a TODO.)


# Loading modules

Before you can use a feature of a modules, you have to `dslib.mrequire()` it:

```lua
local foo = dslib.mrequire("dslib:foo")

foo.bar()
```

This works mostly like Lua's `require()`.
For more details, see `dslib` and the `dslib:mmodules` module.
