# AGENTS.md
This file provides guidance to all Agentic Agents working in the repository. Ensure to follow standards and never break from them.

## Deployment Commands

All orchestration goes through `just` (a `make` alternative). All recipes are idempotent.

| Command | Purpose |
|---|---|
| `just install` | Full deploy: brew → stow → macos → claude-cli → claude-plugins → secrets |
| `just brew` | `brew bundle` from `macos/Brewfile` |
| `just stow` | (Re-)apply GNU Stow symlinks from repo into `$HOME` |
| `just doctor` | Verify tooling, symlinks, secrets, 1Password, plugins |
| `just secrets` | Decrypt `secrets/env.sops.yaml` → `~/.config/secrets/env.sh` (keyless, via 1Password) |
| `sops secrets/env.sops.yaml` | Edit encrypted secrets in-place |
| `brew bundle dump --force --file=macos/Brewfile` | Update Brewfile from current machine state |

## Architecture

### GNU Stow Symlink Model

Every top-level directory (except `macos/` and `secrets/`) is a stow package. `just stow` creates symlinks: `~/dotfiles/<pkg>/path/to/file` → `~/path/to/file`.

**Always edit config files in the repo directory, not directly in `~/.config/`.**

Stow packages: `aerospace`, `claude`, `codex`, `direnv`, `fish`, `gemini`, `ghostty`, `git`, `mise`, `opencode`, `ssh`, `starship`, `zellij`, `zsh`

`macos/` is applied via `just macos` (150+ macOS system defaults). `secrets/` is managed via `just secrets`. Neither is stowed.

### Secrets Pipeline

```
secrets/env.sops.yaml  (ciphertext, committed)
    ↓  just secrets — sops (>=3.10) runs SOPS_AGE_KEY_CMD="op read op://Private/sops/SOPS_PRIVATE_KEY"
    ↓                 to fetch the age key live from 1Password (key never touches disk)
~/.config/secrets/env.sh  (plaintext, gitignored)
    ↓  sourced in .zprofile at login
SEARXNG_URL, CONTEXT7_API_KEY, GITHUB_TOKEN, GITHUB_TOOLSETS
```

The sops age private key lives only in 1Password (`op://Private/sops/SOPS_PRIVATE_KEY`) — it is never committed and never written to disk. `SOPS_AGE_KEY_CMD` is exported in `.zprofile`, so manual `sops secrets/env.sops.yaml` edits also work keylessly (override the ref per-machine with `OP_AGE_REF`). Before `just secrets` will work on a fresh machine, 1Password CLI integration must be enabled in the app: **Settings → Developer → "Integrate with 1Password CLI"**.

### Fresh Mac Bootstrap

`bootstrap.sh` solves the chicken-and-egg problem (no `just` on a blank machine): it installs Xcode CLI Tools, Homebrew, and a minimal toolchain (`just stow age sops jq 1password-cli` + 1Password app), clones the repo to `~/dotfiles`, then runs `just install`.

The intended outcome is a repeatable fresh-machine restore: on a new Mac, `bootstrap.sh` or `just install` should re-deploy the tracked agent toolchain, configs, shared skills, and MCP wiring without manual repo edits.

### Multi-LLM Setup

Four AI tools are configured here — Claude Code, Codex, opencode, and Gemini — and they share infrastructure:
- All consume the same secrets (`SEARXNG_URL`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `GITHUB_TOOLSETS`)
- All use the same MCP server (searxncrawl) pointing at an internal SearxNG instance
- `agents/.agents/AGENTS.md` is the canonical shared instruction file; Claude, Codex, and opencode point to it
- `agents/.agents/skills/` is the source of truth for shared skills; LLM-specific skill directories should reference these skills with symlinks instead of duplicating files

### LLM Configuration Pattern

For any LLM configured in this repo, follow this pattern:

- `agents/.agents/AGENTS.md` is the canonical instruction file
- `agents/.agents/skills/` is the source of truth for shared skills
- LLM-specific skill directories should symlink back to `agents/.agents/skills/`
- The repo-internal symlinks express shared ownership; GNU Stow then deploys the consumer package into `$HOME`
- Agent-specific instructions or skills may live in the tool's own config directory only when they are not part of the shared set
- New onboarded LLMs should follow the same pattern rather than introducing copied instruction or skill trees
- New machine setup should require only `bootstrap.sh` or `just install`, plus unavoidable external authentication steps such as 1Password or OAuth re-auth

## Claude Code Configuration

All Claude Code config lives in `claude/.claude/`. Key locations:

- **Skills**: `claude/.claude/skills/<name>/skill.md` — agent-specific workflows live here; shared skills are symlinked from `agents/.agents/skills/`
- **Rules**: `claude/.claude/rules/anti-ai-writing-style.md` — 50+ banned AI writing phrases; enforced globally
- **Hooks**: Superwhisper (voice I/O on Stop/Notification/UserPromptSubmit); plan-executive-brief (HTML brief on ExitPlanMode)
- **MCP servers**: `claude/.claude/mcp-servers.json` — context7, sequential-thinking, qmd, fff, searxncrawl
- **Plugin snapshot**: `claude/.claude/plugins-snapshot.json` — restore with `just claude-plugins`

## Adding Packages

To add a Homebrew formula or cask: edit `macos/Brewfile`, then run `just brew`.
