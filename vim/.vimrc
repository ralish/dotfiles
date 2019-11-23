" Consult the Vim Options Documentation as a reference:
" http://vimhelp.appspot.com/options.txt.html

" ****************************** Initialisation *******************************

" No vi compatibility (i.e. use Vim defaults)
if &compatible
    set nocompatible
endif

" The above set command will be skipped if the +eval feature is missing, which
" is the case in some minimal versions of Vim (e.g. vim.tiny). The trick below
" will thus reset compatible *only* if the +eval feature is missing. Borrowed
" from the defaults.vim introduced in Vim 8.
silent! while 0
    set nocompatible
silent! endwhile

" Compatibility flags for vi-compatible behaviour
"set cpoptions=aABceFs

" Use the Bash shell instead of fish on older Vim releases
if &shell =~# 'fish$' && (v:version < 704 ||
                         \v:version == 704 && !has('patch276'))
    set shell=/bin/bash
endif

if has('multi_byte')
    " Always use UTF-8 character encoding internally
    set encoding=utf-8
endif

if has('viminfo')
    " Save and restore uppercase global variables
    set viminfo^=!

    " Set the path where the viminfo file is stored
    set viminfo+=n~/dotfiles/vim/.vim/.viminfo
endif


" ********************************** General **********************************

" Optimise colours for dark backgrounds
set background=dark

" Modify backspace behaviour to work over additional elements
set backspace=indent,eol,start

" Display as much as possible of the last line and terminate with '@@@'
set display+=lastline

" Number of commands and search patterns to remember
set history=1000

" Always show a status line in the last window
set laststatus=2

" Show invisible characters as defined in 'listchars'
set list

" Characters to display when 'list' mode is enabled
set listchars=tab:>-,trail:~,extends:>,precedes:<,nbsp:+

" Don't display the intro message on startup
set shortmess+=I

" Maximum line length to perform syntax highlighting on
set synmaxcol=250

" Enable time outs on key codes
set ttimeout

" Time out for key codes (msec)
set ttimeoutlen=100

" Indicate we're on a fast terminal connection
set ttyfast

if has('cmdline_info')
    " Show the cursor position (only if 'statusline' is not defined)
    set ruler

    " Show partial command in the last line of the screen
    set showcmd
endif

if has('langmap') && exists('+langremap')
    " Don't apply 'langmap' to characters resulting from a mapping
    set nolangremap
endif

if has('syntax')
    " Highlight the screen line of the cursor
    set cursorline

    " Highlight the screen column of the cursor
    "set cursorcolumn
endif

if has('wildmenu')
    " Enable menu to resolve ambiguous command completions
    set wildmenu

    " Ignore case when completing file names and directories
    set wildignorecase
endif

" Enable absolute and relative numbering at once (hybrid mode)
if v:version > 703 || v:version == 703 && has('patch1115')
    set number
    set relativenumber
endif


" ********************************* Security **********************************

" Use the Blowfish cipher for file encryption
set cryptmethod=blowfish

" Enable parsing of modelines (has security implications!)
set modeline

" Block unsafe commands in .vimrc and .exrc files in the current directory
set secure


" ********************************** Viewing **********************************

" Automatically reread externally modified files if unchanged in Vim
set autoread

if has('virtualedit')
    " Allow virtual editing in Visual block mode
    set virtualedit=block
endif


" ********************************** Editing **********************************

" Insert a comment on <Enter> in Insert mode if in a comment
"set formatoptions+=r

" Insert a comment on 'o' or 'O' in Normal mode if in a comment
"set formatoptions+=o

" Make Insert mode the default (use Vim more like a modeless editor)
"set insertmode

" Don't treat numbers starting with a zero as octal
set nrformats-=octal

" Always report the number of lines changed by commands
set report=0

" When inserting a bracket show the matching one
"set showmatch

" Remove any comment character when joining lines
if v:version > 703 || v:version == 703 && has('patch541')
    set formatoptions+=j
endif


