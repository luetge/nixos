" vim:fdm=marker
set binary
set nocompatible
set autowrite
set wildmenu

" Prevent neovim from changing the cursor
set guicursor=

nnoremap <silent> ga    <cmd>lua vim.lsp.buf.code_action()<CR>

" }}}

" Formatters {{{
let g:formatdef_py_black = '"black -q -"'
let g:formatters_python = ['py_black', 'autopep8']
" }}}

" This and that {{{
set number
set listchars=tab:▸\ ,eol:¬,trail:·,extends:#,nbsp:.

" navigate visual lines instead of real lines
nnoremap j gj
nnoremap k gk

" switch between buffers easily
nmap gh <C-w>h
nmap gj <C-w>j
nmap gk <C-w>k
nmap gl <C-w>l

" switch between tabs easily
nmap <C-l> gt
nmap <C-h> gT

" hide buffers instead closing them
set hidden

set expandtab
set tabstop=2
set shiftwidth=2
set autoindent
set smartindent

" set tw=100
" Set browser window
if has("gui_running")
  set columns=105
endif


" case-insensitive when searching all lowercase
set smartcase
set smarttab
set incsearch

set history=1000
set undolevels=1000
set nobackup
set noswapfile
set nowb
set backspace=indent,eol,start

" Spelling
" set spell spelllang=en
set nospell

" Hide Toolbar
if has("gui_running")
	set guioptions-=T
endif

set ignorecase
set grepprg=grep\ -nH\ $*

" no error bells
set noerrorbells visualbell t_vb=
autocmd GUIEnter * set visualbell t_vb=

" Syntax highlighting
syn on

" Multiline comments
set formatoptions+=r

" Split below by default
set splitbelow

set tags=./tags,tags;$HOME

syntax enable
if (has("nvim"))
  "For Neovim 0.1.3 and 0.1.4 < https://github.com/neovim/neovim/pull/2198 >
  let $NVIM_TUI_ENABLE_TRUE_COLOR=1
endif

if (has("termguicolors"))
  set termguicolors
endif
set background=dark
let g:enable_bold_font = 1
let g:enable_italic_font = 1
let g:hybrid_transparent_background = 1
colorscheme hybrid_material

" set up the stuff for color highlighing in an xterm
" mac os X t_co=16
set t_Co=256

" Terminal title
set title

" Auto reload file on external change
set autoread

" Show the ruler for editing
set ruler

" Turn off the mouse in the xterm
set mouse=

" Show the command in the status line
set showcmd

" Always have a status line
set laststatus=2

" save on losing focus
au FocusLost * :wa

" Delete trailing white spaces on close
"\( ... Start a match group
"$\n .. Match a new line (end-of-line character followed by a carriage return).
"\) ... End the match group
"\+ ... Allow any number of occurrences of this group (one or more).
"\%$ .. Match the end of the file
au BufWritePre,FileWritePre * %s/\s\+$//e | %s/\r$//e | %s#\($\n\)\+\%$##e

" associate *.json with json filetype
au BufRead,BufNewFile *.json set ft=json syntax=javascript

