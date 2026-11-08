# AGENTS.md
This file provides guidance to all Agentic Agents working in the repository. Ensure to follow standards and never break from them.

## Commands

Deployment uses [mise dotfiles](https://mise.jdx.dev/dotfiles.html) and mise tasks. Everything is idempotent.

| Command | Purpose |
|---|---|
| `./bootstrap.sh` | Fresh Mac: Xcode CLT, Homebrew, sops toolchain, mise, clone, pin overlay, `mise bootstrap` |
| `mise bootstrap` | Link dotfiles, install `[tools]`, then run `mise-tasks/bootstrap` (all setup tasks; reports failures at the end) |
| `mise dot apply` / `mise dot status` | Apply / check the `[dotfiles]` links |
| `mise tasks` | List setup tasks in `mise-tasks/` (`brew`, `macos`, `secrets`, `doctor`, agent CLIs, ...) |
| `mise run doctor` | Verify tooling, dotfile drift, secrets, 1Password, gh, plugins |
| `mise run secrets` | Decrypt `secrets/env.sops.yaml` → `~/.config/secrets/env.sh` (keyless, via 1Password) |
| `sops secrets/env.sops.yaml` | Edit encrypted secrets in place |
| `brew bundle dump --force --file=macos/Brewfile` | Update Brewfile from current machine state |
| `python3 -m unittest discover -s tests -v` | Task and launcher regression tests (temporary home, no real secrets) |

## Architecture

### Layout

- `mise.toml`: shared `[dotfiles]`, `[tools]`, settings. Linked to `~/.config/mise/config.toml`, so it is also the global mise config.
- `mise.<machine>.toml`: per-machine overlay, selected by `env = ["<machine>"]` in the untracked `~/.config/mise/miserc.toml`. Only `mise.macos.toml` exists today.
- `home/`: mirrors `$HOME` path for path (`home/.claude` is `~/.claude`, `home/.config/ghostty` is `~/.config/ghostty`). `mise.toml` links `~/.claude/*`, `~/.codex/*`, `~/.grok/*`, `~/.pi/agent/*`, `~/.agents/*`, `~/.local/bin/*` by glob, so a new file in those dirs needs only `mise dot apply`. `~/.config` apps are listed one by one.
- `mise-tasks/`: one executable script per setup task. Scripts locate the repo from their own path, so they also run directly (`mise-tasks/secrets`).
- `macos/` (Brewfile, `defaults`, app lists) and `secrets/` (sops ciphertext) are not deployed as files.

**Always edit config files under `home/`, not in `$HOME`.** Every `[dotfiles]` entry is a `symlink`, so edits through `$HOME` land in the repo. Put only authored files under `home/`: runtime state (auth, sessions, caches) must stay outside the repo. After adding or removing files, run `mise dot apply` and check `mise dot status`.

### Secrets Pipeline

```
secrets/env.sops.yaml  (ciphertext, committed)
    ↓  mise run secrets — sops (>=3.10) runs SOPS_AGE_KEY_CMD="op read op://Private/sops/SOPS_PRIVATE_KEY"
    ↓                     to fetch the age key live from 1Password (key never touches disk)
~/.config/secrets/env.sh  (plaintext, outside the repo)
    ↓  sourced by zprofile at login
SEARXNG_URL, CONTEXT7_API_KEY, GITHUB_TOKEN, GITHUB_TOOLSETS, CAMOFOX_API_KEY, ...
```

The sops age private key lives only in 1Password. `SOPS_AGE_KEY_CMD` is exported in `home/.zprofile`, so manual `sops` edits also work keylessly (override the ref per machine with `OP_AGE_REF`). On a fresh machine, enable 1Password CLI integration first: **Settings → Developer → "Integrate with 1Password CLI"**.

### Agents

- `home/AGENTS.md` is the one global instruction file. `home/.claude/CLAUDE.md`, `home/.codex/AGENTS.md`, `home/.pi/agent/AGENTS.md`, and `home/.config/opencode/AGENTS.md` are repo-internal links to it.
- `home/.agents/skills/` is the one skills tree, linked to `~/.agents/skills` (Codex, OpenCode and Pi read it). `home/.claude/skills` links to it for Claude Code.
- A skill must exist as exactly one real `SKILL.md`. Never copy a skill into a tool-specific directory: a second real copy with the same `name` is a collision and one is dropped.
- `home/.agents/skills/advisor-strategy` is a git submodule; clone with `--recurse-submodules`. `pi-skills-public/` is vendored.
- `*-workspace/` directories beside skills hold skill data (some skills read them from `~/.claude/skills/`); they have no `SKILL.md`.
- All agents use the crawler MCP server (via `uv` from `~/Projects/tools/searxNcrawl`, cloned by `mise run mcp-repos`).
- New agents follow the same pattern: put their config under `home/.<tool>/`, add a glob entry in `mise.toml`, read the shared AGENTS.md and skills, and need nothing beyond `bootstrap.sh` plus unavoidable logins.

### Claude Code

- `home/.claude/settings.json`: permissions, hooks (plan-executive-brief on ExitPlanMode, axi SessionStart hooks), statusline.
- `home/.claude/rules/anti-ai-writing-style.md`: banned AI writing phrases; enforced globally.
- `home/.claude/.mcp.json`: MCP servers. `home/.claude/plugins-snapshot.json`: restore with `mise run claude-plugins`.

## Adding things

- Homebrew formula or cask: edit `macos/Brewfile`, then `mise run brew`.
- A config file: put it at its `$HOME` path under `home/`. Inside a globbed dir that is enough; otherwise add a `[dotfiles]` entry (shared in `mise.toml`, machine-only in `mise.<machine>.toml`). Then `mise dot apply`.
- A setup step: add an executable script to `mise-tasks/` with a `#MISE description=` line, and add it to `mise-tasks/bootstrap` if a fresh machine needs it.
