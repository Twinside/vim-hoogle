"=============================================================================
" What Is This: Perform a search on local hoogle and display the results on
"               a scratch buffer.
" File: hoogle.vim
" Author: Vincent B <twinside@gmail.com>
" Last Change: 2011 fb. 16
" Version: 1.3
" Thanks:
" ChangeLog:
"       1.3: Updated to the latest hoogle version, adding proper documenation
"       1.2: removed folding for the window.
"       1.1: resize un function of line count.
"       1.0: initial version.
if exists("g:__HOOGLE_VIM__")
    finish
endif
let g:__HOOGLE_VIM__ = 1

if !exists("g:hoogle_search_bin")
    let g:hoogle_search_bin = 'hoogle'
endif

if !exists("g:hoogle_search_count")
    let g:hoogle_search_count = 10
endif

if !exists("g:hoogle_search_buf_name")
    let g:hoogle_search_buf_name = 'HoogleSearch'
endif

if !exists("g:hoogle_search_buf_size")
    let g:hoogle_search_buf_size = 10
endif

if !exists("g:hoogle_search_jump_back")
    let g:hoogle_search_jump_back = 1
endif

if !exists("g:hoogle_search_databases")
    let g:hoogle_search_databases = ''
endif

" ScratchMarkBuffer
" Mark a buffer as scratch
function! s:ScratchMarkBuffer()
    setlocal buftype=nofile
    " make sure buffer is deleted when view is closed
    setlocal bufhidden=wipe
    setlocal noswapfile
    setlocal buflisted
    setlocal nonumber
    setlocal norelativenumber
    setlocal statusline=%F
    setlocal nofoldenable
    setlocal foldcolumn=0
    setlocal wrap
    setlocal linebreak
    setlocal nolist
endfunction

" Return the number of visual lines in the buffer
fun! s:CountVisualLines()
    let initcursor = getpos(".")
    call cursor(1,1)
    let i = 0
    let previouspos = [-1,-1,-1,-1]
    " keep moving cursor down one visual line until it stops moving position
    while previouspos != getpos(".")
        let i += 1
        " store current cursor position BEFORE moving cursor
        let previouspos = getpos(".")
        normal! gj
    endwhile
    " restore cursor position
    call setpos(".", initcursor)
    return i
endfunction

" return -1 if no windows was open
"        >= 0 if cursor is now in the window
fun! s:HoogleGotoWin() "{{{
    let bufnum = bufnr( g:hoogle_search_buf_name )
    if bufnum >= 0
        let win_num = bufwinnr( bufnum )
        " We must get a real window number, or
        " else the buffer would have been deleted
        " already
        exe win_num . "wincmd w"
        return 0
    endif
    return -1
endfunction "}}}

" Close hoogle search
fun! HoogleCloseSearch() "{{{
    let last_buffer = bufnr("%")
    if s:HoogleGotoWin() >= 0
        close
    endif
    let win_num = bufwinnr( last_buffer )
    " We must get a real window number, or
    " else the buffer would have been deleted
    " already
    exe win_num . "wincmd w"
endfunction "}}}

fun! s:GetFullWord()
  let line = getline('.')
  let line_n = line('.')

  let start = max([0, searchpos('\s', 'bcn', line_n)[1]])
  let end = searchpos('\s', 'cn', line_n)[1]

  if !end
    let end = searchpos('[\n|\r]', 'cn', line('.'))[1]
  endif

  return strpart(line, start, end - start)
endfunction

" Open a scratch buffer or reuse the previous one
fun! HoogleLookup( search, args ) "{{{
    " Ok, previous buffer to jump to it at final
    let last_buffer = bufnr("%")

    if strlen(a:search) == 0
      try
        let s:search = s:GetFullWord()
      catch
        " Fallback to <cword> expansion if the word can't be get otherwise.
        let s:search = expand("<cword>")
      endtry
    else
        let s:search = a:search
    endif

    if strlen(g:hoogle_search_databases) == 0
	let s:databases = ''
    else
	let s:databases = ' --databases="' . g:hoogle_search_databases . '"'
    endif

    if s:HoogleGotoWin() < 0
        new
        exe 'file ' . g:hoogle_search_buf_name
        setl modifiable
    else
        setl modifiable
        normal ggVGd
    endif

    call s:ScratchMarkBuffer()

    execute '.!' . g:hoogle_search_bin . ' -n=' . g:hoogle_search_count  . ' "' . s:search . '"' . s:databases . a:args
    setl nomodifiable
    
    let size = s:CountVisualLines()

    if size > g:hoogle_search_buf_size
        let size = g:hoogle_search_buf_size
    endif

    execute 'resize ' . size

    nnoremap <silent> <buffer> <cr> <esc>:call HoogleLineJump()<cr>
    nnoremap <silent> <buffer> gx <esc>:call HoogleFollowLink()<cr>
    nnoremap <silent> <buffer> q <esc>:close<cr>
    let b:hoogle_search = a:search

    if g:hoogle_search_jump_back == 1
      let win_num = bufwinnr( last_buffer )
      " We must get a real window number, or
      " else the buffer would have been deleted
      " already
      exe win_num . "wincmd w"
    endif
endfunction "}}}

" Search the current line and delete it
fun! HoogleSearchLine() "{{{
    let search = getline( '.' )
    normal dd
    call HoogleLookup( search )
endfunction "}}}

fun! HoogleLineJump() "{{{
  if exists('b:hoogle_search') == 0
    return
  endif
  let l:search = s:getSearch()
  if l:search !=? ''
      let b:hoogle_search = l:search
      let b:infoLink = s:getLinkFromSearch(b:hoogle_search)
      call HoogleLookup( b:hoogle_search, ' --info' )
  else
      return
  endif
  unlet b:hoogle_search
endfunction "}}}

fun! s:getSearch()
  let l:cur_line = getline('.')
  if len(l:cur_line) >= 2
      let l:split_line = split(l:cur_line)
      return l:split_line[0] . '.' . l:split_line[1]       " since results are given in the format `Data.IntMap.Strict lookup :: Key -> IntMap a -> Maybe a`
                                                           " this results in a search of `Data.IntMap.Strict.lookup`
  endif
  return ''
endfunction

fun! HoogleFollowLink() "{{{
  if !exists('b:hoogle_search') && exists('b:infoLink')    " In the info window
    call netrw#BrowseX(b:infoLink, 0)
    return
  else
    call netrw#BrowseX(s:getLinkFromSearch(s:getSearch()), 0) " In the results window
  endif
endfunction "}}}

fun! s:getLinkFromSearch(search)

  if strlen(g:hoogle_search_databases) == 0
    let s:databases = ''
  else
    let s:databases = ' --databases="' . g:hoogle_search_databases . '"'
  endif

  let l:res = systemlist(g:hoogle_search_bin . ' -n=1 --link ' . '"' . a:search . '"' . s:databases)
  let l:line = l:res[0]
  if len(l:line) >= 2
    let l:split_line = split(l:line, ' -- ')
    if len(l:split_line) >= 2
      let s:link = l:split_line[1]
      return s:link
    endif
  endif
  return ''
endfunction

command! -nargs=* Hoogle call HoogleLookup( '<args>', '' )
command! -nargs=* HoogleInfo call HoogleLookup( '<args>', ' --info')
command! HoogleClose call HoogleCloseSearch()
command! HoogleLine call HoogleSearchLine()

