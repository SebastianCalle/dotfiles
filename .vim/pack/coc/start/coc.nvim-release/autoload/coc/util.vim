let s:root = expand('<sfile>:h:h:h')
let s:is_win = has('win32') || has('win64')
let s:is_vim = !has('nvim')
let s:clear_match_by_id = has('nvim-0.5.0') || has('patch-8.1.1084')

let s:activate = ""
let s:quit = ""
if has("gui_macvim") && has('gui_running')
  let s:app = "MacVim"
elseif $TERM_PROGRAM ==# "Apple_Terminal"
  let s:app = "Terminal"
elseif $TERM_PROGRAM ==# "iTerm.app"
  let s:app = "iTerm2"
elseif has('mac')
  let s:app = "System Events"
  let s:quit = "quit"
  let s:activate = 'activate'
endif

function! coc#util#has_preview()
  for i in range(1, winnr('$'))
    if getwinvar(i, '&previewwindow')
      return i
    endif
  endfor
  return 0
endfunction

function! coc#util#scroll_preview(dir) abort
  let winnr = coc#util#has_preview()
  if !winnr
    return
  endif
  let winid = win_getid(winnr)
  if exists('*win_execute')
    call win_execute(winid, "normal! ".(a:dir ==# 'up' ? "\<C-u>" : "\<C-d>"))
  else
    let id = win_getid()
    noa call win_gotoid(winid)
    execute "normal! ".(a:dir ==# 'up' ? "\<C-u>" : "\<C-d>")
    noa call win_gotoid(id)
  endif
endfunction

function! coc#util#has_float()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      return 1
    endif
  endfor
  return 0
endfunction

function! coc#util#get_float()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      return win_getid(i)
    endif
  endfor
  return 0
endfunction

function! coc#util#float_hide()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      let winid = win_getid(i)
      call coc#util#close_win(winid)
    endif
  endfor
endfunction

function! coc#util#float_jump()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      exe i.'wincmd w'
      return
    endif
  endfor
endfunction

function! coc#util#float_scrollable()
  let winnr = winnr()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      let wid = win_getid(i)
      let h = nvim_win_get_height(wid)
      let buf = nvim_win_get_buf(wid)
      let lineCount = nvim_buf_line_count(buf)
      return lineCount > h
    endif
  endfor
  return 0
endfunction

function! coc#util#float_scroll(forward)
  let key = a:forward ? "\<C-f>" : "\<C-b>"
  let winnr = winnr()
  for i in range(1, winnr('$'))
    if getwinvar(i, 'float')
      return i."\<C-w>w".key."\<C-w>p"
    endif
  endfor
  return ""
endfunction

" get cursor position
function! coc#util#cursor()
  let pos = getcurpos()
  let content = pos[2] == 1 ? '' : getline('.')[0: pos[2] - 2]
  return [pos[1] - 1, strchars(content)]
endfunction

" close all float/popup window
function! coc#util#close_floats() abort
  if s:is_vim && exists('*popup_clear')
    call popup_clear()
  elseif has('nvim')
    let exists = exists('*nvim_win_get_config')
    for id in nvim_list_wins()
      if exists
        if !empty(nvim_win_get_config(id)['relative'])
          call nvim_win_close(id, 1)
        endif
      else
        if getwinvar(id, 'float', 0)
          call nvim_win_close(id, 1)
        endif
      endif
    endfor
  endif
endfunction

function! coc#util#close_win(id)
  if s:is_vim && exists('*popup_close')
    if !empty(popup_getpos(a:id))
      call popup_close(a:id)
    endif
  endif
  if exists('*nvim_win_close')
    if nvim_win_is_valid(a:id)
      call nvim_win_close(a:id, 1)
    endif
  else
    let winnr = win_id2win(a:id)
    if winnr > 0
      execute winnr.'close!'
    endif
  endif
endfunction

function! coc#util#close(id) abort
  if exists('*nvim_win_close')
    if nvim_win_is_valid(a:id)
      call nvim_win_close(a:id, 1)
    endif
  else
    let winnr = win_id2win(a:id)
    if winnr > 0
      execute winnr.'close!'
    endif
  endif
endfunction

function! coc#util#get_float_mode(allow_selection, align_top, pum_align_top) abort
  let mode = mode()
  if pumvisible() && a:align_top == a:pum_align_top
    return v:null
  endif
  let checked = (mode == 's' && a:allow_selection) || index(['i', 'n', 'ic'], mode) != -1
  if !checked
    return v:null
  endif
  if !s:is_vim && mode ==# 'i'
    " helps to fix undo issue, don't know why.
    call feedkeys("\<C-g>u", 'n')
  endif
  let pos = coc#util#win_position()
  return [mode, bufnr('%'), pos, [line('.'), col('.')]]
endfunction

" create buffer for popup/float window
function! coc#util#create_float_buf(bufnr) abort
  " reuse buffer cause error on vim8
  if a:bufnr && bufloaded(a:bufnr)
    return a:bufnr
  endif
  if s:is_vim
    noa let bufnr = bufadd('')
    noa call bufload(bufnr)
  else
    noa let bufnr = nvim_create_buf(v:false, v:true)
  endif
  " Don't use popup filetype, it would crash on reuse!
  call setbufvar(bufnr, '&buftype', 'nofile')
  call setbufvar(bufnr, '&bufhidden', 'hide')
  call setbufvar(bufnr, '&swapfile', 0)
  call setbufvar(bufnr, '&tabstop', 2)
  call setbufvar(bufnr, '&undolevels', -1)
  return bufnr
endfunction

" create/reuse float window for config position.
function! coc#util#create_float_win(winid, bufnr, config) abort
  " use exists
  if a:winid
    if s:is_vim && !empty(popup_getoptions(a:winid))
      let [line, col] = s:popup_position(a:config)
      call popup_move(a:winid, {
        \ 'line': line,
        \ 'col': col,
        \ 'minwidth': a:config['width'] - 2,
        \ 'minheight': a:config['height'],
        \ 'maxwidth': a:config['width'] - 2,
        \ 'maxheight': a:config['height'],
        \ })
      return [a:winid, winbufnr(a:winid)]
    endif
    if !s:is_vim && nvim_win_is_valid(a:winid)
      call nvim_win_set_config(a:winid, a:config)
      return [a:winid, winbufnr(a:winid)]
    endif
  endif
  let winid = 0
  if s:is_vim
    let [line, col] = s:popup_position(a:config)
    let bufnr = coc#util#create_float_buf(a:bufnr)
    let winid = popup_create(bufnr, {
        \ 'padding': [0, 1, 0, 1],
        \ 'highlight': 'CocFloating',
        \ 'fixed': 1,
        \ 'cursorline': get(a:config, 'cursorline', 0),
        \ 'line': line,
        \ 'col': col,
        \ 'minwidth': a:config['width'] - 2,
        \ 'minheight': a:config['height'],
        \ 'maxwidth': a:config['width'] - 2,
        \ 'maxheight': a:config['height'],
        \ })
    if has("patch-8.1.2281")
      call setwinvar(winid, 'showbreak', 'NONE')
    endif
  else
    let bufnr = coc#util#create_float_buf(a:bufnr)
    let winid = nvim_open_win(bufnr, 0, a:config)
    call setwinvar(winid, '&foldcolumn', 1)
    call setwinvar(winid, '&winhl', 'Normal:CocFloating,NormalNC:CocFloating,FoldColumn:CocFloating,CursorLine:CocMenuSel')
    call setwinvar(winid, '&signcolumn', 'no')
  endif
  if winid <= 0
    return null
  endif
  call setwinvar(winid, '&list', 0)
  call setwinvar(winid, '&number', 0)
  call setwinvar(winid, '&relativenumber', 0)
  call setwinvar(winid, '&cursorcolumn', 0)
  call setwinvar(winid, '&cursorline', 0)
  call setwinvar(winid, '&colorcolumn', 0)
  call setwinvar(winid, 'float', 1)
  call setwinvar(winid, '&wrap', 1)
  call setwinvar(winid, '&linebreak', 1)
  call setwinvar(winid, '&conceallevel', 2)
  let g:coc_last_float_win = winid
  call coc#util#do_autocmd('CocOpenFloat')
  return [winid, winbufnr(winid)]
endfunction

function! coc#util#valid_float_win(winid) abort
  if s:is_vim
    return !empty(popup_getoptions(a:winid))
  endif
  return nvim_win_is_valid(a:winid)
endfunction

function! coc#util#path_replace_patterns() abort
  if has('win32unix') && exists('g:coc_cygqwin_path_prefixes')
    echohl WarningMsg 
    echon 'g:coc_cygqwin_path_prefixes is deprecated, use g:coc_uri_prefix_replace_patterns instead' 
    echohl None
    return g:coc_cygqwin_path_prefixes
  endif
  if exists('g:coc_uri_prefix_replace_patterns')
    return g:coc_uri_prefix_replace_patterns
  endif
  return v:null
endfunction

function! coc#util#win_position()
  let nr = winnr()
  let [row, col] = win_screenpos(nr)
  return [row + winline() - 2, col + wincol() - 2]
endfunction

function! coc#util#version()
  if s:is_vim
    return string(v:versionlong)
  endif
  let c = execute('silent version')
  let lines = split(matchstr(c,  'NVIM v\zs[^\n-]*'))
  return lines[0]
endfunction

function! coc#util#check_refresh(bufnr)
  if !bufloaded(a:bufnr)
    return 0
  endif
  if getbufvar(a:bufnr, 'coc_diagnostic_disable', 0)
    return 0
  endif
  if get(g: , 'EasyMotion_loaded', 0)
    return EasyMotion#is_active() != 1
  endif
  return 1
endfunction

function! coc#util#open_file(cmd, file)
  let file = fnameescape(a:file)
  execute a:cmd .' '.file
endfunction

function! coc#util#platform()
  if s:is_win
    return 'windows'
  endif
  if has('mac') || has('macvim')
    return 'mac'
  endif
  return 'linux'
endfunction

function! coc#util#remote_fns(name)
  let fns = ['init', 'complete', 'should_complete', 'refresh', 'get_startcol', 'on_complete', 'on_enter']
  let res = []
  for fn in fns
    if exists('*coc#source#'.a:name.'#'.fn)
      call add(res, fn)
    endif
  endfor
  return res
endfunction

function! coc#util#job_command()
  if (has_key(g:, 'coc_node_path'))
    let node = expand(g:coc_node_path)
  else
    let node = $COC_NODE_PATH == '' ? 'node' : $COC_NODE_PATH
  endif
  if !executable(node)
    echohl Error | echom '[coc.nvim] "'.node.'" is not executable, checkout https://nodejs.org/en/download/' | echohl None
    return
  endif
  if filereadable(s:root.'/bin/server.js') && filereadable(s:root.'/src/index.ts') && !get(g:, 'coc_force_bundle', 0)
    if !filereadable(s:root.'/lib/attach.js')
      echohl Error | echom '[coc.nvim] javascript bundle not found, please try :call coc#util#install()' | echohl None
      return
    endif
    "use javascript from lib
    return [node] + get(g:, 'coc_node_args', ['--no-warnings']) + [s:root.'/bin/server.js']
  else
    if !filereadable(s:root.'/build/index.js')
      echohl Error | echom '[coc.nvim] build/index.js not found, reinstall coc.nvim to fix it.' | echohl None
      return
    endif
    return [node] + get(g:, 'coc_node_args', ['--no-warnings']) + [s:root.'/build/index.js']
  endif
endfunction

function! coc#util#echo_hover(msg)
  echohl MoreMsg
  echo a:msg
  echohl None
  let g:coc_last_hover_message = a:msg
endfunction

function! coc#util#execute(cmd)
  silent exe a:cmd
  if &filetype ==# ''
    filetype detect
  endif
  if s:is_vim
    redraw!
  endif
endfunction

function! coc#util#jump(cmd, filepath, ...) abort
  silent! normal! m'
  let path = a:filepath
  if (has('win32unix'))
    let path = substitute(a:filepath, '\v\\', '/', 'g')
  endif
  let file = fnamemodify(path, ":~:.")
  exe a:cmd.' '.fnameescape(file)
  if !empty(get(a:, 1, []))
    let line = getline(a:1[0] + 1)
    " TODO need to use utf16 here
    let col = byteidx(line, a:1[1]) + 1
    if col == 0
      let col = 999
    endif
    call cursor(a:1[0] + 1, col)
  endif
  if &filetype ==# ''
    filetype detect
  endif
  if s:is_vim
    redraw
  endif
endfunction

function! coc#util#jumpTo(line, character) abort
  let content = getline(a:line + 1)
  let pre = strcharpart(content, 0, a:character)
  let col = strlen(pre) + 1
  call cursor(a:line + 1, col)
endfunction

function! coc#util#echo_messages(hl, msgs)
  if a:hl !~# 'Error' && (mode() !~# '\v^(i|n)$')
    return
  endif
  let msgs = filter(copy(a:msgs), '!empty(v:val)')
  if empty(msgs)
    return
  endif
  execute 'echohl '.a:hl
  echom a:msgs[0]
  redraw
  echo join(msgs, "\n")
  echohl None
endfunction

function! coc#util#echo_lines(lines)
  echo join(a:lines, "\n")
endfunction

function! coc#util#timer(method, args)
  call timer_start(0, { -> s:Call(a:method, a:args)})
endfunction

function! s:Call(method, args)
  try
    call call(a:method, a:args)
    redraw
  catch /.*/
    return 0
  endtry
endfunction

function! coc#util#is_preview(bufnr)
  let wnr = bufwinnr(a:bufnr)
  if wnr == -1 | return 0 | endif
  return getwinvar(wnr, '&previewwindow')
endfunction

function! coc#util#get_bufoptions(bufnr) abort
  if !bufloaded(a:bufnr) | return v:null | endif
  let bufname = bufname(a:bufnr)
  let buftype = getbufvar(a:bufnr, '&buftype')
  let previewwindow = 0
  let winid = bufwinid(a:bufnr)
  if winid != -1
    let previewwindow = getwinvar(winid, '&previewwindow', 0)
  endif
  let size = -1
  if bufnr('%') == a:bufnr
    let size = line2byte(line("$") + 1)
  elseif !empty(bufname)
    let size = getfsize(bufname)
  endif
  return {
        \ 'bufname': bufname,
        \ 'size': size,
        \ 'eol': getbufvar(a:bufnr, '&eol'),
        \ 'buftype': buftype,
        \ 'winid': winid,
        \ 'previewwindow': previewwindow == 0 ? v:false : v:true,
        \ 'variables': s:variables(a:bufnr),
        \ 'fullpath': empty(bufname) ? '' : fnamemodify(bufname, ':p'),
        \ 'filetype': getbufvar(a:bufnr, '&filetype'),
        \ 'iskeyword': getbufvar(a:bufnr, '&iskeyword'),
        \ 'changedtick': getbufvar(a:bufnr, 'changedtick'),
        \}
endfunction

function! s:variables(bufnr) abort
  let info = getbufinfo({'bufnr':a:bufnr, 'variables': 1})
  let variables = copy(info[0]['variables'])
  for key in keys(variables)
    if key !~# '\v^coc'
      unlet variables[key]
    endif
  endfor
  return variables
endfunction

function! coc#util#root_patterns() abort
  return coc#rpc#request('rootPatterns', [bufnr('%')])
endfunction

function! coc#util#get_config(key) abort
  return coc#rpc#request('getConfig', [a:key])
endfunction

function! coc#util#on_error(msg) abort
  echohl Error | echom '[coc.nvim] '.a:msg | echohl None
endfunction

function! coc#util#preview_info(info, filetype, ...) abort
  pclose
  keepalt new +setlocal\ previewwindow|setlocal\ buftype=nofile|setlocal\ noswapfile|setlocal\ wrap [Document]
  setl bufhidden=wipe
  setl nobuflisted
  setl nospell
  exe 'setl filetype='.a:filetype
  setl conceallevel=2
  setl nofoldenable
  for command in a:000
    execute command
  endfor
  let lines = a:info
  call append(0, lines)
  exe "normal! z" . len(lines) . "\<cr>"
  exe "normal! gg"
  wincmd p
endfunction

function! coc#util#get_config_home()
  if !empty(get(g:, 'coc_config_home', ''))
      return resolve(expand(g:coc_config_home))
  endif
  if exists('$VIMCONFIG')
    return resolve($VIMCONFIG)
  endif
  if has('nvim')
    if exists('$XDG_CONFIG_HOME')
      return resolve($XDG_CONFIG_HOME."/nvim")
    endif
    if s:is_win
      return resolve($HOME.'/AppData/Local/nvim')
    endif
    return resolve($HOME.'/.config/nvim')
  else
    if s:is_win
      return resolve($HOME."/vimfiles")
    endif
    return resolve($HOME.'/.vim')
  endif
endfunction

function! coc#util#get_data_home()
  if !empty(get(g:, 'coc_data_home', ''))
    let dir = resolve(expand(g:coc_data_home))
  else
    if exists('$XDG_CONFIG_HOME')
      let dir = resolve($XDG_CONFIG_HOME."/coc")
    else
      if s:is_win
        let dir = resolve(expand('~/AppData/Local/coc'))
      else
        let dir = resolve(expand('~/.config/coc'))
      endif
    endif
  endif
  if !isdirectory(dir)
    echohl MoreMsg | echom '[coc.nvim] creating data directory: '.dir | echohl None
    call mkdir(dir, "p", 0755)
  endif
  return dir
endfunction

function! coc#util#get_input()
  let pos = getcurpos()
  let line = getline('.')
  let l:start = pos[2] - 1
  while l:start > 0 && line[l:start - 1] =~# '\k'
    let l:start -= 1
  endwhile
  return pos[2] == 1 ? '' : line[l:start : pos[2] - 2]
endfunction

function! coc#util#move_cursor(delta)
  let pos = getcurpos()
  call cursor(pos[1], pos[2] + a:delta)
endfunction

function! coc#util#get_complete_option()
  let disabled = get(b:, 'coc_suggest_disable', 0)
  if disabled | return | endif
  let blacklist = get(b:, 'coc_suggest_blacklist', [])
  let pos = getcurpos()
  let l:start = pos[2] - 1
  let line = getline(pos[1])
  for char in reverse(split(line[0: l:start - 1], '\zs'))
    if l:start > 0 && char =~# '\k'
      let l:start = l:start - strlen(char)
    else
      break
    endif
  endfor
  let input = pos[2] == 1 ? '' : line[l:start : pos[2] - 2]
  if !empty(blacklist) && index(blacklist, input) >= 0
    return
  endif
  let synname = synIDattr(synID(pos[1], l:start, 1),"name")
  return {
        \ 'word': matchstr(line[l:start : ], '^\k\+'),
        \ 'input': empty(input) ? '' : input,
        \ 'line': line,
        \ 'filetype': &filetype,
        \ 'filepath': expand('%:p'),
        \ 'bufnr': bufnr('%'),
        \ 'linenr': pos[1],
        \ 'colnr' : pos[2],
        \ 'col': l:start,
        \ 'synname': synname,
        \ 'changedtick': b:changedtick,
        \ 'blacklist': blacklist,
        \}
endfunction

function! coc#util#with_callback(method, args, cb)
  function! s:Cb() closure
    try
      let res = call(a:method, a:args)
      call a:cb(v:null, res)
    catch /.*/
      call a:cb(v:exception)
    endtry
  endfunction
  let timeout = s:is_vim ? 10 : 0
  call timer_start(timeout, {-> s:Cb() })
endfunction

function! coc#util#quickpick(title, items, cb) abort
  if exists('*popup_menu')
    function! s:QuickpickHandler(id, result) closure
      call a:cb(v:null, a:result)
    endfunction
    function! s:QuickpickFilter(id, key) closure
      for i in range(1, len(a:items))
        if a:key == string(i)
          call popup_close(a:id, i)
          return 1
        endif
      endfor
      " No shortcut, pass to generic filter
      return popup_filter_menu(a:id, a:key)
    endfunction
    try
      call popup_menu(a:items, #{
        \ title: a:title,
        \ filter: function('s:QuickpickFilter'),
        \ callback: function('s:QuickpickHandler'),
        \ })
    catch /.*/
      call a:cb(v:exception)
    endtry
  else
    let res = inputlist([a:title] + a:items)
    call a:cb(v:null, res)
  endif
endfunction

function! coc#util#prompt(title, cb) abort
  if exists('*popup_dialog')
    function! s:PromptHandler(id, result) closure
      call a:cb(v:null, a:result)
    endfunction
    try
      call popup_dialog(a:title. ' (y/n)', #{
        \ filter: 'popup_filter_yesno',
        \ callback: function('s:PromptHandler'),
        \ })
    catch /.*/
      call a:cb(v:exception)
    endtry
  elseif !s:is_vim && exists('*confirm')
    let choice = confirm(a:title, "&Yes\n&No")
    call a:cb(v:null, choice == 1)
  else
    echohl MoreMsg
    echom a:title.' (y/n)'
    echohl None
    let confirm = nr2char(getchar())
    redraw!
    if !(confirm ==? "y" || confirm ==? "\r")
      echohl Moremsg | echo 'Cancelled.' | echohl None
      return 0
      call a:cb(v:null, 0)
    end
    call a:cb(v:null, 1)
  endif
endfunction

function! coc#util#prompt_confirm(title)
  if exists('*confirm') && !s:is_vim
    let choice = confirm(a:title, "&Yes\n&No")
    return choice == 1
  else
    echohl MoreMsg
    echom a:title.' (y/n)'
    echohl None
    let confirm = nr2char(getchar())
    redraw!
    if !(confirm ==? "y" || confirm ==? "\r")
      echohl Moremsg | echo 'Cancelled.' | echohl None
      return 0
    end
    return 1
  endif
endfunction

function! coc#util#get_syntax_name(lnum, col)
  return synIDattr(synIDtrans(synID(a:lnum,a:col,1)),"name")
endfunction

function! coc#util#echo_signatures(signatures) abort
  if pumvisible() | return | endif
  echo ""
  for i in range(len(a:signatures))
    call s:echo_signature(a:signatures[i])
    if i != len(a:signatures) - 1
      echon "\n"
    endif
  endfor
endfunction

function! s:echo_signature(parts)
  for part in a:parts
    let hl = get(part, 'type', 'Normal')
    let text = get(part, 'text', '')
    if !empty(text)
      execute 'echohl '.hl
      execute "echon '".substitute(text, "'", "''", 'g')."'"
      echohl None
    endif
  endfor
endfunction

function! coc#util#unplace_signs(bufnr, sign_ids)
  if !bufloaded(a:bufnr) | return | endif
  for id in a:sign_ids
    execute 'silent! sign unplace '.id.' buffer='.a:bufnr
  endfor
endfunction

function! coc#util#setline(lnum, line)
  keepjumps call setline(a:lnum, a:line)
endfunction

" cmd, cwd
function! coc#util#open_terminal(opts) abort
  if s:is_vim && !exists('*term_start')
    echohl WarningMsg | echon "Your vim doesn't have terminal support!" | echohl None
    return
  endif
  if get(a:opts, 'position', 'bottom') ==# 'bottom'
    let p = '5new'
  else
    let p = 'vnew'
  endif
  execute 'belowright '.p.' +setl\ buftype=nofile '
  setl buftype=nofile
  setl winfixheight
  setl norelativenumber
  setl nonumber
  setl bufhidden=wipe
  let cmd = get(a:opts, 'cmd', '')
  let autoclose = get(a:opts, 'autoclose', 1)
  if empty(cmd)
    throw 'command required!'
  endif
  let cwd = get(a:opts, 'cwd', getcwd())
  let keepfocus = get(a:opts, 'keepfocus', 0)
  let bufnr = bufnr('%')
  let Callback = get(a:opts, 'Callback', v:null)

  function! s:OnExit(status) closure
    let content = join(getbufline(bufnr, 1, '$'), "\n")
    if a:status == 0 && autoclose == 1
      execute 'silent! bd! '.bufnr
    endif
    if !empty(Callback)
      call call(Callback, [a:status, bufnr, content])
    endif
  endfunction

  if has('nvim')
    call termopen(cmd, {
          \ 'cwd': cwd,
          \ 'on_exit': {job, status -> s:OnExit(status)},
          \})
  else
    if s:is_win
      let cmd = 'cmd.exe /C "'.cmd.'"'
    endif
    call term_start(cmd, {
          \ 'cwd': cwd,
          \ 'exit_cb': {job, status -> s:OnExit(status)},
          \ 'curwin': 1,
          \})
  endif
  if keepfocus
    wincmd p
  endif
  return bufnr
endfunction

" run command in terminal
function! coc#util#run_terminal(opts, cb)
  let cmd = get(a:opts, 'cmd', '')
  if empty(cmd)
    return a:cb('command required for terminal')
  endif
  let opts = {
        \ 'cmd': cmd,
        \ 'cwd': get(a:opts, 'cwd', getcwd()),
        \ 'keepfocus': get(a:opts, 'keepfocus', 0),
        \ 'Callback': {status, bufnr, content -> a:cb(v:null, {'success': status == 0 ? v:true : v:false, 'bufnr': bufnr, 'content': content})}
        \}
  call coc#util#open_terminal(opts)
endfunction

function! coc#util#getpid()
  if !has('win32unix')
    return getpid()
  endif

  let cmd = 'cat /proc/' . getpid() . '/winpid'
  return substitute(system(cmd), '\v\n', '', 'gi')
endfunction

function! coc#util#vim_info()
  return {
        \ 'mode': mode(),
        \ 'floating': has('nvim') && exists('*nvim_open_win') ? v:true : v:false,
        \ 'extensionRoot': coc#util#extension_root(),
        \ 'watchExtensions': get(g:, 'coc_watch_extensions', []),
        \ 'globalExtensions': get(g:, 'coc_global_extensions', []),
        \ 'config': get(g:, 'coc_user_config', {}),
        \ 'pid': coc#util#getpid(),
        \ 'columns': &columns,
        \ 'lines': &lines,
        \ 'cmdheight': &cmdheight,
        \ 'filetypeMap': get(g:, 'coc_filetype_map', {}),
        \ 'version': coc#util#version(),
        \ 'completeOpt': &completeopt,
        \ 'pumevent': exists('##MenuPopupChanged') || exists('##CompleteChanged'),
        \ 'isVim': has('nvim') ? v:false : v:true,
        \ 'isCygwin': has('win32unix') ? v:true : v:false,
        \ 'isMacvim': has('gui_macvim') ? v:true : v:false,
        \ 'isiTerm': $TERM_PROGRAM ==# "iTerm.app",
        \ 'colorscheme': get(g:, 'colors_name', ''),
        \ 'workspaceFolders': get(g:, 'WorkspaceFolders', v:null),
        \ 'background': &background,
        \ 'runtimepath': &runtimepath,
        \ 'locationlist': get(g:,'coc_enable_locationlist', 1),
        \ 'progpath': v:progpath,
        \ 'guicursor': &guicursor,
        \ 'vimCommands': get(g:, 'coc_vim_commands', []),
        \ 'textprop': has('textprop') && has('patch-8.1.1719') && !has('nvim') ? v:true : v:false,
        \ 'disabledSources': get(g:, 'coc_sources_disable_map', {}),
        \}
endfunction

function! coc#util#highlight_options()
  return {
        \ 'colorscheme': get(g:, 'colors_name', ''),
        \ 'background': &background,
        \ 'runtimepath': &runtimepath,
        \}
endfunction

" used by vim
function! coc#util#get_content(bufnr)
  if !bufloaded(a:bufnr) | return '' | endif
  return {
        \ 'content': join(getbufline(a:bufnr, 1, '$'), "\n"),
        \ 'changedtick': getbufvar(a:bufnr, 'changedtick')
        \ }
endfunction

" used for TextChangedI with InsertCharPre
function! coc#util#get_changeinfo()
  return {
        \ 'lnum': line('.'),
        \ 'line': getline('.'),
        \ 'changedtick': b:changedtick,
        \}
endfunction

" show diff of current buffer
function! coc#util#diff_content(lines) abort
  let tmpfile = tempname()
  setl foldenable
  call writefile(a:lines, tmpfile)
  let ft = &filetype
  diffthis
  execute 'vs '.tmpfile
  execute 'setf ' . ft
  diffthis
  setl foldenable
endfunction

function! coc#util#clear_signs()
  let buflist = filter(range(1, bufnr('$')), 'buflisted(v:val)')
  for b in buflist
    let signIds = []
    let lines = split(execute('sign place buffer='.b), "\n")
    for line in lines
      let ms = matchlist(line, 'id=\(\d\+\)\s\+name=Coc')
      if len(ms) > 0
        call add(signIds, ms[1])
      endif
    endfor
    call coc#util#unplace_signs(b, signIds)
  endfor
endfunction

function! coc#util#open_url(url)
  if has('mac') && executable('open')
    call system('open '.a:url)
    return
  endif
  if executable('xdg-open')
    call system('xdg-open '.a:url)
    return
  endif
  call system('cmd /c start "" /b '. substitute(a:url, '&', '^&', 'g'))
  if v:shell_error
    echohl Error | echom 'Failed to open '.a:url | echohl None
    return
  endif
endfunction

function! coc#util#install() abort
  call coc#util#open_terminal({
        \ 'cwd': s:root,
        \ 'cmd': 'yarn install --frozen-lockfile',
        \ 'autoclose': 0,
        \ })