" ********************************** Saving ***********************************

" Automatically write changes to a file on certain commands
set autowrite

" Raise a dialogue on operations that would otherwise fail
set confirm

" Don't call fsync() after writing to a file (more power efficient)
set nofsync


" ********************************** Folding **********************************

if has('folding')
    " Initial folding level on opening a new buffer
    set foldlevelstart=3

    " Folding should be determined by the file syntax
    set foldmethod=syntax

    " Maximum nesting of folds for 'indent' and 'syntax' methods
    set foldnestmax=3

    " Close fold levels greater than 'foldlevel' when not under the cursor
    "set foldclose=all

    " Display a column with the given width indicating open and closed folds
    "set foldcolumn=1
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

if has('smartindent')
    " Do smart autoindenting when starting a new line
    set smartindent
endif


" **************************** Keyword Completion *****************************

" Sources to scan for keyword completion
set complete=.,t

" Infer case for keyword completion (only with 'ignorecase')
set infercase

if has('insert_expand')
    " Options to configure keyword completion
    set completeopt=longest,menuone,preview

    " Maximum number of items to show in the keyword completion pop-up
    "set pumheight=0
endif

if has('spell')
    " Use spell checking dictionaries in keyword completion
    set complete+=kspell
endif


" ******************************* Mouse Support *******************************

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

" Enable the 'g' flag in ':substitute' commands by default
set gdefault

" Ignore case in search patterns
set ignorecase

" Case sensitive search with upper case characters (only with 'ignorecase')
set smartcase

" Don't wrap searches around the end of the file
"set nowrapscan

if has('extra_search')
    " Highlight matches when searching
    set hlsearch

    " Search incrementally (i.e. start matching immediately)
    set incsearch
endif


" ****************************** Spell Checking *******************************

if has('syntax')
    " Word list names to use for spell checking
    set spelllang=en_au,en_gb
endif


" ******************************** Tabulation *********************************

" Number of spaces that a <Tab> character in a file corresponds to (viewing)
set tabstop=4

" Number of spaces that an inserted <Tab> character corresponds to (editing)
set softtabstop=4

" Expand <Tab> entries into the appropriate number of spaces
set expandtab

" Do smart insertion of <Tab> entries in front of a line
set smarttab


" ***************************** Window Splitting ******************************

" Don't equalise window sizes on splitting or closing
"set noequalalways

if has('vertsplit')
    " New windows from a vertical split should be right of the current one
    set splitright
endif

if has('windows')
    " New windows from a horizontal split should be below the current one
    set splitbelow

    " Increase the number of tab pages which can be opened
    set tabpagemax=50
endif


" ********************************* Wrapping **********************************

" Don't display lines longer than the window width on the next line
set nowrap

" Use the line number column to show wrapped text
"set cpoptions+=n

if has('linebreak')
    " Wrap long lines at a character in 'breakat'
    set linebreak

    " Characters to line break on when using 'linebreak'
    "let &breakat = ' 	!@*-+;:,./?'

    " String to insert at the start of wrapped lines
    let &showbreak = '> '

    if exists('+breakindent')
        " Preserve indentation when wrapping lines
        set breakindent

        " With 'breakindent' wrapping is reasonable
        set wrap
    endif
endif


" ******************************* Backup Files ********************************

" Disable saving a backup before overwriting a file
set nobackup

" Directories to try for reading/writing backup files
set backupdir^=~/.vim/backup//

" Method to use for creating backup files
"set backupcopy=auto

" String to append to the original file name for backups
"set backupext=~

if has('wildignore')
    " List of file patterns to match for excluding backup creation
    "set backupskip=/tmp/*
endif


" ******************************* Session Files *******************************

if has('mksession')
    " Don't save or restore options and mappings
    set sessionoptions-=options
endif


" ******************************** Swap Files *********************************

" Enable using a swap file for the buffer
set swapfile

" Directories to try for reading/writing swap files
set directory^=~/.vim/swap//

