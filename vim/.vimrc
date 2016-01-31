" Consult the Vim Options Documentation as a reference:
" http://vimdoc.sourceforge.net/htmldoc/options.html

" ****************************** Initialisation *******************************

" No vi compatibility (i.e. use Vim defaults)
set nocompatible

" Compatibility flags for vi-compatible behaviour
"set cpoptions=aABceFs

" Explicitly set the shell to use for '!' and ':!' commands
"set shell=sh

" Always use UTF-8 character encoding internally
set encoding=utf-8


" ******************************** Vundle Init ********************************

" Disable file type detection
filetype off

" Add Vundle to the runtime path
set runtimepath+=~/.vim/bundle/Vundle.vim

" Initialise Vundle
call vundle#begin()

" Let Vundle manage Vundle
Plugin 'VundleVim/Vundle.vim'


" ********************************** General **********************************

" Make Insert mode the default (use Vim like a modeless editor)
"set insertmode

" Number of commands and search patterns to remember
set history=50

" Always show a status line in the last window
set laststatus=2

" Show partial command in the last line of the screen
set showcmd

" Indicate we're on a fast terminal connection
set ttyfast

" Configure mouse support if supported by the terminal
if has('mouse')
    " Enable in all modes
    set mouse=a
    " Configure the model to use (button/action behaviours)
    set mousemodel=popup_setpos
    " Time in which two clicks must occur to be a double-click (msec)
    "set mousetime=500
    " Terminal type for which mouse codes are to be recognised
    set ttymouse=xterm2
endif


" ********************************* Security **********************************

" Use the Blowfish cipher for file encryption
set cryptmethod=blowfish

" Enable parsing of modelines (has security ramifications!)
set modeline

" Block unsafe commands in .vimrc and .exrc files in the current directory
"set secure


" ********************************** Viewing **********************************

" Automatically reread externally modified files if unchanged in Vim
set autoread

" Highlight the screen line of the cursor
set cursorline

" Highlight the screen column of the cursor
"set cursorcolumn

" Don't equalise window sizes on spliting or closing
"set noequalalways

" Show invisible characters as defined in 'listchars'
set list

" Characters to display for the 'list' mode and command
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<

" Configure line numbering based on Vim version
if v:version < 704
    " Enable relative numbering with an easy toggle to absolute numbering
    set relativenumber
    Plugin 'jeffkreeftmeijer/vim-numbertoggle'
else
    " Vim 7.4+ supports absolute and relative numbering at once (hybrid mode)
    set number
    set relativenumber
endif

" Show the cursor position (note 'statusline' overrides this)
set ruler


" ********************************** Editing **********************************

" Options to configure automatic formatting
"set formatoptions=tcq

" Modify backspace behaviour to work over additional elements
set backspace=indent,eol,start

" Always report the number of lines changed by commands
set report=0

" When inserting a bracket show the matching one
set showmatch


" ********************************** Saving ***********************************

" Automatically write changes to a file on certain commands
set autowrite

" Raise a dialog on operations that would otherwise fail
set confirm

" Don't call fsync() after writing to a file (more power efficient)
set nofsync


" ********************************** Folding **********************************

" Folding should be determined by the file syntax
set foldmethod=syntax

" Maximum nesting of folds for 'indent' and 'syntax' methods
set foldnestmax=3

" Initial folding level on opening a new buffer
set foldlevelstart=3

" Display a column with the specified width indicating open and closed folds
"set foldcolumn=1

" Close folds with a level greater than 'foldlevel' when not under the cursor
"set foldclose=all


" ********************************* Indenting *********************************

" Automatically indent new lines to match the previous line
set autoindent

" When autoindenting copy the structure of the previous line
set copyindent

" When changing indentation preserve the existing structure
"set preserveindent

" Round indent operations up to a multiple of 'shiftwidth'
set shiftround

" Number of spaces corresponding to each indent operation
set shiftwidth=4

" Do smart autoindenting when starting a new line
set smartindent


" **************************** Keyword Completion *****************************

