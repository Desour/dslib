<!--
Copyright (C) 2023 DS

SPDX-License-Identifier: CC0-1.0
-->

The plan on versioning is:

* Every module has a version:
  * Before it's intended for use, it's marked as experimental, and [zer0ver](https://0ver.org/)
    is done.
  * After some time, if the module is usable, the version jumps to `1.0.0`, from
    there on:
    * If compatibility is very badly broken, the version jumps to `<maj+1>.0.0`.
      The new version is then loaded via `dslib.mrequire("<modulename> <maj+1>")`,
      and the old version stays available, if possible.
    * Otherwise, if a new feature is introduced, the version jumps to `<maj>.<min+1>.0`.
    * Otherwise, if something worth an update happened, the version jumps to
      `<maj>.<min>.<patch+1>`.
* DSlib as a whole has a version:
  * The major version stays at `0` until it becomes `1`. Then it stays `1`.
  * Whenever one (or more at once) modules increase their major or minor version
    number, the minor version number of DSlib is also incremented by at least `1`.
  * Whenever one (or more at once) modules increase their patch version number,
    the patch version number of DSlib is also incremented by at least `1`.

As nobody enforces me to do this, it is likely this won't happen in practice for
now.

TODO: find out how to make this look good in ldoc
