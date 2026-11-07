# Fresh-Mac deployment orchestration. Run `just` to list recipes.
# Each recipe is idempotent and safe to re-run.

dotfiles := justfile_directory()

# Stow packages that map into $HOME. macos/ and secrets/ are intentionally excluded.
packages := "aerospace agents claude codex direnv fish ghostty git grok herdr mise moshi opencode pi starship zellij zsh"

# 1Password reference for the sops age private key. Override per-machine via env if your
# vault/item/field names differ, e.g. OP_AGE_REF="op://Work/sops/SOPS_PRIVATE_KEY".
op_age_ref := env_var_or_default("OP_AGE_REF", "op://Private/sops/SOPS_PRIVATE_KEY")

# Show available recipes.
default:
    @just --list

# Full deploy. The op-gated secrets step runs last.
install: brew stow macos claude-cli codex-cli grok-cli opencode-cli herdr-cli pi-cli claude-plugins secrets
    # If 1Password CLI integration wasn't enabled yet, the op-gated steps stop with
    # guidance; enable it, then re-run `just install` (every step is idempotent).
    @echo "Done. Open a new login shell, then run 'just doctor' to verify."
    @echo "Post-wipe runbook: POST-WIPE.md — then just mcp-repos && just projects-scaffold"

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
    # Pre-create fold targets so runtime dirs (~/.claude/projects, ~/.config/herdr/*.log, etc.)
    # stay real and out of the repo instead of being folded into a package symlink.
    # ~/.agents/skills must stay a real directory so stow links each shared skill
    # per entry. If it folded into a package symlink, skills installed outside the
    # repo could not live beside the tracked ones.
    mkdir -p ~/.config ~/.claude ~/.codex ~/.gemini ~/.grok ~/.agents/skills ~/.config/herdr ~/.config/moshi \
        ~/.pi/agent/extensions ~/.pi/agent/agents ~/.pi/agent/prompts
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

# Install the Codex CLI if missing (official installer).
codex-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v codex >/dev/null 2>&1; then
      echo "codex already installed: $(codex --version 2>/dev/null || echo present)"
    else
      echo "Installing Codex CLI"
      curl -fsSL https://chatgpt.com/codex/install.sh | sh
    fi

# Install the Grok CLI if missing (official installer).
grok-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v grok >/dev/null 2>&1; then
      echo "grok already installed: $(grok --version 2>/dev/null || grok version 2>/dev/null || echo present)"
    else
      echo "Installing Grok CLI"
      curl -fsSL https://x.ai/cli/install.sh | bash
    fi

# Install the OpenCode CLI if missing (official Homebrew formula).
opencode-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v opencode >/dev/null 2>&1; then
      echo "opencode already installed: $(opencode --version 2>/dev/null || echo present)"
    else
      echo "Installing OpenCode CLI"
      brew install anomalyco/tap/opencode
    fi

# Install the Herdr CLI if missing (official installer; self-updates via `herdr update`).
herdr-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v herdr >/dev/null 2>&1; then
      echo "herdr already installed: $(herdr --version 2>/dev/null || echo present)"
    else
      echo "Installing Herdr CLI"
      curl -fsSL https://herdr.dev/install.sh | sh
    fi

# Install the Pi coding agent CLI if missing (npm global package).
# Auth is interactive (pi login / provider keys); never commit auth.json.
pi-cli:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v pi >/dev/null 2>&1; then
      echo "pi already installed: $(pi --version 2>/dev/null || echo present)"
    else
      echo "Installing Pi coding agent CLI (@mariozechner/pi-coding-agent)"
      if command -v npm >/dev/null 2>&1; then
        npm install -g @mariozechner/pi-coding-agent
      else
        echo "npm not found — install Node (brew/mise), then re-run just pi-cli" >&2
        exit 1
      fi
    fi
    mkdir -p "$HOME/.local/bin" "$HOME/.pi/agent"
    # Managed installs often symlink into ~/.local/bin/pi
    if ! command -v pi >/dev/null 2>&1 && [ -x "$HOME/.local/bin/pi" ]; then
      echo "pi binary at ~/.local/bin/pi — ensure ~/.local/bin is on PATH"
    fi

# Clone MCP-related tool repos used by stowed agent configs (idempotent).
# crawler MCP expects ~/Projects/tools/searxNcrawl (see claude/.claude/.mcp.json).
mcp-repos:
    #!/usr/bin/env bash
    set -euo pipefail
    tools="$HOME/Projects/tools"
    mkdir -p "$tools"
    clone_one() {
      local url=$1 dest=$2
      if [ -d "$dest/.git" ]; then
        echo "ok  $dest (exists)"
        git -C "$dest" fetch --quiet origin 2>/dev/null || true
        return 0
      fi
      if [ -e "$dest" ]; then
        echo "skip $dest (exists, not a git repo)"
        return 0
      fi
      echo "clone $url -> $dest"
      git clone "$url" "$dest"
    }
    # Prefer HTTPS so gh credential helper works when SSH is a different GitHub user.
    clone_one "https://github.com/DylansDecoded/searxNcrawl.git" "$tools/searxNcrawl" \
      || clone_one "git@github.com:DylansDecoded/searxNcrawl.git" "$tools/searxNcrawl" \
      || echo "WARN: could not clone searxNcrawl — create $tools/searxNcrawl manually"
    if command -v uv >/dev/null 2>&1 && [ -d "$tools/searxNcrawl" ]; then
      echo "uv present; crawler MCP can use: uv run --directory $tools/searxNcrawl ..."
    else
      echo "note: install uv if crawler MCP fails (https://github.com/astral-sh/uv)"
    fi
    echo "MCP repos done. SEARXNG_URL still comes from just secrets / env.sh."

