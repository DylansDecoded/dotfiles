# Sourced for every zsh invocation (interactive, non-interactive, login,
# non-login). Keep this file minimal — heavy env setup belongs in .zprofile.
#
# Keep mise shims first so mise-managed tools win in every shell context,
# including non-interactive ones that skip .zshrc.
# User bin dirs are also kept here so tools in ~/.local/bin and ~/bin resolve
# in contexts that skip .zshrc (VS Code tasks, `ssh host cmd`, scripts).
# Homebrew must be here too: mosh's remote `mosh-server` lookup and other
# `ssh host cmd` invocations are non-login, so they skip .zprofile's
# `brew shellenv`. Login shells still get the rest of brew's env from there.

typeset -U path PATH
path=("$HOME/.local/share/mise/shims" /opt/homebrew/bin /opt/homebrew/sbin $path "$HOME/.local/bin" "$HOME/bin")
