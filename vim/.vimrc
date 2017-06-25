" Consult the Vim Options Documentation as a reference:
" http://vimhelp.appspot.com/options.txt.html

" ****************************** Initialisation *******************************

" No vi compatibility (i.e. use Vim defaults)
if &compatible
    set nocompatible
endif

" Compatibility flags for vi-compatible behaviour
"set cpoptions=aABceFs

" Explicitly set the shell to use for '!' and ':!' commands
if &shell =~# 'fish$'
    set shell=sh
endif

" Always use UTF-8 character encoding internally
if has('multi_byte')
    set encoding=utf-8
endif


" ******************************* vim-plug Init *******************************

" Directory where vim-plug will store plugins
call plug#begin('~/.vim/plugins')


" ********************************** General **********************************

" Make Insert mode the default (use Vim like a modeless editor)
"set insertmode

" Number of commands and search patterns to remember
set history=1000

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
set secure


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

" Display as much as possible of the last line
set display+=lastline

" Don't equalise window sizes on spliting or closing
"set noequalalways

" Show invisible characters as defined in 'listchars'
set list

" Characters to display for the 'list' mode and command
set listchars=eol:$,tab:>-,trail:~,extends:>,precedes:<,nbsp:+

" Configure line numbering based on Vim version
if v:version < 704
    " Enable relative numbering with an easy toggle to absolute numbering
    set relativenumber
    Plug 'jeffkreeftmeijer/vim-numbertoggle'
else
    " Vim 7.4+ supports absolute and relative numbering at once (hybrid mode)
    set number
    set relativenumber
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

" Remove comment character when joining lines
if v:version > 703 || v:version == 703 && has('patch541')
    set formatoptions+=j
endif

" Modify backspace behaviour to work over additional elements
set backspace=indent,eol,start

" Don't treat numbers starting with a zero as octal
set nrformats-=octal

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
set scrolloff=1
"
" Number of columns to scroll horizontally (only with 'nowrap')
set sidescroll=3

" Number of columns to keep left and right of the cursor (only with 'nowrap')
"set sidescrolloff=3


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

" Time after which nothing is typed to write the swap file (msec)
set updatetime=250


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


" ********************************** Plugins **********************************
" ################################ Appearance #################################

" tmux statusline generator
Plug 'edkolev/tmuxline.vim'

" Support ANSI escape sequences
Plug 'powerman/vim-plugin-AnsiEsc'

" vim-airline & themes
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'


" ############################## Colour Schemes ###############################

" Solarized
Plug 'altercation/vim-colors-solarized'

" Tomorrow Theme
"Plug 'chriskempson/vim-tomorrow-theme'

" Base16
"Plug 'chriskempson/base16-vim'

" Bad Wolf
"Plug 'sjl/badwolf'


" ################################ Navigation #################################

" Full path fuzzy finder
Plug 'ctrlpvim/ctrlp.vim'

" Improved motions handling
Plug 'easymotion/vim-easymotion'

" Full filesystem explorer
Plug 'scrooloose/nerdtree'


" ############################### Functionality ###############################

" Show a Git diff in the gutter
if has('signs')
    Plug 'airblade/vim-gitgutter'
endif

" Improved <Tab> completion
Plug 'ervandew/supertab'

" Advanced syntax checking
Plug 'scrooloose/syntastic'

" Powerful Git wrapper
Plug 'tpope/vim-fugitive'

" Heuristically set buffer options
Plug 'tpope/vim-sleuth'

" Clever code quoting
Plug 'tpope/vim-surround'


" ################################ Integration ################################

" Synchronise with tmux's clipboard
Plug 'roxma/vim-tmux-clipboard'

" Support focus events when running under tmux (use our fork until PR#8 merged)
Plug 'ralish/vim-tmux-focus-events'


" ############################# Language Support ##############################

" Jinja2
Plug 'Glench/Vim-Jinja2-Syntax'

" Markdown
Plug 'tpope/vim-markdown'

" PgSQL
Plug 'exu/pgsql.vim'

" Python
Plug 'klen/python-mode'

" Salt
Plug 'saltstack/salt-vim'

" tmux
Plug 'tmux-plugins/vim-tmux'

" YAML (built-in support is very slow)
Plug 'stephpy/vim-yaml'


" ***************************** vim-plug Finalise *****************************

" Initialise the plugin system
call plug#end()


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
" ################################# nerdtree ##################################

" Shortcut to toggle NERDTree
noremap <C-n> :NERDTreeToggle<CR>

" Open a NERDTree automatically on startup if no files were specified
autocmd StdinReadPre * let s:std_in=1
if exists(':NERDTree')
    autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif
endif


" ################################ python-mode ################################

" Don't automatically run linter on saving changes
let g:pymode_lint_on_write = 0

" Don't automatically regenerate rope project cache on saving changes
let g:pymode_rope_regenerate_on_write = 0


" ################################# syntastic #################################

" Always populate the location-list with detected errors
let g:syntastic_always_populate_loc_list = 1

" Controls the behaviour of the error window (location-list):
" - 0: Don't open or close automatically
" - 1: Automatically open/close when errors are detected/not detected
" - 2: Automatically close when no errors are detected
" - 3: Automatically open when errors are detected
let g:syntastic_auto_loc_list = 1

" Run syntax checks when buffers are first loaded and on saving
let g:syntastic_check_on_open = 1

" Don't run syntax checks when buffers are written due to exiting
let g:syntastic_check_on_wq = 0

" Allow shellcheck to source files not specified on the command line
let g:syntastic_sh_shellcheck_args = '-x'


" ################################ vim-airline ################################

" Enable Powerline symbols
let g:airline_powerline_fonts=1

" Use the Solarized theme
let g:airline_theme='solarized'


" ############################### vim-markdown ################################

" Enable fenced code block syntax highlighting for these languages
let g:markdown_fenced_languages = ['bash=sh', 'python', 'sh', 'shell=sh']


" ***************************** Language Handling *****************************
" ################################### Jinja ###################################

" Disable HTML highlighting as usually we're not editing HTML templates
let g:jinja_syntax_html=0

" Always treat '.jinja' files as Jinja (overrides any modeline)
autocmd BufNewFile,BufWinEnter *.jinja set filetype=jinja


" ################################# Markdown ##################################

" Treat '.md' files as Markdown instead of Modula-2
autocmd BufNewFile,BufReadPost *.md set filetype=markdown


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
noremap <silent> <expr> j (v:count == 0 ? 'gj' : 'j')
noremap <silent> <expr> k (v:count == 0 ? 'gk' : 'k')
noremap <silent> <expr> <Up> (v:count == 0 ? 'gk' : 'k')
noremap <silent> <expr> <Down> (v:count == 0 ? 'gj' : 'j')
noremap gj j
noremap gk k

" Keep the cursor in place when joining lines with 'J'
nnoremap J mzJ`z

" Make 'U' perform a redo operation (a sensible inverse of 'u')
nnoremap U <C-r>

" Make behaviour of 'Y' consistent with 'D' and 'C' (i.e. yank from cursor)
nnoremap Y y$

" Write the file via sudo
cnoremap w!! w !sudo tee % >/dev/null

" vim: syntax=vim cc=80 tw=79 ts=4 sw=4 sts=4 et sr
