# Interactive-shell configuration only. Env vars, PATH, Homebrew, and mise
# shims live in .zshenv / .zprofile and are inherited from them.

COMPLETION_WAITING_DOTS="true"

# Added by Windsurf
export PATH="/Users/dylan/.codeium/windsurf/bin:$PATH"

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
# <<< grok installer <<<

# mise: https://mise.jdx.dev/
# Run after other PATH edits so mise-managed tools take precedence.
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

plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"   # must be last

# Docker Desktop owns these completion links. If the app was removed or moved,
# Homebrew leaves dangling links behind and compinit errors while scanning them.
for completion in /opt/homebrew/share/zsh/site-functions/_docker\
                 /opt/homebrew/share/zsh/site-functions/_docker-compose; do
  [[ -L "$completion" && ! -e "$completion" ]] && rm -f "$completion"
done

autoload -Uz compinit && compinit
