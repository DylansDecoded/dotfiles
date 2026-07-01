# AGENTS.md
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

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

### Multi-LLM Setup

Four AI tools are configured here — Claude Code, Codex, opencode, and Gemini — and they share infrastructure:
- All consume the same secrets (`SEARXNG_URL`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `GITHUB_TOOLSETS`)
- All use the same MCP server (searxncrawl) pointing at an internal SearxNG instance
- `codex/.codex/AGENTS.md` is the shared global agent instruction file; opencode references it directly

## Claude Code Configuration

All Claude Code config lives in `claude/.claude/`. Key locations:

- **Skills**: `claude/.claude/skills/<name>/skill.md` — custom workflows (gtasks, humanizer, plan-executive-brief, sow-rfp-writeups, clone)
- **Rules**: `claude/.claude/rules/anti-ai-writing-style.md` — 50+ banned AI writing phrases; enforced globally
- **Hooks**: Superwhisper (voice I/O on Stop/Notification/UserPromptSubmit); plan-executive-brief (HTML brief on ExitPlanMode)
- **MCP servers**: `claude/.claude/mcp-servers.json` — context7, sequential-thinking, qmd, fff, searxncrawl
- **Plugin snapshot**: `claude/.claude/plugins-snapshot.json` — restore with `just claude-plugins`

## Adding Packages

To add a Homebrew formula or cask: edit `macos/Brewfile`, then run `just brew`.