# Create empty Projects bucket directories (does not delete or move existing trees).
projects-scaffold:
    #!/usr/bin/env bash
    set -euo pipefail
    root="$HOME/Projects"
    for d in \
      work/robots-and-pencils \
      personal/products \
      personal/home \
      tools \
      labs \
      knowledge \
      .archive \
      .runtime
    do
      mkdir -p "$root/$d"
      echo "ok  $root/$d"
    done
    echo "Projects scaffold ready. See docs/projects-layout.md for clone targets."

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
    warn() { printf '  \033[1;33m!!\033[0m  %s\n' "$1"; }
    fail=0
    echo "Tooling:"
    for t in brew stow sops age just jq; do
      if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t missing"; fail=1; fi
    done
    echo "AI CLIs:"
    for t in claude codex opencode herdr pi; do
      if command -v "$t" >/dev/null 2>&1; then ok "$t"; else bad "$t missing"; fail=1; fi
    done
    for t in grok moshi; do
      if command -v "$t" >/dev/null 2>&1; then ok "$t"; else warn "$t missing (optional)"; fi
    done
    command -v cursor >/dev/null 2>&1 || command -v cursor-agent >/dev/null 2>&1 \
      && ok "cursor present" || warn "cursor not on PATH (optional; install app and sign in)"
    echo "Symlinks:"
    for f in ~/.zshrc ~/.config/ghostty/config ~/.config/starship.toml ~/.codex/config.toml; do
      if [ -L "$f" ] || [ -f "$f" ]; then ok "$f"; else bad "$f missing"; fail=1; fi
    done
    [ -L "$HOME/.agents/skills" ] || [ -d "$HOME/.agents/skills" ] \
      && ok "~/.agents/skills" || warn "~/.agents/skills missing (run just stow)"
    for f in \
      "$HOME/.pi/agent/settings.json" \
      "$HOME/.pi/agent/mcp.json" \
      "$HOME/.pi/agent/models.json" \
      "$HOME/.pi/agent/extensions/herdr-agent-state.ts" \
      "$HOME/.pi/agent/agents/scout.md" \
      "$HOME/.pi/agent/prompts/deepen.md" \
      "$HOME/.agents/skills/pi-skills-public/README.md"
    do
      if [ -L "$f" ]; then ok "$f (stowed)"
      elif [ -e "$f" ]; then warn "$f exists but is not a symlink (run just stow after backing up)"
      else warn "$f missing (run just stow)"
      fi
    done
    echo "Secrets:"
    if SOPS_AGE_KEY_CMD="op read {{op_age_ref}}" \
      sops -d {{dotfiles}}/secrets/env.sops.yaml >/dev/null 2>&1; then
      ok "secrets decrypt (keyless via 1Password)"
    else
      bad "secrets decrypt failed (op authenticated? sops >= 3.10?)"
      fail=1
    fi
    if [ -f "$HOME/.config/sops/age/keys.txt" ]; then
      warn "legacy age key file on disk (optional remove: rm ~/.config/sops/age/keys.txt)"
    else
      ok "no age key on disk"
    fi
    if [ -f "$HOME/.config/secrets/env.sh" ]; then ok "env.sh generated"; else bad "env.sh missing (run 'just secrets')"; fail=1; fi
    echo "1Password:"
    if command -v op >/dev/null 2>&1; then
      if op whoami >/dev/null 2>&1; then ok "op authenticated"; else bad "op not authenticated (enable CLI integration)"; fail=1; fi
    else
      bad "op CLI missing"; fail=1
    fi
    echo "GitHub:"
    if command -v gh >/dev/null 2>&1; then
      if gh auth status >/dev/null 2>&1; then ok "gh authenticated"; else warn "gh not logged in (gh auth login)"; fi
    else
      bad "gh missing"; fail=1
    fi
    echo "MCP / Projects:"
    if [ -d "$HOME/Projects/tools/searxNcrawl/.git" ] || [ -d "$HOME/Projects/tools/searxNcrawl" ]; then
      ok "searxNcrawl at ~/Projects/tools/searxNcrawl"
    else
      warn "searxNcrawl missing — run just mcp-repos (crawler MCP needs it)"
    fi
    command -v uv >/dev/null 2>&1 && ok "uv" || warn "uv missing (crawler MCP)"
    [ -d "$HOME/Projects" ] && ok "~/Projects" || warn "~/Projects missing — just projects-scaffold"
    echo "Agent credentials (presence only; never printed):"
    if [ -f "$HOME/.config/anthropic/credentials/default.json" ]; then
      if [ -r "$HOME/.config/anthropic/credentials/default.json" ]; then
        ok "anthropic credentials file readable"
      else
        bad "anthropic credentials exist but not readable (ownership/mode)"
        fail=1
      fi
    else
      warn "no anthropic credentials file (Pi/Kimi may need provider login)"
    fi
    [ -f "$HOME/.pi/agent/auth.json" ] && ok "pi auth.json present" || warn "pi auth.json missing (pi login)"
    echo "Claude plugins:"
    if command -v claude >/dev/null 2>&1; then
      want=$(jq '.plugins | length' {{dotfiles}}/claude/.claude/plugins-snapshot.json)
      have=$(claude plugin list 2>/dev/null | grep -c . || echo 0)
      ok "claude present; snapshot lists $want plugins (installed list rows: $have)"
    else
      bad "claude CLI missing"; fail=1
    fi
    echo "Docs:"
    [ -f {{dotfiles}}/POST-WIPE.md ] && ok "POST-WIPE.md" || bad "POST-WIPE.md missing"
    if [ "$fail" -ne 0 ]; then
      echo "doctor: failures present"
      exit 1
    fi
    echo "doctor: all required checks passed"
