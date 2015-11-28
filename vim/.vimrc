" Consult the Vim Options Documentation as a reference
" http://vimdoc.sourceforge.net/htmldoc/options.html

" Explicitly use sh
set shell=sh

" Be more useful (ie. drop Vi compatibility)
set nocompatible

" Setting this first seems to fix non-zero exit status on OS X
filetype on

" Disable all file type detection (for Vundle)
filetype off

" Enable mouse usage everywhere (all modes)
if has('mouse')
    set mouse=a
endif

" Store the viminfo file somewhere sensible
if has ('win32')
    set viminfo='100,<50,s10,h,rA:,rB,n$HOME/Development/Personal/dotfiles/vim/.vim/.viminfo
endif

" Load up Vundle
set rtp+=~/.vim/bundle/vundle/
call vundle#rc()

" Let Vundle manage Vundle
Bundle 'gmarik/vundle'

" ******************** Bundles ********************
Bundle 'L9'
Bundle 'surround.vim'
Bundle 'altercation/vim-colors-solarized'
Bundle 'bling/vim-airline'
Bundle 'ervandew/supertab'
Bundle 'exu/pgsql.vim'
Bundle "Glench/Vim-Jinja2-Syntax"
Bundle 'kien/ctrlp.vim'
Bundle 'Lokaltog/vim-easymotion'
Bundle 'powerman/vim-plugin-AnsiEsc'
Bundle "saltstack/salt-vim"
Bundle 'scrooloose/nerdtree'
Bundle 'scrooloose/syntastic'
Bundle 'stephpy/vim-yaml'
Bundle 'tpope/vim-fugitive'

" Enable full file type detection (for Vundle)
filetype plugin indent on

" Set our preferred colour scheme
try
    colorscheme solarized
catch
    colorscheme default
endtry

" Optimise for dark backgrounds
set background=dark

" Allow backspacing over everything in insert mode
set backspace=indent,eol,start

" Don't litter the filesystem with backup files
set nobackup

" Highlight the current line
set cursorline

" Increase the command line history
set history=50

" Ignore case in search patterns
set ignorecase

" Search incrementally (ie. start matching immediately)
set incsearch

" Always draw a status line
set laststatus=2

" Enable modeline support
set modeline

" Setup the line numbering based on Vim version
if v:version < 704
    " Enable relative numbering with a few tweaks in the absence of hybrid mode
    set relativenumber
    Bundle "jeffkreeftmeijer/vim-numbertoggle"
else
    " Vim 7.4+ can enable both absolute/relative numbering at once (hybrid mode)
    set relativenumber
    set number
endif

" Always show the cursor position (line and column number)
set ruler

" Show partial command in the last line of the screen
set showcmd

" Case sensitive search if the pattern has upper case characters
set smartcase

" Do smart autoindenting when starting a new line
set smartindent

" If the terminal has colour support then add some extras
if &t_Co > 2 || has('gui_running')
    " Enable syntax highlighting
    syntax on

    " Highlight matches when searching
    set hlsearch
endif


" {{{ Editing Settings: Tabs }}}

" Number of spaces that a <Tab> in the file counts for
set tabstop=4

" Number of spaces to use for each step of (auto)indent
set shiftwidth=4

" Number of spaces that a <Tab> counts for while editing
set softtabstop=4

" Expand <Tab> entries into the defined number of spaces
set expandtab

" On <Tab> in front of a line insert 'shiftwidth' spaces
set smarttab


" {{{ Editing Settings: Whitespace }}}

" Show invisible characters (eol, tab, etc...)
set list

" Define formatting settings for 'list' mode
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<

" Filetype overrides
autocmd BufNewFile,BufReadPost *.md set filetype=markdown

" vim: syntax=vim ts=4 sw=4 sts=4 et sr
