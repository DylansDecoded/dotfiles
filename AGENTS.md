# AGENTS.md
This file provides guidance to all Agentic Agents working in the repository. Ensure to follow standards and never break from them.

## Deployment Commands

All orchestration goes through `just` (a `make` alternative). All recipes are idempotent.

Every recipe is also mirrored as a **mise task** in the repo-root `mise.toml` (migration
in progress — `just` stays canonical until it completes). Use `mise run <task>`
(e.g. `mise run install`, `mise run stow`, `mise run doctor`); run `mise tasks` to list.
The repo `mise.toml` also pins the orchestration tools (`sops`, `age`, `jq`); `stow` is
not in the mise registry and stays brew-managed.

| Command | Purpose |
|---|---|
| `just install` | Full deploy: brew → stow → macos → AI CLIs → secrets |
| `just brew` | `brew bundle` from `macos/Brewfile` |
| `just stow` | (Re-)apply GNU Stow symlinks from repo into `$HOME` |
| `just doctor` | Verify tooling, symlinks, secrets, 1Password, and installed CLIs |
| `just claude-cli` | Install the Claude Code CLI if missing |
| `just codex-cli` | Install the Codex CLI if missing |
| `just grok-cli` | Install the Grok CLI if missing |
| `just opencode-cli` | Install the OpenCode CLI if missing |
| `just pi-cli` | Install the Pi coding-agent CLI if missing |
| `just secrets` | Decrypt `secrets/env.sops.yaml` → `~/.config/secrets/env.sh` (keyless, via 1Password) |
| `sops secrets/env.sops.yaml` | Edit encrypted secrets in-place |
| `brew bundle dump --force --file=macos/Brewfile` | Update Brewfile from current machine state |

## Architecture

### GNU Stow Symlink Model

Every top-level directory (except `macos/` and `secrets/`) is a stow package. `just stow` creates symlinks: `~/dotfiles/<pkg>/path/to/file` → `~/path/to/file`.

**Always edit config files in the repo directory, not directly in `~/.config/`.**

Stow packages: `aerospace`, `direnv`, `fish`, `ghostty`, `git`, `mise`, `starship`, `zellij`, `zsh`

`macos/` is applied via `just macos` (150+ macOS system defaults). `secrets/` is managed via `just secrets`. Neither is stowed.

### Secrets Pipeline

```
secrets/env.sops.yaml  (ciphertext, committed)
    ↓  just secrets — sops (>=3.10) runs SOPS_AGE_KEY_CMD="op read op://Private/sops/SOPS_PRIVATE_KEY"
    ↓                 to fetch the age key live from 1Password (key never touches disk)
~/.config/secrets/env.sh  (plaintext, gitignored)
    ↓  sourced in .zprofile at login
SEARXNG_URL, CONTEXT7_API_KEY, GITHUB_TOKEN, GITHUB_TOOLSETS, CAMOFOX_API_KEY
```

The sops age private key lives only in 1Password (`op://Private/sops/SOPS_PRIVATE_KEY`) — it is never committed and never written to disk. `SOPS_AGE_KEY_CMD` is exported in `.zprofile`, so manual `sops secrets/env.sops.yaml` edits also work keylessly (override the ref per-machine with `OP_AGE_REF`). Before `just secrets` will work on a fresh machine, 1Password CLI integration must be enabled in the app: **Settings → Developer → "Integrate with 1Password CLI"**.

### Fresh Mac Bootstrap

`bootstrap.sh` solves the chicken-and-egg problem (no `just` on a blank machine): it installs Xcode CLI Tools, Homebrew, and a minimal toolchain (`just stow age sops jq 1password-cli` + 1Password app), clones the repo to `~/dotfiles`, then runs `just install`.

The intended outcome is a repeatable fresh-machine restore: on a new Mac, `bootstrap.sh` or `just install` should re-deploy the tracked dotfiles without manual repo edits.

### AI Tooling Policy

The repository may install AI applications and CLIs, but it intentionally does not track their configuration directories. Claude Code, Codex, Grok, OpenCode, Pi, and similar tools should start from their vendor defaults. Do not add agent instructions, skills, plugins, hooks, MCP definitions, themes, model settings, or launch wrappers unless that policy is explicitly changed.

## Adding Packages

To add a Homebrew formula or cask: edit `macos/Brewfile`, then run `just brew`.
