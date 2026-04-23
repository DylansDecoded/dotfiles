# Interactive-shell configuration only. Env vars, PATH, Homebrew, and mise
# shims live in .zshenv / .zprofile and are inherited from them.

COMPLETION_WAITING_DOTS="true"

# mise: https://mise.jdx.dev/
eval "$(mise activate zsh)"
# zoxide: https://zoxide.org/
eval "$(zoxide init zsh)"
# https://github.com/junegunn/fzf
source <(fzf --zsh)
# https://starship.rs/
eval "$(starship init zsh)"

# Zap plugin manager: https://zapzsh.com
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] \
  && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

autoload -Uz compinit && compinit

plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"   # must be last
