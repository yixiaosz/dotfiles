" Yixiao's Vimrc

" Dependencies: ALE, ruff, pyright

" Activates syntax highlighting
syntax on

" Use file type specific indentation
filetype indent on

" Show line numbers
set number

" Highlight search results
set hlsearch
" Enable incremental search (searches as you type)
set incsearch
" Ignore case when searching, unless a capital letter is used
set ignorecase
set smartcase

" Set the width of a tab to 4 spaces
set tabstop=4
" Set the width of a soft tab to 4 spaces
set softtabstop=4
" Number of spaces to use for each step of (auto)indent
set shiftwidth=4
" Use spaces instead of tabs
set expandtab

" Key remap
" (1) Quickly move cursor between Vim windows
noremap <c-h> <c-w><c-h>
noremap <c-j> <c-w><c-j>
noremap <c-k> <c-w><c-k>
noremap <c-l> <c-w><c-l>

" Vim-plug
call plug#begin()

" List your plugins here
" Plug 'tpope/vim-sensible'
Plug 'dense-analysis/ale'                           " async lint engine: controls lintes & fixers
" Plug 'LunarWatcher/auto-pairs'                      " auto (parethesis) completion
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " auto update fzf when PlugInstall
Plug 'junegunn/fzf.vim'                             " fuzzy search tool
Plug 'preservim/nerdtree'                           " file tree on the side

call plug#end()
" Vim-plug commands (run in vim)
    " :PlugInstall to install the plugins
    " :PlugUpdate to install or update the plugins
    " :PlugDiff to review the changes from the last update
    " :PlugClean to remove plugins no longer in the list

" Enable ALE for Python
let g:ale_python_auto_enabled = 1

" Set Ruff as the linter 
" install ruff in the venv
let g:ale_linters = {'python':['ruff','pyright']}

" Set Ruff as the formatter 
" Ruff will format the code on save
" let g:ale_fixers = {'python':['ruff_format']}

" ALE auto fix files on save
let g:ale_fix_on_save = 1

" Enable ALE hover
let g:ale_hover_cursor = 1
set updatetime=500

" Custom ALE highlight groups
highlight ALEError ctermbg=DarkRed guibg=DarkRed
highlight ALEWarning ctermbg=DarkYellow guibg=DarkYellow

" NerdTree configs
" (1) Use <Ctrl-T> to turn on NerdTree
noremap <C-t> :NERDTreeToggle<CR>
