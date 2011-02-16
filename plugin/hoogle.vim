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

if !exists("g:hoogle_search_count")
    let g:hoogle_search_count = 10
endif

if !exists("g:hoogle_search_buf_name")
    let g:hoogle_search_buf_name = 'HoogleSearch'
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
    setlocal statusline=%F
    setlocal nofoldenable
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

" Open a scratch buffer or reuse the previous one
fun! HoogleLookup( search ) "{{{
    " Ok, previous buffer to jump to it at final
    let last_buffer = bufnr("%")

    if s:HoogleGotoWin() < 0
        new
        exe 'file ' . g:hoogle_search_buf_name
        setl modifiable
    else
        setl modifiable
        normal ggVGd
    endif

    call s:ScratchMarkBuffer()

    execute '.!hoogle -n=' . g:hoogle_search_count  . ' "' . a:search . '"'
    setl nomodifiable
    
    execute 'resize ' . line( '$' )

    let win_num = bufwinnr( last_buffer )
    " We must get a real window number, or
    " else the buffer would have been deleted
    " already
    exe win_num . "wincmd w"
endfunction "}}}

" Search the current line and delete it
fun! HoogleSearchLine() "{{{
    let search = getline( '.' )
    normal dd
    call HoogleLookup( search )
endfunction "}}}

command! -nargs=* Hoogle call HoogleLookup( '<args>' )
command! HoogleClose call HoogleCloseSearch()
command! HoogleLine call HoogleSearchLine()