endfunction

function! coc#util#do_complete(name, opt, cb) abort
  let handler = 'coc#source#'.a:name.'#complete'
  let l:Cb = {res -> a:cb(v:null, res)}
  let args = [a:opt, l:Cb]
  call call(handler, args)
endfunction

function! coc#util#extension_root() abort
  if get(g:, 'coc_node_env', '') ==# 'test'
    return s:root.'/src/__tests__/extensions'
  endif
  if !empty(get(g:, 'coc_extension_root', ''))
    echohl Error | echon 'g:coc_extension_root not used any more, use g:coc_data_home instead' | echohl None
  endif
  return coc#util#get_data_home().'/extensions'
endfunction

function! coc#util#update_extensions(...) abort
  let async = get(a:, 1, 0)
  if async
    call coc#rpc#notify('updateExtensions', [])
  else
    call coc#rpc#request('updateExtensions', [v:true])
  endif
endfunction

function! coc#util#install_extension(args) abort
  let names = filter(copy(a:args), 'v:val !~# "^-"')
  let isRequest = index(a:args, '-sync') != -1
  if isRequest
    call coc#rpc#request('installExtensions', names)
  else
    call coc#rpc#notify('installExtensions', names)
  endif
endfunction

function! coc#util#do_autocmd(name) abort
  if exists('#User#'.a:name)
    exe 'doautocmd <nomodeline> User '.a:name
  endif
