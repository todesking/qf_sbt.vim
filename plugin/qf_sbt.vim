" Dependencies: vimproc, current_project.vim

command! SbtStart  call qf_sbt#start()
command! SbtStop   call qf_sbt#stop()
command! SbtClean  call qf_sbt#clean()
command! SbtRestart call qf_sbt#restart()
command! SbtLog    echo join(qf_sbt#get_proc().log, "\n")

augroup qf_sbt
	autocmd!
	autocmd QuitPre * call qf_sbt.quit_all()
augroup END