" Don't call [f]sync() after writing to a swap file (more power efficient)
set swapsync=

" Time after which nothing is typed to write the swap file (msec)
set updatetime=250


" ******************************** Undo Files *********************************

" Maximum number of changes that can be undone
"set undolevels=1000

" Save the whole buffer for undo when reloading if less than this many lines
"set undoreload=10000

if has('persistent_undo')
    " Enable saving of undo history to an undo file
    set undofile

    " Directories to try for reading/writing undo files
    set undodir^=~/.vim/undo//
endif


" ******************************** View Files *********************************

if has('mksession')
    " Directory for reading/writing view files
    set viewdir=~/.vim/view

    " List of items to save and restore for views
    "set viewoptions=folds,options,cursor
endif


" ******************************** Functions **********************************

" Centre and pad the current line up to text width (defaults to 79)
" Inspired by: https://stackoverflow.com/a/3400528
function! AsciiTextBanner(...)
    let l:fill_char = a:0 >= 1 ? a:1 : '#'
    let l:text_width = a:0 >= 2 ? a:2 : &textwidth

    if len(l:fill_char) != 1
        let l:fill_char = '#'
    endif

    if l:text_width <= 0 || l:text_width > 1000
        let l:text_width = 79
    endif

    silent s/[[:space:]]*$//
    execute "center" . l:text_width
    execute "normal! hhv0r" . l:fill_char . "A\<Esc>"

    let l:eol_chars = l:text_width - col('$')
    if l:eol_chars > 0
        silent substitute/$/\=(' '.repeat(l:fill_char, l:eol_chars))/
    endif
endfunction


" ******************************* Key Mappings ********************************

" Key to use for <Leader>
let mapleader = '\'

" Move by rows instead of lines (much more intuitive with 'wrap')
nnoremap <expr> j v:count ? 'j' : 'gj'
nnoremap <expr> <Down> v:count ? 'j' : 'gj'
nnoremap <expr> k v:count ? 'k' : 'gk'
nnoremap <expr> <Up> v:count ? 'k' : 'gk'

