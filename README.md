# qf_sbt.vim: SBT Vim integration

## Current status

Works well, poorly documented.

## Features

* Async execution
* Set error/warnings to quickfix
* SBT processes are managed by vim
* SBT plugin not needed.

## Dependency

* [current_project.vim](https://github.com/todesking/current_project.vim)
* [VimProc](https://github.com/Shougo/vimproc.vim)

## Usage

### Commands

All operations are based on current buffer's project root.

* `SbtStart`
* `SbtStop`
* `SbtRestart`
* `SbtClean`
* `SbtLog`

### Vimrc example

```vim
function! Vimrc_build_status() abort " {{{
	let proc = qf_sbt#get_proc()
	if empty(proc) " sbt not started
		return ''
	elseif !qf_sbt#is_valid(proc) " sbt started, but died unexpectedly.
		return '(>_<)'
	else
		" throttle for prevent too many updates
		if !exists('b:vimrc_build_status_last_updated')
			let b:vimrc_build_status_last_updated = reltime()
		endif
		if str2float(reltimestr(reltime(b:vimrc_build_status_last_updated))) > 0.5
			let build_number = proc.last_build_number
			call proc.update()
			if build_number < proc.last_build_number
				call proc.set_qf() " Set build result to quickfix
			endif
			let b:vimrc_build_status_last_updated = reltime()
		endif
		return proc.build_status_string
	endif
endfunction " }}}

set statusline='... %{Vimrc_build_status()} ...'
```

## Related plugin

* [sbt-quickfix](https://github.com/dscleaver/sbt-quickfix)
  * The plugin provides similar functions(Update quickfix from sbt compile result).
  * It use sbt plugin to generate compile result, then update quickfix with `clientserver` feature.
  * Need sbt plugin
* [sbt-vim](https://github.com/ktvoelker/sbt-vim)
  * No async feature
  * Need python
