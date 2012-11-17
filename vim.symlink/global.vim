" be 'modern'
set nocompatible
syntax on
filetype plugin indent on

" prevent vim from adding that stupid empty line at the end of every file
set noeol
set binary

" presentation settings
set number              " precede each line with its line number
set numberwidth=3       " number of culumns for line numbers
set textwidth=0         " Do not wrap words (insert)
set nowrap              " Do not wrap words (view)
set showcmd             " Show (partial) command in status line.
set showmatch           " Show matching brackets.
set ruler               " line and column number of the cursor position
set wildmenu            " enhanced command completion
set visualbell          " use visual bell instead of beeping
set laststatus=2        " always show the status line

" for MVIM
if has("gui_running")
    set gfn=Bitstream\ Vera\ Sans\ Mono:h13
    set guioptions=egmrt
    set guioptions-=r
endif

colorscheme github

" ULTIMATE AUTOCOMPLETE
"let g:neocomplcache_enable_at_startup = 1
"let g:neocomplcache_min_syntax_length = 4
"let g:neocomplcache_enable_auto_select = 0
"<CR>: close popup and save indent.
"inoremap <expr><CR>  neocomplcache#smart_close_popup() . "\<CR>"
"<TAB>: completion.
"inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"

"let g:SuperTabDefaultCompletionType = "context"
"let g:SuperT
":nnoremap ,z :NERDTree <Bar> :belowright split :TlistOpen<CR>
let Tlist_Use_Horiz_Window = 0
"let Tlist_Use_Right_Window = 1
let Tlist_Compact_Format=1
let Tlist_Enable_Fold_Column=0
let Tlist_GainFocus_On_ToggleOpen = 1
"let Tlist_Show_One_File = 1
let Tlist_Exit_OnlyWindow = 1
let Tlist_Use_SingleClick=1
let Tlist_Display_Tag_Scope = 0

" highlight spell errors
hi SpellErrors guibg=red guifg=black ctermbg=red ctermfg=black

" status line
set statusline=%<%1*%f%*\ %h%m%r%#warningmsg#%{SyntasticStatuslineFlag()}%*%=%-14.(%l,%c%V%)\ %P
" highlihgt status line file name
hi User1 term=bold,reverse cterm=bold ctermfg=4 ctermbg=2 gui=bold guifg=Blue guibg=#44aa00

" behavior
                        " ignore these files when completing names and in
                        " explorer
set wildignore=.svn,CVS,.git,.hg,*.o,*.a,*.class,*.mo,*.la,*.so,*.obj,*.swp,*.jpg,*.png,*.xpm,*.gif
set shell=/bin/bash     " use bash for shell commands
set autowriteall        " Automatically save before commands like :next and :make
set hidden              " enable multiple modified buffers
set history=1000
set autoread            " automatically read feil that has been changed on disk and doesn't have changes in vim
set backspace=indent,eol,start
set guioptions-=T       " disable toolbar"
set completeopt=menuone,preview
let bash_is_sh=1        " syntax shell files as bash scripts
set cinoptions=:0,(s,u0,U1,g0,t0 " some indentation options ':h cinoptions' for details
set modelines=5         " number of lines to check for vim: directives at the start/end of file
"set fixdel                 " fix terminal code for delete (if delete is broken but backspace works)

set ts=4                " number of spaces in a tab
set sw=4                " number of spaces for indent
set et                  " expand tabs into spaces

" mouse settings
if has("mouse")
  set mouse=a
endif
set mousehide                           " Hide mouse pointer on insert mode."

" search settings
set incsearch           " Incremental search
set hlsearch            " Highlight search match
set ignorecase          " Do case insensitive matching
set smartcase           " do not ignore if search pattern has CAPS

" omni completion settings
"set completeopt=longest,menuone
"function InsertTabWrapper()
  "let col = col('.') - 1
  "if !col || getline('.')[col - 1] !~ '\k'
    "return "\<tab>"     
  "else
    "return "\<c-p>"
  "endif
"endfunction
"inoremap <tab> <c-r>=InsertTabWrapper()<cr>

set ofu=syntaxcomplete#Complete
let g:rubycomplete_buffer_loading = 0
let g:rubycomplete_classes_in_global = 1

" directory settings
set backupdir=~/.backup,.       " list of directories for the backup file
set directory=~/.backup,~/tmp,. " list of directory names for the swap file
set nobackup            " do not write backup files
set noswapfile          " do not write .swp files

" folding
set foldcolumn=0        " columns for folding
set foldmethod=syntax
set foldlevelstart=1
"set foldminlines=3
set nofoldenable        "dont fold by default "
" space toggles fold open/close
nnoremap <Space> @=(foldlevel('.')>=2 ? foldclosed('.')>=0 ? 'zA': 'zc' : '1')<CR>

" Set a nicer foldtext function
set foldtext=MyFoldText()
function! MyFoldText()
  let line = getline(v:foldstart)
  if match( line, '^[ \t]*\(\/\*\|\/\/\)[*/\\]*[ \t]*$' ) == 0
    let initial = substitute( line, '^\([ \t]\)*\(\/\*\|\/\/\)\(.*\)', '\1\2', '' )
    let linenum = v:foldstart + 1
    while linenum < v:foldend
      let line = getline( linenum )
      let comment_content = substitute( line, '^\([ \t\/\*]*\)\(.*\)$', '\2', 'g' )
      if comment_content != ''
        break
      endif
      let linenum = linenum + 1
    endwhile
    let sub = initial . ' ' . comment_content
  else
    let sub = line
    let startbrace = substitute( line, '^.*{[ \t]*$', '{', 'g')
    if startbrace == '{'
      let line = getline(v:foldend)
      let endbrace = substitute( line, '^[ \t]*}\(.*\)$', '}', 'g')
      if endbrace == '}'
        let sub = sub.substitute( line, '^[ \t]*}\(.*\)$', '...}\1', 'g')
      endif
    endif
  endif
  let n = v:foldend - v:foldstart + 1
  let info = " " . n . " lines"
  let sub = sub . "                                                                                                                  "
  let num_w = getwinvar( 0, '&number' ) * getwinvar( 0, '&numberwidth' )
  let fold_w = getwinvar( 0, '&foldcolumn' )
  let sub = strpart( sub, 0, winwidth(0) - strlen( info ) - num_w - fold_w - 1 )
  "return sub . info
  return sub
endfunction

function! LoadStartupPlugins()
 "cd ~/git/
 ":TlistOpen
 ":NERDTree
 "wincmd l "give back focus
endf

:au VimEnter * :call LoadStartupPlugins()

" extended '%' mapping for if/then/else/end etc
runtime macros/matchit.vim