" Keep the cursor in place when joining lines
nnoremap J mzJ`z

" We never use Ex mode so use its mapping for reformatting
nnoremap Q gq

" Make 'U' perform a redo operation (a sensible inverse of 'u')
nnoremap U <C-R>

" Make behaviour of 'Y' consistent with 'D' and 'C' (i.e. yank from cursor)
nnoremap Y y$

" Open/close current fold
nnoremap zz za

" Shortcuts for managing our vimrc
nnoremap <Leader>ev :vsplit $MYVIMRC<CR>
nnoremap <Leader>sv :source $MYVIMRC<CR><C-L>:echo 'Reloaded .vimrc'<CR>

" Disable highlighting of current search results
nnoremap <Leader><Space> :nohlsearch<C-R>=has('diff')?'<Bar>diffupdate':''<CR><CR><C-L>

" Centre and pad the current line
nnoremap <leader>ac :call AsciiTextBanner()<CR>

" Toggle list mode
nnoremap <Leader>l :set list!<CR>

" Toggle paste mode
nnoremap <Leader>p :set paste!<CR>

" Close current window
nnoremap <Leader>q :quit<CR>

" Toggle line wrapping
nnoremap <Leader>w :set wrap!<CR>

" Toggle spell checking
if has('spell')
    nnoremap <Leader>s :setlocal spell!<CR>
    inoremap <Leader>s <C-\><C-O>:setlocal spell!<CR>
endif

" Break undo before running CTRL-U or CTRL-W so they can be undone
inoremap <C-U> <C-G>u<C-U>
inoremap <C-W> <C-G>u<C-W>

" Write the current buffer via sudo
cnoremap w!! w !sudo tee % > /dev/null


" *****************************************************************************
" * We'll now configure language handling and plugin settings. On minimal Vim *
" * releases (e.g. vim.tiny) effectively none of this will work. Vim versions *
" * without the +eval feature will skip processing of if statements and their *
" * contents, so we wrap all subsequent configuration in an if block so that  *
" * we preserve compatibility with these minimal Vim releases.                *
" *****************************************************************************
if 1

" ***************************** Language Handling *****************************
" ##################################### C #####################################

" Highlight strings inside of comments
let g:c_comment_strings = 1


" ################################### Git #####################################

" Nice to know where our lines will wrap
autocmd FileType gitcommit set colorcolumn=73


" ################################### Jinja ###################################

" Always treat '.jinja' files as Jinja (overrides any modeline)
autocmd BufNewFile,BufWinEnter *.jinja set filetype=jinja


" ################################### Shell ###################################

" Assume Bash syntax for shell files
let g:is_bash = 1

" Bitmask of folding features to enable:
" - 1: Functions
" - 2: Here documents
" - 4: if/do/for statements
let g:sh_fold_enabled = 1


" ********************************** Plugins **********************************
" ############################# vim-plug Startup ##############################

" Directory where vim-plug will store plugins
call plug#begin('~/.vim/plugins')


" ################################ Appearance #################################

" vim-airline & themes
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

" Display vertical indent lines
Plug 'Yggdroot/indentLine'

" Support ANSI escape sequences
Plug 'powerman/vim-plugin-AnsiEsc'

" Relative numbering with a toggle for absolute numbering
if v:version < 703 || v:version == 703 && !has('patch1115')
    set relativenumber
    Plug 'jeffkreeftmeijer/vim-numbertoggle'
endif


" ############################## Colour Schemes ###############################

" Bad Wolf
"Plug 'sjl/badwolf'

" Base16
"Plug 'chriskempson/base16-vim'

" Jellybeans
"Plug 'nanotech/jellybeans.vim'

" Molokai
"Plug 'tomasr/molokai'

" Solarized
Plug 'altercation/vim-colors-solarized'

" Tomorrow Theme
"Plug 'chriskempson/vim-tomorrow-theme'


" ############################### Functionality ###############################

" Full path fuzzy finder
Plug 'ctrlpvim/ctrlp.vim'

" Improved motions handling
Plug 'easymotion/vim-easymotion'

" Support EditorConfig files
if has('python') || has('python3')
    Plug 'editorconfig/editorconfig-vim'
endif

" Improved <Tab> completion
Plug 'ervandew/supertab'

" Full filesystem explorer
Plug 'scrooloose/nerdtree'
" Git support for NERDTree
Plug 'Xuyuanp/nerdtree-git-plugin'

" Heuristically set buffer options
Plug 'tpope/vim-sleuth'

" Clever code quoting
Plug 'tpope/vim-surround'

" Advanced syntax checking
Plug 'vim-syntastic/syntastic'


" ############################### Integrations ################################

" Git: Powerful Git wrapper
Plug 'tpope/vim-fugitive'

" Git: Show a diff in the gutter
if has('signs')
    Plug 'airblade/vim-gitgutter'
endif

" tmux: Clipboard synchronisation
Plug 'roxma/vim-tmux-clipboard'

" tmux: Focus event handling
if v:version > 704 || v:version == 704 && has('patch392')
    Plug 'tmux-plugins/vim-tmux-focus-events'
endif

" tmux: Status line generator
Plug 'edkolev/tmuxline.vim'


" ################################# Languages #################################

" CoffeeScript
Plug 'kchmck/vim-coffee-script'

" Git
Plug 'tpope/vim-git'

" JavaScript
Plug 'pangloss/vim-javascript'

" Jinja2
Plug 'Glench/Vim-Jinja2-Syntax'

" JSON
Plug 'elzr/vim-json'

" Markdown (simple)
Plug 'tpope/vim-markdown'

" Markdown (advanced)
"Plug 'plasticboy/vim-markdown'

" Nagios
Plug 'bigbrozer/vim-nagios'

" PowerShell
Plug 'PProvost/vim-ps1'

" PgSQL
Plug 'lifepillar/pgsql.vim'

" Python
Plug 'python-mode/python-mode', { 'branch': 'develop' }

" Salt
Plug 'saltstack/salt-vim'

" tmux
Plug 'tmux-plugins/vim-tmux'

" YAML (built-in support is very slow)
"Plug 'stephpy/vim-yaml'
" Using our fork until PR #20 is merged
Plug 'ralish/vim-yaml', { 'branch': 'comment-fix' }


" ########################## vim-plug Initialisation ##########################

" Initialise the plugin system
call plug#end()


" ****************************** Plugin Settings ******************************
" ############################### Colour Scheme ###############################

" Set our preferred colour scheme
try
    colorscheme solarized
catch
    colorscheme default
endtry


" ############################# editorconfig-vim ##############################

" File path patterns to exclude
let g:EditorConfig_exclude_patterns = ['fugitive://.*']


" ################################### json ####################################

" Don't conceal double quotes
let g:vim_json_syntax_conceal = 0


" ################################# nerdtree ##################################

" Key mapping to toggle NERDTree
nnoremap <C-N> :NERDTreeToggle<CR>

" Open NERDTree automatically on startup if no files were specified
autocmd StdinReadPre * let s:std_in = 1
if exists(':NERDTree')
    autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif
endif


" ################################### pgsql ###################################

" Make PostgreSQL's SQL dialect the default for '.sql' files
let g:sql_type_default = 'pgsql'


" ################################ python-mode ################################

" Don't automatically run linter on saving changes
let g:pymode_lint_on_write = 0

" Don't automatically regenerate rope project cache on saving changes
let g:pymode_rope_regenerate_on_write = 0


" ################################# syntastic #################################

" Some useful shortcuts to common commands
nnoremap <Leader>sc :SyntasticCheck<CR>
nnoremap <Leader>si :SyntasticInfo<CR>

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

" Nicer symbols for the various issue types
let g:syntastic_warning_symbol = '▲'
let g:syntastic_style_warning_symbol = '≈'
let g:syntastic_error_symbol = '✘'
let g:syntastic_style_error_symbol = '≃'

" Indicate to the C++ compiler which standard we're using
"let g:syntastic_cpp_compiler_options = '-std=c++11'

" Configure which syntax checkers to use for various languages
let g:syntastic_javascript_checkers = ['eslint']
let g:syntastic_yaml_checkers = ['yamllint']

" Use markdownlint-cli (Node.js) instead of mdl (Ruby)
let g:syntastic_markdown_mdl_exec = 'markdownlint'
let g:syntastic_markdown_mdl_args = ''

" Allow shellcheck to source files not specified on the command line
let g:syntastic_sh_shellcheck_args = '-x'


" ################################ vim-airline ################################

" Enable Powerline symbols
let g:airline_powerline_fonts = 1

" Use the Solarized theme
let g:airline_theme = 'solarized'


" ############################### vim-gitgutter ###############################

" Always display the sign column
if exists('&signcolumn')
    set signcolumn=yes
else
    let g:gitgutter_sign_column_always = 1
endif


" ############################# Vim-Jinja2-Syntax #############################

" Disable HTML highlighting as usually we're not editing HTML templates
let g:jinja_syntax_html = 0


" ########################### vim-markdown (tpope) ############################

" Enable fenced code block syntax highlighting for these languages
let g:markdown_fenced_languages = ['bash=sh', 'python', 'sh', 'shell=sh']

" Don't conceal markdown syntax characters
let g:markdown_syntax_conceal = 0


" ######################### vim-markdown (plasticboy) #########################

" Enable fenced code block syntax highlighting for these languages
let g:vim_markdown_fenced_languages =
    \['bash=sh', 'c++=cpp', 'ini=dosini', 'shell=sh', 'viml=vim']


endif
" *****************************************************************************
" * End of configuration of language handling and plugin settings.            *
" *****************************************************************************

" vim: syntax=vim cc=80 tw=79 ts=4 sw=4 sts=4 et sr
