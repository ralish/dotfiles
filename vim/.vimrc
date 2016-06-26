" Consult the Vim Options Documentation as a reference:
" http://vimhelp.appspot.com/options.txt.html

" ****************************** Initialisation *******************************

" No vi compatibility (i.e. use Vim defaults)
set nocompatible

" Compatibility flags for vi-compatible behaviour
"set cpoptions=aABceFs

" Explicitly set the shell to use for '!' and ':!' commands
"set shell=sh

" Always use UTF-8 character encoding internally
if has('multi_byte')
    set encoding=utf-8
endif


" ******************************** Vundle Init ********************************

" Disable file type detection
if has('autocmd')
    filetype off
endif

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
if has('cmdline_info')
    set showcmd
endif

" Don't display the intro message on startup
set shortmess+=I

" Indicate we're on a fast terminal connection
set ttyfast

" Set the path where the viminfo file is stored
if has('viminfo')
    set viminfo+=n~/dotfiles/vim/.vim/.viminfo
endif

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

" Configure highlighting of the cursor position
if has('syntax')
    " Highlight the screen line of the cursor
    set cursorline

    " Highlight the screen column of the cursor
    "set cursorcolumn
endif

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
    "set relativenumber
endif

" Show the cursor position (note 'statusline' overrides this)
if has('cmdline_info')
    set ruler
endif

" New windows from a horizontal split should be below the current one
if has('windows')
    set splitbelow
endif

" New windows from a vertical split should be right of the current one
if has('vertsplit')
    set splitright
endif


" ********************************** Editing **********************************

" Options to configure automatic formatting
"set formatoptions=tcq

" Modify backspace behaviour to work over additional elements
set backspace=indent,eol,start

" Always report the number of lines changed by commands
set report=0

" When inserting a bracket show the matching one
"set showmatch

" Allow the cursor to be positioned where there's no character in Visual mode
if has('virtualedit')
    set virtualedit=block
endif


" ********************************** Saving ***********************************

" Automatically write changes to a file on certain commands
set autowrite

" Raise a dialog on operations that would otherwise fail
set confirm

" Don't call fsync() after writing to a file (more power efficient)
set nofsync


" ********************************** Folding **********************************

if has('folding')
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
endif


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
if has('smartindent')
    set smartindent
endif


" **************************** Keyword Completion *****************************

" Sources to scan for keyword completion
set complete=.,t

" Infer case for keyword completion (requires 'ignorecase')
"set infercase

" Configure Insert mode completion
if has('insert_expand')
    " Options to configure keyword completion
    set completeopt=longest,menuone,preview

    " Maximum number of items to show in the keyword completion popup
    "set pumheight=0
endif


" ********************************* Scrolling *********************************

" Number of lines to scroll vertically
"set scrolljump=1

" Number of lines to keep above and below the cursor
set scrolloff=2
"
" Number of columns to scroll horizontally (only with 'nowrap')
set sidescroll=1

" Number of columns to keep left and right of the cursor (only with 'nowrap')
"set sidescrolloff=0


" ***************************** Search & Replace ******************************

" Ignore case in search patterns
set ignorecase

" Case sensitive search with upper case characters (only with 'ignorecase')
set smartcase

" Don't wrap searches around the end of the file
"set nowrapscan

" Configure extra search capabilities
if has('extra_search')
    " Highlight matches when searching
    set hlsearch

    " Search incrementally (start matching immediately)
    set incsearch
endif

" Enable the 'g' flag in ':substitute" commands by default
set gdefault


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

" Use the line number column to show wrapped text
"set cpoptions+=n

" Configure line breaking of long lines
if has('linebreak')
    " Wrap long lines at a character in 'breakat'
    set linebreak

    " Characters to line break on when using 'linebreak'
    "let &breakat = ' 	!@*-+;:,./?'

    " String to insert at the start of wrapped lines
    "let &showbreak = '> '
endif


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
if has('wildignore')
    "set backupskip=/tmp/*
endif


" ******************************** Swap Files *********************************

" Enable/disable using a swapfile for the buffer
set swapfile

" Directories to try for reading/writing swap files
set directory^=~/.vim/swap//

" Don't call [f]sync() after writing to a swap file (more power efficient)
set swapsync=


" ******************************** Undo Files *********************************

" Configure persistent undo
if has('persistent_undo')
    " Enable/disable saving of undo history to an undo file
    set undofile

    " Directories to try for reading/writing undo files
    set undodir^=~/.vim/undo//
endif

" Maximum number of changes that can be undone
"set undolevels=1000

" Save the whole buffer for undo when reloading if less than this many lines
"set undoreload=10000


