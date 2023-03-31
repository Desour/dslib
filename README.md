<!--
Copyright (C) 2023 DS

SPDX-License-Identifier: CC0-1.0
-->

DSlib
=====

A modding helper library for Minetest mods.

Required Minetest version: >= 5.5.0

**Warning**: Adding this mod to `secure.trusted_mods` in a Minetest version prior
to 5.5.0 is considered insecure. (I.e. because mods had access to `debug.setupvalue`
and `debug.setlocal`.)

This repo is hosted on Codeberg (<https://codeberg.org/Desour/dslib>), and there's
a mirror on GitHub (<https://github.com/Desour/dslib>).


# Info for non-modders

Some modules of this library mod require `dslib` to be in the `secure.trusted_mods`
setting if they are used.

You can see this via a mod error when starting a server. The backtrace will show
you a mod that requires the features.

If you don't want to or can't check yourself whether you can trust this mod, you
can try to:

* look for reviews from trustworthy competent persons somewhere else,
* use depending mods as trust source (if a mod uses a feature of DSlib that requires
  it to be trusted, and doesn't explicitly warn about insecure-ness, the mod author
  probably trusts (some version of) DSlib) and/or
* think about the trustworthiness of your other mods (if they are all not malicious
  and do not dynamically load and execute new code, there is nothing that would
  knowingly exploit existing vulnerabilities).

But in the end, it's still your responsibility to decide.
The methods above most likely won't work.


# Features

The most important reason why one decides to use a library is its features, so
here we go:

* `dslib:mmodules`: An api to `dslib.mrequire()` (works almost like `require()`) and
  register modules.
* `dslib:rotnum`: Helpers to make working with 90° rotations easy, ie. for facedir.
* `dslib:raw_buffer`: TODO, experimental
* `dslib:endian_helpers`: Functions for converting numbers between native,
  little and big endian-ness.
* `dslib:new_luajit_stuff`: Extensions from new LuaJIT (ie. `table.new()`).
* `dslib:fmt`: Text formatting. (unfinished)
* TODO: module for more fine grained depends


# Qualities

Before deciding to use this library, you will want to check on some exclusion
criteria. Be assured that the following qualities are (hopefully) ensured:

* Everything must be secure.
  (That is: No mod must be able to escape the sandbox because of this mod.)
  If you find something suspicious, please tell me. Everything non-obvious must
  be explained via a comment.
  Experimental modules may be insecure, but they can not be loaded.
* There must be documentation for every feature that is intended for use.
* One should not pay for bloat that one doesn't use. (Ie. submodules are not
  loaded unless `mrequire()`d.)


# Documentation

Documentation is done using [ldoc](https://stevedonovan.github.io/ldoc/).

To generate the documentation, first install ldoc, then do:
`$ make doc`
Then open `doc/ldoc/index.html` with a web browser.


# The files in this repo

* `README.md`: I am this.
* `.luacheckrc`: Config for luacheck (`$ luacheck .`).
* `config.ld`: Config for ldoc.
* `init.lua`, `src/*`: The src files.
* `mod.conf`: Mod conf for minetest.
* `examples/*`: Usage examples for you.
* `doc/*`: Documentation stuff.
* `.gitignore`: Git stuff.
* `tests/*`: Unittests written for [busted](https://olivinelabs.com/busted/).
* `Makefile`: A makefile with some targets for ldoc, luacheck, busted and co..
* TODO: add missing files


# TODOs

* add stuff
* add examples
* add more unittests
* find out how to fix the line offsets in ldoc source pages


# License

The relevant code is licensed under Apache-2.0.

Everything else is CC0-1.0.

Command for adding a license header:
`$ reuse annotate --template=mytemplate --copyright-style=string-c --license="Apache-2.0" --copyright="YOUR NAME" FILES`


# Reporting security issues

You can report security issues to me via pm on the minetest forums, by opening
an issue, by commenting to a commit, via a comment on minetest forums or via dm
when you see me anywhere.

For issues in recent changes or experimental modules, you may prefer more public
means of communication. Otherwise more private ways are preferred (ie. forums pm),
but not required.

(I will try to acknowledge your message as fast as possible so you know I've read
it.)


# Contributing

Despite this repo's name, contributions from other persons than me are welcome, if
they fit in the overall theme.