" Sources to scan for keyword completion
set complete=.,t

" Options to configure keyword completion
set completeopt=longest,menuone,preview

" Infer case for keyword completion (requires 'ignorecase')
"set infercase

" Maximum number of items to show in the keyword completion popup
"set pumheight=0


" ********************************* Scrolling *********************************

" Number of lines to scroll vertically
"set scrolljump=1

" Number of lines to keep above and below the cursor
set scrolloff=1
"
" Number of columns to scroll horizontally (only with 'nowrap')
set sidescroll=1

" Number of columns to keep left and right of the cursor (only with 'nowrap')
"set sidescrolloff=0


" ***************************** Search & Replace ******************************

" Highlight matches when searching
set hlsearch

" Ignore case in search patterns
set ignorecase

" Search incrementally (start matching immediately)
set incsearch

" Enable the 'g' flag in ':substitute" commands by default
set gdefault

" Case sensitive search with upper case characters (only with 'ignorecase')
set smartcase

" Don't wrap searches around the end of the file
"set nowrapscan


" ******************************** Tabulation *********************************

" Number of spaces that a <Tab> character in a file corresponds to (viewing)
set tabstop=4

" Number of spaces that an inserted <Tab> character corresponds to (editing)
set softtabstop=4

" Expand <Tab> entries into the appropriate number of spaces
set expandtab

" Do smart insertion of <Tab> entries in front of a line
set smarttab


" ********************************* Wrapping **********************************

" Don't display lines longer than the window width on the next line
"set nowrap

" Wrap long lines at a character in 'breakat'
set linebreak

" String to insert at the start of wrapped lines
"let &showbreak = ''


" ******************************* Backup Files ********************************

" Enable/disable saving a backup before overwriting a file
set nobackup

" Directories to try for reading/writing backup files
set backupdir^=~/.vim/backup//

" Method to use for creating backup files
"set backupcopy=auto

" String to append to the original file name for backups
"set backupext=~

" List of file patterns to match for excluding backup creation
"set backupskip=/tmp/*


" ******************************** Swap Files *********************************

" Enable/disable using a swapfile for the buffer
set swapfile

" Directories to try for reading/writing swap files
set directory^=~/.vim/swap//

" Don't call [f]sync() after writing to a swap file (more power efficient)
set swapsync=


" ******************************** Undo Files *********************************

" Enable/disable saving of undo history to an undo file
set undofile

" Directories to try for reading/writing undo files
set undodir^=~/.vim/undo//

" Maximum number of changes that can be undone
"set undolevels=1000

" Save the whole buffer for undo when reloading if less than this many lines
"set undoreload=10000


" ******************************** View Files *********************************

" Directory for reading/writing view files
set viewdir=~/.vim/view

" List of items to save or restore to/from views
"set viewoptions=folds,options,cursor


" ****************************** Vundle Plugins *******************************

Plugin 'L9'
Plugin 'surround.vim'
Plugin 'altercation/vim-colors-solarized'
Plugin 'ervandew/supertab'
Plugin 'exu/pgsql.vim'
Plugin 'Glench/Vim-Jinja2-Syntax'
Plugin 'kien/ctrlp.vim'
Plugin 'Lokaltog/vim-easymotion'
Plugin 'powerman/vim-plugin-AnsiEsc'
Plugin 'saltstack/salt-vim'
Plugin 'scrooloose/nerdtree'
Plugin 'scrooloose/syntastic'
Plugin 'stephpy/vim-yaml'
Plugin 'tpope/vim-fugitive'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'


" ****************************** Vundle Finalise ******************************

" Finalise Vundle
call vundle#end()

" Enable file type detection with plugin and indent support
filetype plugin indent on

" Enable syntax highlighting
syntax on


" ******************************* Colour Scheme *******************************

" Optimise for dark backgrounds
set background=dark

" Set our preferred colour scheme
try
    colorscheme solarized
catch
    colorscheme default
endtry


" vim: syntax=vim cc=80 tw=79 ts=4 sw=4 sts=4 et sr
