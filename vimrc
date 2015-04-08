" Pathogen
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

" File (type) handling
filetype plugin indent on
set encoding=utf-8

" Visual settings
syntax on
colorscheme hybrid
set guifont=Menlo\ For\ Powerline
let g:airline_powerline_fonts = 1
set laststatus=2
set number

" Core key bindings
let mapleader = ";"
inoremap jk <ESC>
vnoremap ; <ESC>

" Search and substitution
set ignorecase
set smartcase
set gdefault
set incsearch
set showmatch
set hlsearch
nnoremap <Leader><Space> :noh<CR>

" Moving lines
nnoremap <C-j> :m .+1<CR>==
nnoremap <C-k> :m .-2<CR>==
inoremap <C-j> <ESC>:m .+1<CR>==gi
inoremap <C-k> <ESC>:m .-2<CR>==gi
vnoremap <C-j> :m '>+1<CR>gv=gv
vnoremap <C-k> :m '<-2<CR>gv=gv

" Movement
set scrolloff=10
nnoremap <Tab> %
vnoremap <Tab> %

" Plugin key bindings
nnoremap <Leader>tt :TagbarToggle<CR>
