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

# Podman Compose Provider
export PODMAN_COMPOSE_PROVIDER=/opt/homebrew/bin/podman-compose

# Local Bin
export PATH="$HOME/.local/bin:$PATH"

# Orca Router API Key
export ORCAROUTER_API_KEY=sk-orca-w8jcAclvgGpyxo8cQqw1UoLk0PYewiliTM5Ge4JGe1o
export JIRA_API_TOKEN=АТАТТ3хFfGF©qКHaaQNсamu549vsv3еRеfW5qbI8G9sDTjt8hZUsuWUChvНiYNMpAtuPg83Emqfo5jttbpchLЗеUsquЗееQJpRWesbcu58NtSduGnF6—L4Q©AvоgnТFLуJuBqNIVZBe_7у×2QEbW1wN4EG1х7m9oVy1gILcN25nsYBT6kQl_IwM=38A6929F

# quota-axi only reads ~/.grok/auth.json; any grok CLI call renews the token first.
alias quota-axi='grok models >/dev/null 2>&1; command quota-axi'
export CURSOR_API_KEY=crsr_b1084d5d427835d9112c2cf3b0327a8fe83dc83b2c62441c35c806064e18d9ac

# kimi-code
export PATH="/Users/dylan/.kimi-code/bin:$PATH"
export ORCA_KEY='sk-orca-YbnrK2vWO8EGgQVgbCo3kTpEOYjZRDElq8G5teyHeAx'
