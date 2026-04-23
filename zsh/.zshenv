# Sourced for every zsh invocation (interactive, non-interactive, login,
# non-login). Keep this file minimal — heavy env setup belongs in .zprofile.
#
# User bin dirs are kept here so tools in ~/.local/bin and ~/bin resolve
# in contexts that skip .zshrc (VS Code tasks, `ssh host cmd`, scripts).
# Homebrew paths are added by .zprofile via `brew shellenv`.

typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/bin" $path)
