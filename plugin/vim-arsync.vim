" Vim plugin to handle async rsync synchronisation between hosts
" Title: vim-arsync
" Author: Ken Hasselmann
" Date: 08/2019
" License: MIT

function! LoadConf()
    let l:conf_dict = {}
    let l:config_file = findfile('.vim-arsync', '.,,;')

    if strlen(l:config_file) > 0
        let l:conf_options = readfile(l:config_file)
        for i in l:conf_options
            let l:var_name = substitute(i[0:stridx(i, ' ')], '^\s*\(.\{-}\)\s*$', '\1', '')
            if l:var_name == 'ignore_path'
                let l:var_value = eval(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''))
                " echo substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', '')
            else
                let l:var_value = escape(substitute(i[stridx(i, ' '):], '^\s*\(.\{-}\)\s*$', '\1', ''), '%#!')
            endif
            let l:conf_dict[l:var_name] = l:var_value
        endfor
    endif
    if !has_key(l:conf_dict, "local_path")
        " echom fnamemodify(l:config_file,':p:h')
        let l:conf_dict['local_path'] = fnamemodify(l:config_file,':p:h')
    endif
    if !has_key(l:conf_dict, "remote_port")
        let l:conf_dict['remote_port'] = 22
    endif
    if !has_key(l:conf_dict, "remote_or_local")
        let l:conf_dict['remote_or_local'] = "remote"
    endif
    return l:conf_dict
endfunction

function! JobHandler(job_id, data, event_type)
    " redraw | echom a:job_id . ' ' . a:event_type
    if a:event_type == 'stdout' || a:event_type == 'stderr'
        " redraw | echom string(a:data)
        if has_key(getqflist({'id' : g:qfid}), 'id')
            call setqflist([], 'a', {'id' : g:qfid, 'lines' : a:data})
        endif
    elseif a:event_type == 'exit'
        if a:data != 0
            copen
        endif
        if a:data == 0
            echo "vim-arsync success."
        endif
        " echom string(a:data)
    endif
endfunction

function! ShowConf()
    let l:conf_dict = LoadConf()
    echo l:conf_dict
    echom string(getqflist())
endfunction

function! ARsync(direction)
    let l:conf_dict = LoadConf()
    if has_key(l:conf_dict, 'remote_host')
        let l:user_passwd = ''
        if has_key(l:conf_dict, 'remote_user')
            let l:user_passwd = l:conf_dict['remote_user'] . '@'
            if has_key(l:conf_dict, 'remote_passwd')
                if !executable('sshpass')
                    echoerr 'You need to install sshpass to use plain text password, otherwise please use ssh-key auth.'
                    return
                endif
                let sshpass_passwd = l:conf_dict['remote_passwd']
            endif
        endif

        if has_key(l:conf_dict, "sleep_before_sync")
            exe 'sleep '.l:conf_dict['sleep_before_sync']
        endif

        if l:conf_dict['remote_or_local'] == 'remote'
            if a:direction == 'down'
                let l:cmd = [ 'rsync', '-vare', 'ssh -p '.l:conf_dict['remote_port'], l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/', l:conf_dict['local_path'] . '/']
            elseif  a:direction == 'up'
                let l:cmd = [ 'rsync', '-vazre', 'ssh -p '.l:conf_dict['remote_port'], l:conf_dict['local_path'] . '/', l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/']
            else " updelete
                let l:cmd = [ 'rsync', '-vazre', 'ssh -p '.l:conf_dict['remote_port'], l:conf_dict['local_path'] . '/', l:user_passwd . l:conf_dict['remote_host'] . ':' . l:conf_dict['remote_path'] . '/', '--delete']
            endif
        elseif l:conf_dict['remote_or_local'] == 'local'
            if a:direction == 'down'
                let l:cmd = [ 'rsync', '-var',  l:conf_dict['remote_path'] , l:conf_dict['local_path']]
            elseif  a:direction == 'up'
                let l:cmd = [ 'rsync', '-var',  l:conf_dict['local_path'] , l:conf_dict['remote_path']]
            else " updelete
                let l:cmd = [ 'rsync', '-var',  l:conf_dict['local_path'] , l:conf_dict['remote_path'] . '/', '--delete']
            endif
        endif
        if has_key(l:conf_dict, 'ignore_path')
            for file in l:conf_dict['ignore_path']
                let l:cmd = l:cmd + ['--exclude', file]
            endfor
        endif
        if has_key(l:conf_dict, 'ignore_dotfiles')
            if l:conf_dict['ignore_dotfiles'] == 1
                let l:cmd = l:cmd + ['--exclude', '.*']
            endif
        endif
        if has_key(l:conf_dict, 'remote_passwd')
            let l:cmd = ['sshpass', '-p', sshpass_passwd] + l:cmd
        endif

        " create qf for job
        call setqflist([], ' ', {'title' : 'vim-arsync'})
        let g:qfid = getqflist({'id' : 0}).id
        " redraw | echom join(cmd)
        let l:job_id = arsync#job#start(cmd, {
                    \ 'on_stdout': function('JobHandler'),
                    \ 'on_stderr': function('JobHandler'),
                    \ 'on_exit': function('JobHandler'),
                    \ })
        " TODO: handle errors
    else
        echoerr 'Could not locate a .vim-arsync configuration file. Aborting...'
    endif
endfunction

function! AutoSync()
    let l:conf_dict = LoadConf()
    if has_key(l:conf_dict, 'auto_sync_up')
        if l:conf_dict['auto_sync_up'] == 1
            autocmd BufWritePost,FileWritePost * ARsyncUp
            " echo 'Setting up auto sync to remote'
        endif
    endif
endfunction

if !executable('rsync')
    echoerr 'You need to install rsync to be able to use the vim-arsync plugin'
    finish
endif

command! ARsyncUp call ARsync('up')
command! ARsyncUpDelete call ARsync('upDelete')
command! ARsyncDown call ARsync('down')
command! ARshowConf call ShowConf()

autocmd VimEnter * call AutoSync()