endfunction

function! coc#util#rebuild()
  let dir = coc#util#extension_root()
  if !isdirectory(dir) | return | endif
  call coc#util#open_terminal({
        \ 'cwd': dir,
        \ 'cmd': 'npm rebuild',
        \ 'keepfocus': 1,
        \})
endfunction

" content of first echo line
function! coc#util#echo_line()
  let str = ''
  let line = &lines - (&cmdheight - 1)
  for i in range(1, &columns - 1)
    let nr = screenchar(line, i)
    let str = str . nr2char(nr)
  endfor
  return str
endfunction

" [r, g, b] ['255', '255', '255']
" return ['65535', '65535', '65535'] or return v:false to cancel
function! coc#util#pick_color(default_color)
  if has('mac')
    let default_color = map(a:default_color, {idx, val -> str2nr(val) * 65535 / 255 })
    " This is the AppleScript magic:
    let s:ascrpt = ['-e "tell application \"' . s:app . '\""',
          \ '-e "' . s:activate . '"',
          \ "-e \"set AppleScript's text item delimiters to {\\\",\\\"}\"",
          \ '-e "set theColor to (choose color default color {' . default_color[0] . ", " . default_color[1] . ", " . default_color[2] . '}) as text"',
          \ '-e "' . s:quit . '"',
          \ '-e "end tell"',
          \ '-e "return theColor"']
    let res = trim(system("osascript " . join(s:ascrpt, ' ') . " 2>/dev/null"))
    if empty(res)
      return v:false
    else
      return split(trim(res), ',')
    endif
  endif

  let hex_color = printf('#%02x%02x%02x', a:default_color[0], a:default_color[1], a:default_color[2])

  if has('unix')
    if executable('zenity')
      let res = trim(system('zenity --title="Select a color" --color-selection --color="' . hex_color . '" 2> /dev/null'))
      if empty(res)
        return v:false
      else
        " res format is rgb(255,255,255)
        return map(split(res[4:-2], ','), {idx, val -> string(str2nr(trim(val)) * 65535 / 255)})
      endif
    endif
  endif

  let rgb = v:false
  if !has('python')
    echohl Error | echom 'python support required, checkout :echo has(''python'')' | echohl None
    return
  endif
  try
    execute 'py import gtk'
  catch /.*/
    echohl Error | echom 'python gtk module not found' | echohl None
    return
  endtry