" ******************************** View Files *********************************

if has('mksession')
    " Directory for reading/writing view files
    set viewdir=~/.vim/view

    " List of items to save or restore to/from views
    "set viewoptions=folds,options,cursor
endif


" ****************************** Vundle Plugins *******************************
" ################################ Appearance #################################

" tmux statusline generator
Plugin 'edkolev/tmuxline.vim'
" Support ANSI escape sequences
Plugin 'powerman/vim-plugin-AnsiEsc'
" vim-airline & themes
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'


" ############################## Colour Schemes ###############################

" Solarized
Plugin 'altercation/vim-colors-solarized'
" Tomorrow Theme
"Plugin 'chriskempson/vim-tomorrow-theme'
" Base16
"Plugin 'chriskempson/base16-vim'
" Bad Wolf
"Plugin 'sjl/badwolf'


" ################################ Navigation #################################

" Full path fuzzy finder
Plugin 'ctrlpvim/ctrlp.vim'
" Improved motions handling
Plugin 'easymotion/vim-easymotion'
" Full filesystem explorer
Plugin 'scrooloose/nerdtree'


" ############################### Functionality ###############################

" Improved <Tab> completion
Plugin 'ervandew/supertab'
" Advanced syntax checking
Plugin 'scrooloose/syntastic'
" Powerful Git wrapper
Plugin 'tpope/vim-fugitive'
" Clever code quoting
Plugin 'tpope/vim-surround'


" ################################ Integration ################################

" Support focus events when running under tmux (use our fork until PR#8 merged)
Plugin 'ralish/vim-tmux-focus-events'


" ############################# Language Support ##############################

" Jinja2
Plugin 'Glench/Vim-Jinja2-Syntax'
" Markdown
Plugin 'tpope/vim-markdown'
" PgSQL
Plugin 'exu/pgsql.vim'
" Python
Plugin 'klen/python-mode'
" Salt
Plugin 'saltstack/salt-vim'
" YAML (built-in support is very slow)
Plugin 'stephpy/vim-yaml'


" ****************************** Vundle Finalise ******************************

" Finalise Vundle
call vundle#end()

" Enable file type detection with plugin and indent support
if has('autocmd')
    filetype plugin indent on
endif


" ******************************* Colour Scheme *******************************

" Optimise for dark backgrounds
set background=dark

" Set our preferred colour scheme
try
    colorscheme solarized
catch
    colorscheme default
endtry


" ****************************** Plugin Settings ******************************
" ################################ vim-airline ################################

" Enable Powerline symbols
let g:airline_powerline_fonts=1

" Use the Solarized theme
let g:airline_theme='solarized'


" ################################# NERDTree ##################################

" Shortcut to toggle NERDTree
noremap <C-n> :NERDTreeToggle<CR>

" Open a NERDTree automatically on startup if no files were specified
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif


" ***************************** Language Handling *****************************
" ################################### Jinja ###################################

" Always treat '.jinja' files as Jinja (overrides any modeline)
autocmd BufNewFile,BufWinEnter *.jinja set filetype=jinja


" ################################# Markdown ##################################

" Treat '.md' files as Markdown instead of Modula-2
autocmd BufNewFile,BufReadPost *.md set filetype=markdown

" Enable fenced code block syntax highlighting for these languages
let g:markdown_fenced_languages = ['bash=sh', 'python', 'sh', 'shell=sh']


" ################################### Shell ###################################

" Assume Bash syntax for shell files
autocmd FileType sh let g:is_bash=1

" Bitmask of folding features to enable:
" - 1: Functions
" - 2: Here documents
" - 4: if/do/for statements
autocmd FileType sh let g:sh_fold_enabled=1


" #################################### SQL ####################################

" Make PostgreSQL's SQL dialect the default for '.sql' files
let g:sql_type_default = 'pgsql'


" ******************************* Key Mappings ********************************

" Move by rows instead of lines (much more intuitive with 'wrap')
noremap j gj
noremap k gk
noremap gk k
noremap gj j
noremap <Up> gk
noremap <Down> gj

" Keep the cursor in place when joining lines with 'J'
nnoremap J mzJ`z

" Make 'U' perform a redo operation (a sensible inverse of 'u')
nnoremap U <C-r>

" Make behaviour of 'Y' consistent with 'D' and 'C' (i.e. yank from cursor)
nnoremap Y y$

" Write the file via sudo
cnoremap w!! w !sudo tee % >/dev/null


" ********************************* Finalise **********************************

" Enable syntax highlighting
if has('syntax')
    syntax on
endif

" vim: syntax=vim cc=80 tw=79 ts=4 sw=4 sts=4 et sr
