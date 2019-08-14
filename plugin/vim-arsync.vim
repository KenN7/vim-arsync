" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

function! LoadConf()
  let conf = {}
  let l_configpath = expand('%:p:h')
  let l_configfile = l_configpath . '/.vim-arsync'
  let l_foundconfig = ''
  if filereadable(l_configfile)
    let l_foundconfig = l_configfile
  else
    while !filereadable(l_configfile)
      let slashindex = strridx(l_configpath, '/')
      if slashindex >= 0
        let l_configpath = l_configpath[0:slashindex]
        let l_configfile = l_configpath . '.vim-arsync'
        let l_configpath = l_configpath[0:slashindex-1]
        if filereadable(l_configfile)
          let l_foundconfig = l_configfile
          break
        endif
        if slashindex == 0 && !filereadable(l_configfile)
          break
        endif
      else
        break
      endif
    endwhile
  endif

  if strlen(l_foundconfig) > 0
    let options = readfile(l_foundconfig)
    for i in options
      let vname = substitute(i[0:stridx(i, ' ')], '^\s*\(.\{-}\)\s*$', '\1', '')
        if vname == "ignore_path"
            let vvalue = eval(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''))
            " echo substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', '')
        else
            let vvalue = escape(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''), "%#!")
        endif
      let conf[vname] = vvalue
    endfor
  endif
  return conf
endfunction

function! s:handler(job_id, data, event_type)
    " redraw | echom a:job_id . ' ' . a:event_type
    redraw | echom string(a:data)
endfunction

function! ShowConf()
    let conf = LoadConf()
    echo conf
endfunction

function! ARsync(direction)
    let conf = LoadConf()
    if has_key(conf, 'remote_host')
        let userpasswd = ""
        if has_key(conf, 'remote_user')
            let userpasswd = conf['remote_user'] . "@"
            if has_key(conf, 'remote_passwd')
                let userpasswd = conf['remote_user'] . ":" . conf['remote_passwd'] . "@"
            endif
        endif

        if a:direction == "up"
            let cmd = [ "rsync", "-avzhe", "ssh", conf['project_path'], userpasswd . conf['remote_host'] . ":" . conf['remote_path'], "--exclude", ".*"]
        elseif a:direction == "down"
            let cmd = [ "rsync", "-avzhe", "ssh", userpasswd . conf['remote_host'] . ":" . conf['remote_path'], conf['project_path'], "--exclude", ".*"]
        endif
        if has_key(conf, 'ignore_path')
            for d in conf['ignore_path']
                let cmd = cmd + ["--exclude", d]
            endfor
        endif

        " redraw | echom join(cmd)
        let jobid = arsync#job#start(cmd, {
            \ 'on_stdout': function('s:handler'),
            \ 'on_stderr': function('s:handler'),
            \ 'on_exit': function('s:handler'),
            \ })       
    else
        echo 'Could not locate a .vim-arsync configuration file. Aborting...'
    endif
endfunction

function! AutoSync()
    let conf = LoadConf()
    if has_key(conf, 'auto_sync_up')
        if conf["auto_sync_up"] == 1
            autocmd BufWritePost * ARsyncUp
            " echo "Setting up auto sync to remote"
        endif
    endif
endfunction

if !executable("rsync")
    echo "You need to install rsync to be able to use the vim-arsync plugin"
    finish
endif

command! ARsyncUp call ARsync('up')
command! ARsyncDown call ARsync('down')
command! ARshowConf call ShowConf()

call AutoSync()

