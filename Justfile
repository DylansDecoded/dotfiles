# Fresh-Mac deployment orchestration. Run `just` to list recipes.
# Each recipe is idempotent and safe to re-run.

dotfiles := justfile_directory()

# Stow packages that map into $HOME. macos/ and secrets/ are intentionally excluded.
packages := "aerospace claude codex direnv fish gemini ghostty git mise opencode ssh starship zellij zsh"

# 1Password reference for the sops age private key. Override per-machine via env if your
# vault/item/field names differ, e.g. OP_AGE_REF="op://Work/sops/SOPS_PRIVATE_KEY".
op_age_ref := env_var_or_default("OP_AGE_REF", "op://Private/sops/SOPS_PRIVATE_KEY")

# Show available recipes.
default:
    @just --list

# Full deploy. The op-gated secrets step runs last.
install: brew stow macos claude-cli claude-plugins secrets
    # If 1Password CLI integration wasn't enabled yet, the op-gated steps stop with
    # guidance; enable it, then re-run `just install` (every step is idempotent).
    @echo "Done. Open a new login shell, then run 'just doctor' to verify."

# Install everything in the Brewfile (brews, casks, fonts, VS Code extensions).
# Third-party taps outside Homebrew's curated allowlist need explicit trust
# (brew >=6) before their formulae/casks can load — trust every tap the
# Brewfile declares so a newly added tap doesn't silently need this repeated.
brew:
    #!/usr/bin/env bash
    set -euo pipefail
    grep -E '^tap "' {{dotfiles}}/macos/Brewfile | sed -E 's/^tap "([^"]+)".*/\1/' | while read -r t; do
      brew tap "$t"
      brew trust --tap "$t"
    done
    brew bundle --file={{dotfiles}}/macos/Brewfile

# Fail unless the 1Password CLI is authenticated (desktop app integration or `op signin`).
_op-check:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v op >/dev/null 2>&1; then
      echo "op CLI not found — run 'just brew' (installs 1password-cli) first." >&2
      exit 1
    fi
    if ! op whoami >/dev/null 2>&1; then
      echo "1Password CLI is not authenticated." >&2
      echo "Open the 1Password app, sign in, then enable:" >&2
      echo "  Settings -> Developer -> 'Integrate with 1Password CLI'." >&2
      echo "The first 'op' call prompts Touch ID. Then re-run." >&2
      echo "(Headless alternative: eval \"\$(op signin)\")" >&2
      exit 1
    fi

# Decrypt sops secrets into ~/.config/secrets/env.sh (sourced by .zprofile).
# Keyless: sops (>=3.10) fetches the age key live from 1Password via SOPS_AGE_KEY_CMD;
# the private key never touches disk.
secrets:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v op >/dev/null 2>&1; then
      echo "op CLI not found — run 'just brew' (installs 1password-cli) first." >&2
      exit 1
    fi
    if ! op whoami >/dev/null 2>&1; then
      echo "1Password CLI not authenticated — attempting 'op signin'..." >&2
      eval "$(op signin)" || {
        echo "Sign-in failed. Enable 1Password app → Settings → Developer → 'Integrate with 1Password CLI'." >&2
        exit 1
      }
    fi
    export SOPS_AGE_KEY_CMD="op read {{op_age_ref}}"
    umask 077
    mkdir -p "$HOME/.config/secrets"
    sops -d --output-type dotenv {{dotfiles}}/secrets/env.sops.yaml \
      | sed -E 's/^/export /' > "$HOME/.config/secrets/env.sh"
    chmod 600 "$HOME/.config/secrets/env.sh"
    echo "Wrote ~/.config/secrets/env.sh (sourced by .zprofile on next login shell)."

# Symlink dotfiles into $HOME via GNU Stow.
stow:
    # Pre-create fold targets so runtime dirs (~/.claude/projects, ~/.ssh/known_hosts, etc.)
    # stay real and out of the repo instead of being folded into a package symlink.
    mkdir -p ~/.config ~/.claude ~/.codex ~/.gemini ~/.ssh
    chmod 700 ~/.ssh
    @echo "--- dry run ---"
    cd {{dotfiles}} && stow -n -v -t ~ {{packages}}
    @echo "--- applying ---"
    cd {{dotfiles}} && stow -v -t ~ {{packages}}

# Apply macOS system defaults.
macos:
    bash {{dotfiles}}/macos/defaults

# Install the Claude Code CLI if missing (official installer).
claude-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v claude >/dev/null 2>&1; then
      echo "claude already installed: $(claude --version 2>/dev/null || echo present)"
    else
      echo "Installing Claude Code CLI"
      curl -fsSL https://claude.ai/install.sh | bash
    fi

# Restore user-scope Claude plugins from the tracked snapshot.
# Marketplaces must be registered before plugins can resolve from them.
claude-plugins:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v claude >/dev/null 2>&1; then
      echo "claude CLI not found — run 'just claude-cli' first. Skipping."
      exit 0
    fi
    claude plugin marketplace add anthropics/claude-plugins-official
    claude plugin marketplace add EveryInc/compound-engineering-plugin
    claude plugin marketplace add superultrainc/superwhisper-claude-code
    fail=0
    while read -r p; do
      [ -z "$p" ] && continue
      echo "Installing plugin: $p"
      claude plugin install "$p" || { echo "  FAILED: $p"; fail=1; }
    done < <(jq -r '.plugins[]' {{dotfiles}}/claude/.claude/plugins-snapshot.json)
    exit "$fail"

# Verify a deployed machine.
doctor:
    #!/usr/bin/env bash
    set -uo pipefail
    ok() { printf '  \033[1;32mok\033[0m  %s\n' "$1"; }
    bad() { printf '  \033[1;31mXX\033[0m  %s\n' "$1"; }
    echo "Tooling:"
    for t in brew stow sops age just jq; do
      command -v "$t" >/dev/null 2>&1 && ok "$t" || bad "$t missing"
    done
    echo "Symlinks:"
    for f in ~/.zshrc ~/.config/ghostty/config ~/.config/starship.toml ~/.codex/config.toml; do
      [ -L "$f" ] || [ -f "$f" ] && ok "$f" || bad "$f missing"
    done
    echo "Secrets:"
    SOPS_AGE_KEY_CMD="op read {{op_age_ref}}" \
      sops -d {{dotfiles}}/secrets/env.sops.yaml >/dev/null 2>&1 \
      && ok "secrets decrypt (keyless via 1Password)" \
      || bad "secrets decrypt failed (op authenticated? sops >= 3.10?)"
    [ -f "$HOME/.config/sops/age/keys.txt" ] \
      && bad "legacy key file on disk — remove with: rm ~/.config/sops/age/keys.txt" \
      || ok "no age key on disk"
    [ -f "$HOME/.config/secrets/env.sh" ] && ok "env.sh generated" || bad "env.sh missing (run 'just secrets')"
    echo "1Password:"
    if command -v op >/dev/null 2>&1; then
      op whoami >/dev/null 2>&1 && ok "op authenticated" || bad "op not authenticated (enable CLI integration)"
    else
      bad "op CLI missing"
    fi
    [ -f "$HOME/.ssh/config" ] && ok "~/.ssh/config present" || bad "~/.ssh/config missing (run 'just stow')"
    echo "Claude plugins:"
    if command -v claude >/dev/null 2>&1; then
      want=$(jq '.plugins | length' {{dotfiles}}/claude/.claude/plugins-snapshot.json)
      have=$(claude plugin list 2>/dev/null | grep -c . || echo 0)
      ok "claude present; snapshot lists $want plugins (installed list rows: $have)"
    else
      bad "claude CLI missing"
    fi
