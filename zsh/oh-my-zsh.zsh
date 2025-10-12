# ---------------------------------- Paths ------------------------------------

# Installation
export ZSH="$HOME/.oh-my-zsh"

# Custom files
ZSH_CUSTOM="$HOME/dotfiles/zsh/oh-my-zsh"

# Cache files
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/oh-my-zsh"

# Completion cache
ZSH_COMPDUMP="$ZSH_CACHE_DIR/zcompdump-${SHORT_HOST}-${ZSH_VERSION}"

# ---------------------------------- Theme ------------------------------------

# Name of theme to load or "random" to load a random theme
if [[ -d $ZSH_CUSTOM/themes/powerlevel10k ]]; then
    ZSH_THEME='powerlevel10k/powerlevel10k'
else
    ZSH_THEME='agnoster'
fi

# Random theme: Array of candidate themes
#ZSH_THEME_RANDOM_CANDIDATES=()

# Random theme: Array of ignored themes
#
# NOTE: Only applies if ZSH_RANDOM_THEME_CANDIDATES is not set.
#ZSH_THEME_RANDOM_IGNORED=()

# Random theme: Suppress startup message indicating the chosen theme
#ZSH_THEME_RANDOM_QUIET='true'

# --------------------------------- Plugins -----------------------------------

# Array of plugins to load
plugins=(colored-man-pages gitfast shrink-path zsh-autosuggestions)

# ------------------------------- Completion ----------------------------------

# Permit loading completion functions from potentially insecure paths
#ZSH_DISABLE_COMPFIX='true'

# Print a red ellipsis when a completion request is processing. A string
# can also be provided to specify what to print instead of a red ellipsis.
#COMPLETION_WAITING_DOTS='true'

# Perform case-sensitive completion
CASE_SENSITIVE='true'

# Treat hyphens and underscores as interchangeable for completion
#
# NOTE: Case-sensitive completion must be disabled.
#HYPHEN_INSENSITIVE='true'

# --------------------------------- Library -----------------------------------

# Disable "magic" functions which may cause compatibility issues
#DISABLE_MAGIC_FUNCTIONS='true'

# Disable automatic usage of colour output with "ls" utility
#DISABLE_LS_COLORS='true'

# Attempt to correct command names and filenames passed as arguments
#ENABLE_CORRECTION='true'

# Disable marking untracked files under VCS as dirty (for performance)
#DISABLE_UNTRACKED_FILES_DIRTY='true'

# Timestamp format when showing command history
#
# Valid values:
# - (blank)             No timestamps
# - mm/dd/yyyy
# - dd.mm.yyyy
# - yyyy-mm-dd
# - (custom)            Directly passed to omz_history as "-t" argument
#HIST_STAMPS=''

# ---------------------------------- Title ------------------------------------

# Disable setting the terminal title based on the running command
#DISABLE_AUTO_TITLE='true'

# --------------------------------- Updates -----------------------------------

# Automatic updates mode
#
# Valid values:
# - disabled
# - automatic
# - reminder
zstyle ':omz:update' mode disabled

# Frequency of update checks (days)
#zstyle ':omz:update' frequency 13

# ----------------------------- Initialisation --------------------------------

# Load Oh My Zsh
source "$ZSH/oh-my-zsh.sh"

# -------------------------------- Post-init ----------------------------------

# NOTE: These settings must be set *after* Oh My Zsh has been sourced.

# Default terminal title when not running a command
#ZSH_THEME_TERM_TITLE_IDLE='%n@%m:%~'

# Default terminal tab title when not running a command
#ZSH_THEME_TERM_TAB_TITLE_IDLE='%15<..<%~%<<'

# -------------------------- Theme Customisations -----------------------------

case $ZSH_THEME in
    agnoster)
        # Hide our user account in the prompt
        if [[ $USER = samuel.leslie ]]; then
            DEFAULT_USER='samuel.leslie'
        else
            DEFAULT_USER='sdl'
        fi

        # Shrink the current path
        prompt_dir() {
            prompt_segment blue black "$(shrink_path -l -t)"
        }
        ;;
    powerlevel10k/powerlevel10k)
        [[ ! -f $HOME/.p10k.zsh ]] || source "$HOME/.p10k.zsh"
        ;;
esac

# ----------------------------- Plugin Settings -------------------------------
# =========================== zsh-autosuggestions =============================

plugin='zsh-autosuggestions'
if (($plugins[(Ie)$plugin])); then
    # Colour to use when highlighting suggestions
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=250'
fi

# -------------------------------- Clean-up -----------------------------------

unset plugin

# vim: syntax=zsh cc=80 tw=79 ts=4 sw=4 sts=4 et sr
