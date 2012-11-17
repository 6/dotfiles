" be 'modern'
set nocompatible
syntax on
filetype plugin indent on

" utf-8/unicode support
" requires Vim to be compiled with Multibyte support, you can check that by
" running `vim --version` and checking for +multi_byte.
if has('multi_byte')
  scriptencoding utf-8
  set encoding=utf-8
end

" presentation settings
set number              " precede each line with its line number
set numberwidth=3       " number of culumns for line numbers
set textwidth=0         " Do not wrap words (insert)
set showcmd             " Show (partial) command in status line.
set showmatch           " Show matching brackets.
set ruler               " line and column number of the cursor position
set wildmenu            " enhanced command completion
set laststatus=2        " always show the status line
hi SpellErrors guibg=red guifg=black ctermbg=red ctermfg=black " highlight spell errors
colorscheme eclipse
" column marker
set colorcolumn=80
hi ColorColumn guibg=#fafafa

" behavior
" ignore these files when completing names and in explorer
set wildignore=.svn,CVS,.git,.hg,*.o,*.a,*.class,*.mo,*.la,*.so,*.obj,*.swp,*.jpg,*.png,*.xpm,*.gif
set shell=/bin/bash     " use bash for shell commands
set autowriteall        " Automatically save before commands like :next and :make
set hidden              " enable multiple modified buffers
set history=1000
set autoread            " automatically read file that has been changed on disk and doesn't have changes in vim
set backspace=indent,eol,start
let bash_is_sh=1        " syntax shell files as bash scripts
set cinoptions=:0,(s,u0,U1,g0,t0 " some indentation options ':h cinoptions' for details
set modelines=5         " number of lines to check for vim: directives at the start/end of file
set autoindent          " automatically indent new line
set ts=2                " number of spaces in a tab
set sw=2                " number of spaces for indent
set et                  " expand tabs into spaces

" search settings
set incsearch           " Incremental search
set hlsearch            " Highlight search match
set ignorecase          " Do case insensitive matching
set smartcase           " do not ignore if search pattern has CAPS

" directory settings
silent !mkdir -vp ~/.backup/undo/ > /dev/null 2>&1
set backupdir=~/.backup,.       " list of directories for the backup file
set directory=~/.backup,~/tmp,. " list of directory names for the swap file
set nobackup            " do not write backup files
set noswapfile          " do not write .swp files
set undofile
set undodir=~/.backup/undo/,~/tmp,.

" folding
set foldcolumn=0        " columns for folding
set foldmethod=syntax
set foldlevelstart=1
set foldminlines=5
set foldnestmax=2
set nofoldenable        "dont fold by default
" space toggles fold open/close
nnoremap <space> za

function! LoadStartupPlugins()
 " TODO?
endf

:au VimEnter * :call LoadStartupPlugins()

" extended '%' mapping for if/then/else/end etc
runtime macros/matchit.vim

let mapleader = ","
let maplocalleader = "\\"
