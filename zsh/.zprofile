# Sourced once per login shell; exports are inherited by child shells.
# Put env-setup and login-time side effects here so they don't re-run in
# every interactive shell spawned from a terminal tab.

# Homebrew — sets PATH, MANPATH, INFOPATH, HOMEBREW_PREFIX/CELLAR/REPOSITORY
eval "$(/opt/homebrew/bin/brew shellenv)"

# Tool telemetry / auto-update behavior
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export DISABLE_TELEMETRY=1

# 1Password SSH agent — inherited by git, ssh, scp in any child shell
export SSH_AUTH_SOCK="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# mise: https://mise.jdx.dev/dev-tools/shims.html
# Shims resolve mise-managed tools in non-interactive contexts (IDEs,
# editor LSPs, cron). Full activation lives in .zshrc.
source <(mise activate zsh --shims)