python << endpython

import vim
import gtk, sys

# message strings
wnd_title_insert = "Insert a color"

csd = gtk.ColorSelectionDialog(wnd_title_insert)
cs = csd.colorsel

cs.set_current_color(gtk.gdk.color_parse(vim.eval("hex_color")))

cs.set_current_alpha(65535)
cs.set_has_opacity_control(False)
# cs.set_has_palette(int(vim.eval("s:display_palette")))

if csd.run()==gtk.RESPONSE_OK:
    c = cs.get_current_color()
    s = [str(int(c.red)),',',str(int(c.green)),',',str(int(c.blue))]
    thecolor = ''.join(s)
    vim.command(":let rgb = split('%s',',')" % thecolor)

csd.destroy()

endpython
  return rgb
endfunction

function! coc#util#iterm_open(dir)
  return s:osascript(
      \ 'if application "iTerm2" is not running',
      \   'error',
      \ 'end if') && s:osascript(
      \ 'tell application "iTerm2"',
      \   'tell current window',
      \     'create tab with default profile',
      \     'tell current session',
      \       'write text "cd ' . a:dir . '"',
      \       'write text "clear"',
      \       'activate',
      \     'end tell',
      \   'end tell',
      \ 'end tell')
endfunction

function! s:osascript(...) abort
  let args = join(map(copy(a:000), '" -e ".shellescape(v:val)'), '')
  call  s:system('osascript'. args)
  return !v:shell_error
