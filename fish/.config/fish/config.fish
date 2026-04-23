# ~/.config/fish/config.fish

# XDG Paths
set -gx XDG_CONFIG_HOME $HOME/.config
set -gx XDG_CACHE_HOME $HOME/.cache
set -gx XDG_DATA_HOME $HOME/.local/share


# Homebrew (Apple Silicon)
# fish_add_path /opt/homebrew/bin
# fish_add_path /opt/homebrew/sbin

# Common paths
fish_add_path ~/bin
fish_add_path ~/.local/bin

# Suppress the greeting
set -g fish_greeting

# Editor
set -gx EDITOR "nvim --wait"  # or vim, nvim, etc.

# init plugins
zoxide init fish | source 


# Homebrew completions
if test -d (brew --prefix)"/share/fish/completions"
    set -p fish_complete_path (brew --prefix)/share/fish/completions
end
if test -d (brew --prefix)"/share/fish/vendor_completions.d"
    set -p fish_complete_path (brew --prefix)/share/fish/vendor_completions.d
end
