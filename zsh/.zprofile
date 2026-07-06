# Sourced once per login shell; exports are inherited by child shells.
# Put env-setup and login-time side effects here so they don't re-run in
# every interactive shell spawned from a terminal tab.

# Homebrew — sets PATH, MANPATH, INFOPATH, HOMEBREW_PREFIX/CELLAR/REPOSITORY
eval "$(/opt/homebrew/bin/brew shellenv)"

# Tool telemetry / auto-update behavior
export HOMEBREW_NO_ANALYTICS=1
export HOMEBREW_NO_AUTO_UPDATE=1
export DISABLE_TELEMETRY=1

export OPENCODE_ENABLE_EXA=1

# Secrets (sops + age, keyless). The age private key lives only in 1Password;
# sops (>=3.10) fetches it on demand via SOPS_AGE_KEY_CMD, so it never touches
# disk. `just secrets` decrypts secrets/env.sops.yaml into the cached file
# below; we source it so values like SEARXNG_URL / CONTEXT7_API_KEY /
# GITHUB_TOKEN are exported to child processes (Claude Code, Codex, opencode,
# Gemini and their MCP servers). Override the 1Password ref with OP_AGE_REF.
export SOPS_AGE_KEY_CMD="op read ${OP_AGE_REF:-op://Private/sops/SOPS_PRIVATE_KEY}"
[ -f "$HOME/.config/secrets/env.sh" ] && source "$HOME/.config/secrets/env.sh"