endfunction

function! s:system(cmd)
  let output = system(a:cmd)
  if v:shell_error && output !=# ""
    echohl Error | echom output | echohl None
    return
  endif
  return output
endfunction

function! coc#util#pclose()
  for i in range(1, winnr('$'))
    if getwinvar(i, '&previewwindow')
      pclose
      redraw
    endif
  endfor
endfunction

function! coc#util#set_buf_var(bufnr, name, val) abort
  if !bufloaded(a:bufnr) | return | endif
  call setbufvar(a:bufnr, a:name, a:val)
endfunction

function! coc#util#change_lines(bufnr, list) abort
  if !bufloaded(a:bufnr) | return | endif
  if exists('*setbufline')
    for [lnum, line] in a:list
      call setbufline(a:bufnr, lnum + 1, line)
    endfor
  elseif a:bufnr == bufnr('%')
    for [lnum, line] in a:list
      call setline(lnum + 1, line)
    endfor
  else
    let bufnr = bufnr('%')
    exe 'noa buffer '.a:bufnr
    for [lnum, line] in a:list
      call setline(lnum + 1, line)
    endfor
    exe 'noa buffer '.bufnr
  endif
endfunction

function! coc#util#unmap(bufnr, keys) abort
  if bufnr('%') == a:bufnr
    for key in a:keys
      exe 'silent! nunmap <buffer> '.key
    endfor
  endif
