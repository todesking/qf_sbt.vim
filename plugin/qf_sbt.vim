" Dependencies: vimproc, current_project.vim

command! SbtStart  call qf_sbt#start()
command! SbtStop   call qf_sbt#stop()
command! SbtClean  call qf_sbt#clean()
command! SbtRestart call qf_sbt#restart()
command! SbtLog    echo join(qf_sbt#get_proc().log, "\n")
command! SbtList   call qf_sbt#list_procs()
command! SbtSetQf  call s:set_qf()

function! s:set_qf() abort " {{{
	let proc = qf_sbt#get_proc()
	if !qf_sbt#is_valid(proc)
		return
	endif
	call proc.update()
	call proc.set_qf()
endfunction " }}}

augroup qf_sbt
	autocmd!
	autocmd QuitPre * call qf_sbt#quit_all()
augroup END
