" Yixiao's Vimrc

" Dependencies: ALE, ruff, pyright

" Activates syntax highlighting
syntax on

" Use file type specific indentation
filetype indent on

" Show line numbers
set number

" Show lin char length
set ruler

" Show line edge (except markdown files)
highlight OverLength ctermbg=red ctermfg=white guibg=#592929

highlight OverLength ctermbg=red ctermfg=white guibg=#592929

function! s:ToggleOverLength()
    if &filetype ==# 'markdown'
        match OverLength /none/
    else
        match OverLength /\%81v.*/
    endif
endfunction

augroup ColumnLimit
    autocmd!
    autocmd BufEnter,WinEnter,FileType * call s:ToggleOverLength()
augroup END

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

" Vim's idle timer
set updatetime=500

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
Plug 'LunarWatcher/auto-pairs'                      " auto (parethesis) completion
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } } " auto update fzf when PlugInstall
Plug 'junegunn/fzf.vim'                             " fuzzy search tool
Plug 'preservim/nerdtree'                           " file tree on the side

call plug#end()
" Vim-plug commands (run in vim)
    " :PlugInstall to install the plugins
    " :PlugUpdate to install or update the plugins
    " :PlugDiff to review the changes from the last update
    " :PlugClean to remove plugins no longer in the list

" Set linters
" install ruff in the venv
let g:ale_linters = {
\    'python':['ruff','pyright'],
\    'java':['javac','checkstyle'],
\}

" Set fixers (currently turned off)
" let g:ale_fixers = {
" \    'python':['ruff_format'],
" \    'java':['google_java_format'],
" \}

" ALE auto fix files on save
" let g:ale_fix_on_save = 1

" Custom ALE highlight groups
highlight ALEError ctermbg=DarkRed guibg=DarkRed
highlight ALEWarning ctermbg=DarkYellow guibg=DarkYellow

" NerdTree configs
" (1) Use <Ctrl-T> to turn on NerdTree
noremap <C-t> :NERDTreeToggle<CR>

" Skeleton file for Java programs
autocmd BufNewFile *.java 0r ~/dotfiles/java.skeleton
" Replace class name with the new file's name
autocmd BufNewFile *.java %s/ClassName/\=expand('%:t:r')/g 