endfunction

function! coc#util#open_files(files)
  let bufnrs = []
  " added on latest vim8
  if exists('*bufadd') && exists('*bufload')
    for file in a:files
      if bufloaded(file)
        call add(bufnrs, bufnr(file))
      else
        let bufnr = bufadd(file)
        call bufload(file)
        call add(bufnrs, bufnr)
        call setbufvar(bufnr, '&buflisted', 1)
      endif
    endfor
  else
    noa keepalt 1new +setl\ bufhidden=wipe
    for file in a:files
      execute 'noa edit +setl\ bufhidden=hide '.fnameescape(file)
      if &filetype ==# ''
        filetype detect
      endif
      call add(bufnrs, bufnr('%'))
    endfor
    noa close
  endif
  doautocmd BufEnter
  return bufnrs
endfunction

function! coc#util#refactor_foldlevel(lnum) abort
  if a:lnum <= 2 | return 0 | endif
  let line = getline(a:lnum)
  if line =~# '^\%u3000\s*$' | return 0 | endif
  return 1
endfunction

function! coc#util#get_pretext() abort
  return strpart(getline('.'), 0, col('.') - 1)
endfunction

function! coc#util#refactor_fold_text(lnum) abort
  let range = ''
  let info = get(b:line_infos, a:lnum, [])
  if !empty(info)
    let range = info[0].':'.info[1]
  endif
  return trim(getline(a:lnum)[3:]).' '.range
