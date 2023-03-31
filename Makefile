# Copyright (C) 2023 DS
#
# SPDX-License-Identifier: CC0-1.0

.PHONY: default clean doc clean_doc test run_static_checks run_unittests

default:

clean: clean_doc

doc:
	ldoc .

clean_doc:
	rm -r doc/ldoc/

test: run_static_checks run_unittests

run_static_checks:
	luacheck .

run_unittests:
	busted .
