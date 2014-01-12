# Some general cnfiguration common to all shells
# Should be compatible with: sh, bash, ksh, zsh

# Customise our path
export PATH=~/bin:$PATH

# Our preferred text editors ordered by priority
EDITOR_PRIORITY="vim vi nano pico"

# Figure out which editor to default to
for editor in `echo $EDITOR_PRIORITY`; do
	editor_path=`command -v $editor`
	if [ -n "$editor_path" ]; then
		export EDITOR="$editor_path"
		export VISUAL="$editor_path"
		break
	fi
done

