# qf_sbt.vim: SBT Vim integration

## Features

* Async execution
* Set error/warnings to quickfix
* SBT processes are managed by vim
* SBT plugin not needed.

## Dependency

* [current_project.vim](https://github.com/todesking/current_project.vim)
* [VimProc](https://github.com/Shougo/vimproc.vim)

## Related plugin

* [sbt-quickfix](https://github.com/dscleaver/sbt-quickfix)
  * The plugin provides similar functions(Update quickfix from sbt compile result).
  * It use sbt plugin to generate compile result, then update quickfix with `clientserver` feature.
  * Need sbt plugin
* [sbt-vim](https://github.com/ktvoelker/sbt-vim)
  * No async feature
  * Need python
