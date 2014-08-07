# qf_sbt.vim: SBT Vim integration

## Status

Under construction. No document, but I use the plugin usually.

## Dependency

* [VimProc](https://github.com/Shougo/vimproc.vim)

## Related plugin

[sbt-quickfix](https://github.com/dscleaver/sbt-quickfix) plugin provides similar functions(Update quickfix from sbt compile result).
It use sbt plugin to generate compile result, then update quickfix with `clientserver` feature.

In contrast, sbt-qf manage sbt process and parse raw compile result with VimProc.
