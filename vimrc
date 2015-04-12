" Pathogen
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect('bundle/{}', 'custom/{}')

" Vim behavior
set nocompatible
set backupdir^=~/.vim/.bak//
set directory^=~/.vim/.tmp//
set undofile
set undodir=~/.vim/.tmp/
set wildmenu
set wildignore+=*.swp,*~,._*,.DS_Store,tags
set wildignore+=*/.git,*/.cache,*/.bundle,*/vendor/cache,*/.sass-cache
set wildignore+=*.zip,*.tar.gz,*.tar.bz2,*.rar,*.tar.xz

" File (type) and character handling
filetype plugin indent on
set encoding=utf-8
set softtabstop=2
set shiftwidth=2
set expandtab

" Leader and escape bindings
let mapleader = ";"
inoremap jk <ESC>
vnoremap ; <ESC>
nnoremap ' :

" Key sequence completion timeout
set timeoutlen=500

" Visual settings
syntax on
set nowrap
set scrolloff=10
set sidescrolloff=10
set laststatus=2
set visualbell
set noshowmatch
set number
set linespace=2
set list
set listchars=""
set listchars+=extends:>
set listchars+=precedes:<
set guioptions-=L
set guioptions-=r
let NERDTreeShowHidden = 1
let g:NERDTreeRespectWildIgnore = 1
let g:NERDTreeWinSize = 45

" Colorscheme and font settings
colorscheme hybrid
set guifont=Menlo\ for\ Powerline
let g:airline_powerline_fonts = 1

" Search and substitution
set ignorecase
set smartcase
set gdefault
set incsearch
set hlsearch
nnoremap <Leader><Space> :noh<CR>
if executable("ag")
  set grepprg=ag\ --nogroup\ --nocolor
  let g:ctrlp_user_command = 'ag %s -l --nocolor --hidden -g ""'
endif

" Moving lines
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==
inoremap <C-j> <ESC>:m .+1<CR>==gi
inoremap <C-k> <ESC>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

" Motions
nnoremap <Tab> %
vnoremap <Tab> %

" File and window management
nnoremap <Leader>w :w<CR>
nnoremap q :q<CR>
nnoremap qq :qa<CR>
nnoremap <Leader>e :e<Space>
nnoremap <Leader>ww <C-w>w
nnoremap <Leader>wj <C-w>j
nnoremap <Leader>wk <C-w>k
nnoremap <Leader>wh <C-w>h
nnoremap <Leader>wl <C-w>l

" Plugin key bindings
nnoremap <Leader>n :NERDTreeToggle<CR>
nnoremap <Leader>t :TagbarToggle<CR>
nnoremap <Leader>ag :Ag!<Space>

" Source local vimrc
if filereadable($HOME . "/.vimrc.local")
  source ~/.vimrc.local
endif