if has('statusline')
    "hi User1 ctermfg=012 ctermbg=016
    "hi User2 ctermfg=172 ctermbg=016
    "hi User3 ctermfg=015 ctermbg=016
    hi User1 ctermfg=012
    hi User2 ctermfg=172
    hi User3 ctermfg=015

    set statusline=\ "                            " start with one space
    set statusline+=%1*                           " use color 1
    set statusline+=\%f                           " file name
    set statusline+=%2*                            " switch back to statusline highlight
    set statusline+=\ %m%r%w%h\                   " flags
    set statusline+=%*                            " switch back to statusline highlight
    set statusline+=%=                            " ident to the right
    set statusline+=%{&fileformat}\               " file format
    set statusline+=%{(&fenc==\"\"?&enc:&fenc)}\  " encoding
    set statusline+=%{strlen(&ft)?&ft:'none'}\    " filetype
    set statusline+=%{((exists(\"+bomb\")\ &&\ &bomb)?\"B,\":\"\")} " BOM
    set statusline+=%3*                           " use color 2
    set statusline+=[%l,%v][%p%%]\                " cursor position/offset
    set statusline+=%*                            " switch back to statusline highlight
endif

" Autoformat
nnoremap <leader>ff :call CocAction('format')<CR>
" Test this to check if autopep8 working
" echo "print 'coração niño'" | autopep8 -
let g:formatdef_autopep8 = '"autopep8 - --aggressive --indent-size 4"'

" Search
vnoremap // y/\V<C-R>=escape(@",'/\')<CR><CR>

" Autocomplete Python
au FileType python set omnifunc=pythoncomplete#Complete

imap <leader><tab> <c-x><c-o>

" Python ident
au FileType python set ts=8 sts=4 et sw=4 smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class

if exists('$TMUX')
    let s:tmux_is_last_pane = 0
    au WinEnter * let s:tmux_is_last_pane = 0

    " Like `wincmd` but also change tmux panes instead of vim windows when needed.
    function s:TmuxWinCmd(direction, tmuxdir)
        let nr = winnr()
        " try to switch windows within vim
        exec 'wincmd ' . a:direction
        " Forward the switch panes command to tmux if:
        " we tried switching windows in vim but it didn't have effect.
        if nr == winnr()
            let cmd = 'tmux select-pane -' . a:tmuxdir
            call system(cmd)
            let s:tmux_is_last_pane = 1
            echo cmd
        else
            let s:tmux_is_last_pane = 0
        endif
    endfunction

    " navigate between split windows/tmux panes
    map <c-h> :call <SID>TmuxWinCmd('h', 'L')<cr>
    nnoremap <c-j> :call <SID>TmuxWinCmd('j', 'D')<cr>
    map <c-k> :call <SID>TmuxWinCmd('k', 'U')<cr>
    map <c-l> :call <SID>TmuxWinCmd('l', 'R')<cr>
else
    nnoremap <C-h> <C-w>h
    nnoremap <C-j> <C-w>j
    nnoremap <C-k> <C-w>k
    nnoremap <C-l> <C-w>l
endif

" enable all syntax highlighting features
let python_highlight_all = 1

" cargo install ripgrep
if executable("rg")
    set grepprg=rg\ --vimgrep\ --no-heading
    set grepformat=%f:%l:%c:%m,%f:%l:%m
endif

nnoremap <c-p> :Files<CR>
nnoremap <leader>p :GFiles<CR>
nnoremap <leader>o :Files ~<CR>
nnoremap <leader>, :Buffers<CR>
nnoremap <leader>h :History<CR>
nnoremap <leader>c :Commits!<CR>

" yaml 2 spaces
autocmd FileType yaml setlocal ts=2 sts=2 sw=2 expandtab


" }}}

" Mappings {{{
" in insert mode press F2 and paste (no indenting,...)
set pastetoggle=<F2>

let mapleader="\\"

" :w!! zum Speichern mit Admin-Rechten
cmap w!! %!sudo tee > /dev/null %

" Edit vimrc
nmap ,v :e ~/.vimrc<CR>

imap jk <Esc>
" }}}

" Font/Encoding {{{
set encoding=utf-8
set fenc=utf-8
if has("gui_gtk3")
  set guifont=M+1Code\ Nerd\ Font\ Mono\ 16
else
  set guifont=M+1Code\ Nerd\ Font\ Mono:h16
end

" }}}


" quick navigation {{{
map ]q :cnext<CR>
map [q :cprev<CR>
nmap <silent> <leader>a <Plug>(coc-diagnostic-next-error)
nmap <silent> <leader>A <Plug>(coc-diagnostic-next)
" }}}

" vimlatex {{{
let g:tex_flavor = 'pdflatex'
nmap <C-space> <Plug>IMAP_JumpForward
vmap <C-space> <Plug>IMAP_JumpForward
" }}}
