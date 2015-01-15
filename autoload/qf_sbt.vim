" Dependencies: vimproc, current_project.vim

" {project_dir: sbt_proc}
if !exists('s:procs')
	let s:procs = {}
endif

function! qf_sbt#restart(...) abort " {{{
	call qf_sbt#stop()
	sleep 1000m
	call call('qf_sbt#start', a:000)
endfunction " }}}

function! qf_sbt#quit_all() abort " {{{
	for path in keys(s:procs)
		call s:procs[path].kill()
		call remove(s:procs, path)
	endfor
endfunction " }}}

function! qf_sbt#clean() abort " {{{
	call qf_sbt#restart('clean')
endfunction " }}}

function! qf_sbt#start(...) abort " {{{
	let precommands = a:000
	let info = current_project#info()
	let proc = s:getProc()
	if qf_sbt#is_valid(proc)
		echo "sbt already started"
		return
	endif

	echo 'starting sbt...'
	execute 'lcd ' . info.path
	let proc = s:CProc.new(info.path, ['sbt', '-J-Dsbt.log.format=false', 'set target <<= baseDirectory.apply {bd => new java.io.File(bd, "target/qf-sbt")}'] + precommands + ['~test:compile'])
	let s:procs[info.path] = proc
	lcd -
endfunction " }}}

function! qf_sbt#stop() abort " {{{
	let proc = s:getProc()
	if qf_sbt#is_valid(proc)
		echo 'stopping sbt...'
		call proc.kill()
	endif
	call s:releaseProc()
endfunction " }}}

function! qf_sbt#get_proc() abort " {{{
	return s:getProc()
endfunction " }}}

function! qf_sbt#is_valid(proc) abort " {{{
	return !empty(a:proc) && a:proc.is_valid()
endfunction " }}}

function! qf_sbt#all_procs() abort " {{{
	return s:procs
endfunction " }}}

