" Be more useful (ie. drop Vi compatibility)
set nocompatible

" Setting this first seems to fix non-zero exit status on OS X
filetype on

" Disable all file type detection (for Vundle)
filetype off

" Load up Vundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Let Vundle manage Vundle
Bundle 'gmarik/vundle'

" ******************** Bundles ********************
Bundle 'altercation/vim-colors-solarized'
Bundle 'ervandew/supertab'
Bundle 'kien/ctrlp.vim'
Bundle 'Lokaltog/vim-easymotion'
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'tpope/vim-fugitive'
Bundle 'L9'
Bundle 'surround.vim'

" Enable full file type detection (for Vundle)
filetype plugin indent on

" Use the Solarized colour scheme
colorscheme solarized

" Optimise for dark backgrounds
set background=dark

" Don't expand tabs into spaces
set noexpandtab

" Ignore case in search patterns
set ignorecase

" Always draw a status line
set laststatus=2

" Enable modeline support
set modeline

" Print the line number in front of each line
set number

" Show partial command in the last line of the screen
set showcmd

" Case sensitive search if the pattern has upper case characters
set smartcase

" Do smart autoindenting when starting a new line
set smartindent

" Insert appropriate number of blanks for tab in front of a line
set smarttab

