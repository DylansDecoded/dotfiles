# Sourced for every zsh invocation (interactive, non-interactive, login,
# non-login). Keep this file minimal — heavy env setup belongs in .zprofile.
#
# Keep mise shims first so mise-managed tools win in every shell context,
# including non-interactive ones that skip .zshrc.
# User bin dirs are also kept here so tools in ~/.local/bin and ~/bin resolve
# in contexts that skip .zshrc (VS Code tasks, `ssh host cmd`, scripts).
# Homebrew paths are added by .zprofile via `brew shellenv`.

typeset -U path PATH
path=("$HOME/.local/share/mise/shims" $path "$HOME/.local/bin" "$HOME/bin")