endfunction

" get popup position for vim8 based on config of neovim float window
function! s:popup_position(config) abort
  let relative = get(a:config, 'relative', 'editor')
  if relative ==# 'cursor'
    return [s:popup_cursor(a:config['row']), s:popup_cursor(a:config['col'])]
  endif
  return [a:config['row'] + 1, a:config['col'] + 1]
endfunction

function! s:popup_cursor(n) abort
  if a:n == 0
    return 'cursor'
  endif
  if a:n < 0
    return 'cursor'.a:n
  endif
  return 'cursor+'.a:n
endfunction

function! coc#util#set_buf_lines(bufnr, lines) abort
  let res = setbufline(a:bufnr, 1, a:lines)
  if res == 0
    call deletebufline(a:bufnr, len(a:lines) + 1, '$')
  endif
endfunction

" get tabsize & expandtab option
function! coc#util#get_format_opts(bufnr) abort
  if a:bufnr && bufloaded(a:bufnr)
    let tabsize = getbufvar(a:bufnr, '&shiftwidth')
    if tabsize == 0
      let tabsize = getbufvar(a:bufnr, '&tabstop')
    endif
    return [tabsize, getbufvar(a:bufnr, '&expandtab')]
  endif
  let tabsize = &shiftwidth == 0 ? &tabstop : &shiftwidth
  return [tabsize, &expandtab]