function! qf_sbt#list_procs() abort " {{{
	let home = fnamemodify('~', ':p')
	for key in keys(s:procs)
		let proc = s:procs[key]
		call proc.update()
		let path = substitute(key, '^\V' . escape(home, '\'), '~', '')
		echo printf('%-40s %-10s %s', path, proc.state, proc.build_status_string)
	endfor
endfunction " }}}

function! qf_sbt#status_string(options) abort " {{{
	let proc = qf_sbt#get_proc()
	if empty(proc) " sbt not started
		return ''
	elseif !qf_sbt#is_valid(proc) " sbt started, but died unexpectedly.
		return '(>_<)'
	else
		" throttle for prevent too many updates
		if !exists('b:qf_sbt_status_string_updated')
			let b:qf_sbt_status_string_updated = reltime()
		endif
		if str2float(reltimestr(reltime(b:qf_sbt_status_string_updated))) > 0.5
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

function! s:getProc() abort " {{{
	let info = current_project#info()
	return get(s:procs, info.path, {})
endfunction " }}}

function! s:releaseProc() abort " {{{
	let info = current_project#info()
	if has_key(s:procs, info.path)
		call remove(s:procs, info.path)
	endif
endfunction " }}}

" Class system {{{
function! s:new_instance(proto, data) abort " {{{
	for name in keys(a:proto)
		let a:data[name] = a:proto[name]
	endfor
	return a:data
endfunction " }}}

function! s:default_initialize(...) dict abort " {{{
endfunction " }}}

function! s:new(...) dict abort " {{{
	let instance = s:new_instance(self, {})
	call call(self.initialize, a:000, instance)
	return instance
endfunction " }}}

function! s:new_class() abort " {{{
	return {'new': function('s:new'), 'initialize': function('s:default_initialize')}
endfunction " }}}
" }}}

" Class Proc {{{
	let s:CProc = s:new_class()
	function! s:CProc.initialize(path, cmd) dict abort " {{{
		let self.path = a:path
		let self.command = a:cmd
		let self.proc = vimproc#popen2(a:cmd)
		let self.last_compile_events = []
		let self._buf = []
		let self.log = []
		let self.state = 'startup' " startup -> compile -> idle -> compile
		let self.last_compile_result = ''
		let self.last_build_number = 0

		let self.build_status_version = 0
		let self.build_status_string = '...'
	endfunction " }}}
	function! s:CProc.is_valid() dict abort " {{{
		return self.proc.checkpid()[0] == 'run'
	endfunction " }}}
	function! s:CProc.kill() dict abort " {{{
		if self.is_valid()
			call self.proc.kill()
		endif
	endfunction " }}}
	function! s:CProc.update() dict abort " {{{
		let lines = self.proc.stdout.read_lines(-1, 20)
		for l in lines
			if get(g:, 'sbt_qf_debug', 0)
				echo l
			endif
			call add(self.log, l)
			if self.state == 'idle' || self.state == 'startup'
				if l =~# '\v^\[info\] Compiling '
					let self.log = [l]
					let self.state = 'compile'
				elseif l =~# '\v^\[success\] Total time\:.*completed.*'
					let self.last_build_number += 1
					let self.state = 'idle'
					let self.last_compile_result = 'success'
					let self.last_compile_events = []
				else
					" ignore line
				endif
			elseif self.state == 'compile'
				if l =~# '\v^\[(success|error)\] Total time\:.*completed.*' || l =~# '\v^\[error\] .* Compilation failed'
					let self.last_compile_events = s:build_compile_events(self._buf)
					let self._buf = []
					let self.state = 'idle'
					let self.last_build_number += 1
					if l =~ '\v^\[success\]'
						let self.last_compile_result = 'success'
					else
						let self.last_compile_result = 'error'
					endif
				else
					call add(self._buf, l)
				endif
			else
				throw "Invalid state: " . self.state
			endif
		endfor
		if len(self.proc.stdout.buffer) > 0 && self.proc.stdout.buffer[-1] =~# '\V\^Project loading failed: (r)etry, (q)uit, (l)ast, or (i)gnore?'
			call self.proc.stdin.write("q\n")
		endif
		call self._update_build_status_string(lines)
		return lines
	endfunction " }}}
	function! s:CProc.set_qf() dict abort " {{{
		let message_width = 150
		let qf_items = []
		let typecodes = {'error': 'E', 'warn': 'W'}
		for ev in self.last_compile_events
			call add(qf_items, {
			\ 'filename': ev.path,
			\ 'lnum': ev.line,
			\ 'text': "\n" . join(map(ev.message, 'join(split(v:val, "\\v.{,' . message_width . '}\\zs"), "\n")'), "\n"),
			\ 'type': typecodes[ev.type],
			\ })
		endfor
		if getqflist() != qf_items
			call setqflist(qf_items)
		endif
	endfunction " }}}
	function! s:CProc._update_build_status_string(messages) dict abort " {{{
		let messages = a:messages
		if empty(messages)
			return
		endif
		let self.build_status_version += 1
		let s = ""
		let error_count = 0
		let warn_count = 0
		if self.state == 'startup'
			let s .= repeat(".", self.build_status_version % 4 + 1)
		elseif self.state == 'idle'
			if self.last_compile_result == 'success'
				let s .= "[S]"
			elseif self.last_compile_result == 'error'
				let s .= "[E]"
			endif
			for e in self.last_compile_events
				if e.type == 'error'
					let error_count += 1
				elseif e.type == 'warn'
					let warn_count += 1
				else
					echoerr "[qf_sbt.vim] WARN: Unknown compile event type: " . e.type
				endif
			endfor
		elseif self.state == 'compile'
			let s .= "[" . repeat(".", self.build_status_version % 4 + 1) . "] "
			if !empty(messages)
				let m = matchlist(messages[-1], '\v^\[(error|warn|info|success)\] (.*)')
				if empty(m)
					let s .= messages[-1][0:20]
				else
					let s .= m[1][0] . ':' . m[2][0:20]
				endif
			endif
		endif
		if error_count > 0
			let s .= "E" . error_count
		endif
		if warn_count > 0
			let s .= "W" . warn_count
		endif
		let self.build_status_string = s
		return s
	endfunction " }}}
" }}}

function! s:build_compile_events(lines) abort " {{{
	let result = []
	let cur = {}
	for l in a:lines
		if l =~# '\v (error|warning)s? found$' || l =~# '\v Compilation failed$'
			continue
		endif
		let m = matchlist(l, '^\v\[(error|warn)\] (.*\.%(java|scala)):([0-9]+):(.*)')
		if !empty(m)
			" start of error/warn
			if !empty(cur)
				call add(result, cur)
			endif
			let cur = {'type': m[1], 'path': m[2], 'line': str2nr(m[3]), 'message': [m[4]]}
		elseif has_key(cur, 'path')
			" error/warn message
			call add(cur.message, substitute(l, '\v^\[(error|warn)\] ', '', 'g'))
		else
			" do nothing
		endif
	endfor
	if get(cur, 'path', '') != ''
		call add(result, cur)
	endif
	return result
endfunction " }}}