endfunction

function! coc#util#clear_pos_matches(match, ...) abort
  let winid = get(a:, 1, win_getid())
  if empty(getwininfo(winid))
    " not valid
    return
  endif
  if win_getid() == winid
    let arr = filter(getmatches(), 'v:val["group"] =~# "'.a:match.'"')
    for item in arr
      call matchdelete(item['id'])
    endfor
  elseif s:clear_match_by_id
    let arr = filter(getmatches(winid), 'v:val["group"] =~# "'.a:match.'"')
    for item in arr
      call matchdelete(item['id'], winid)
    endfor
  endif
endfunction

function! coc#util#clearmatches(ids, ...)
  let winid = get(a:, 1, win_getid())
  if empty(getwininfo(winid))
    return
  endif
  if win_getid() == winid
    for id in a:ids
      try
        call matchdelete(id)
      catch /.*/
        " matches have been cleared in other ways,
      endtry
    endfor
   elseif s:clear_match_by_id
    for id in a:ids
      try
        call matchdelete(id, winid)
      catch /.*/
        " matches have been cleared in other ways,
      endtry
    endfor
  endif
endfunction

" clear document highlights of current window
function! coc#util#clear_highlights(...) abort
    let winid = get(a:, 1, win_getid())
    if empty(getwininfo(winid))
      " not valid
      return
    endif
    if winid == win_getid()
      let arr = filter(getmatches(), 'v:val["group"] =~# "^CocHighlight"')
      for item in arr
        call matchdelete(item['id'])
      endfor
    elseif s:clear_match_by_id
      let arr = filter(getmatches(winid), 'v:val["group"] =~# "^CocHighlight"')
      for item in arr
        call matchdelete(item['id'], winid)
      endfor
    endif
endfunction

" Create float window for input, works on nvim >= 0.5.0
function! coc#util#create_prompt_win(title, default) abort
  let bufnr = nvim_create_buf(v:false, v:true)
  call setbufvar(bufnr, '&buftype', 'prompt')
  call setbufvar(bufnr, '&bufhidden', 'unload')
  call setbufvar(bufnr, '&undolevels', -1)
  call setbufvar(bufnr, 'coc_suggest_disable', 1)
  " Calculate col
  let curr = win_screenpos(winnr())[1] + wincol() - 2
  let col = curr + 30 < &columns ? 0 : &columns - curr - 31
  if col == 0 && curr >= len(a:title) + 2
    let col = 0 - len(a:title) -2
  endif
  let winid = nvim_open_win(bufnr, 0, {
    \ 'relative': 'cursor',
    \ 'width': 30,
    \ 'height': 1,
    \ 'row': 0,
    \ 'col': col,
    \ 'style': 'minimal',
    \ })
  if !winid
    return 0
  endif
  call setwinvar(winid, '&winhl', 'Normal:CocFloating,NormalNC:CocFloating')
  call win_gotoid(winid)
  call matchaddpos("MoreMsg", [[1, 1, len(a:title) + 2]])
  call prompt_setprompt(bufnr,' '.a:title.': ')
  call prompt_setcallback(bufnr, {text -> coc#rpc#notify('PromptInsert', [text, bufnr])})
  call prompt_setinterrupt(bufnr, { -> execute('bd! '.bufnr, 'silent!')})
  startinsert
  call feedkeys(a:default, 'in')
  return bufnr
endfunction

function! coc#util#win_gotoid(winid) abort
  noa let res = win_gotoid(a:winid)
  if res == 0
    throw 'Invalid window number'
  endif
endfunction
