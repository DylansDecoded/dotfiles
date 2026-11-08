# dotfiles

Personal macOS developer environment: shell, terminal, window manager, git, and
the agent toolchain (Claude Code, Codex, OpenCode, Pi, Grok). Deployed with
[mise dotfiles](https://mise.jdx.dev/dotfiles.html); secrets encrypted with
[sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

## Layout

- `mise.toml` - shared config: `[dotfiles]` links, `[tools]`, settings. Linked to
  `~/.config/mise/config.toml`, so it is also the global mise config.
- `mise.<machine>.toml` - per-machine overlay (`mise.macos.toml` today). The host
  picks one in the untracked `~/.config/mise/miserc.toml`: `env = ["macos"]`.
- `home/` - mirrors `$HOME` path for path (`home/.claude` is `~/.claude`).
  `home/AGENTS.md` and `home/.agents/skills/` are the one instruction file and
  the one skills tree for every agent.
- `mise-tasks/` - setup tasks (`mise run <task>`; `mise tasks` lists them).
- `macos/` - Brewfile and system defaults. `secrets/` - sops ciphertext.

## Fresh Mac

Full post-reinstall order (Projects, Firstmate, logins): **[POST-WIPE.md](POST-WIPE.md)**.

```sh
curl -fsSL https://raw.githubusercontent.com/DylansDecoded/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` installs Xcode Command Line Tools, Homebrew, the secrets toolchain
(`age sops jq 1password-cli` + the 1Password app) and mise, clones this repo to
`~/dotfiles`, pins the machine overlay, and runs `mise bootstrap`. That links
the dotfiles, installs `[tools]`, then runs `mise-tasks/bootstrap`, which attempts
each task below and lists the failed ones at the end.

Daily use: edit files under `home/` in place (they are symlinked). After adding
or removing files, run `mise dot apply`. `mise dot status` shows drift.

## Tasks

| Task | What it does |
| --- | --- |
| `brew` | `brew bundle` from `macos/Brewfile`, trusting each declared tap. |
| `macos` | Runs `macos/defaults` without closing apps. Log out and in afterwards. |
| `shell-plugins` | Installs Zap and the configured zsh plugins. |
| `claude-cli`, `codex-cli`, `grok-cli`, `opencode-cli` | Install each agent CLI if missing. |
| `claude-plugins` | Restores user-scope plugins from `home/.claude/plugins-snapshot.json`. |
| `projects-scaffold` | Creates empty `~/Projects` buckets. |
| `mcp-repos` | Clones searxNcrawl to `~/Projects/tools/searxNcrawl` for the crawler MCP. |
| `secrets` | Decrypts `secrets/env.sops.yaml` into `~/.config/secrets/env.sh` via 1Password. |
| `doctor` | Checks tooling, agent CLIs, dotfile drift, secrets, gh, MCP paths, plugins. |

If macOS rejects Safari or Accessibility preference writes, check the reported
domains and the terminal's Full Disk Access permission, then retry `mise run macos`.

## Another machine

Copy `mise.macos.toml` to `mise.<machine>.toml`, keep the entries that apply,
and pin it on that host: `printf 'env = ["<machine>"]\n' > ~/.config/mise/miserc.toml`.
Run `MACHINE=<machine> ./bootstrap.sh`, or `mise trust` both files and `mise bootstrap`.

## Secrets (sops + age)

Encrypted values live in `secrets/env.sops.yaml` (committed as ciphertext). The
age **private key never enters this repo or a local key file**. Sops retrieves it
from 1Password with `SOPS_AGE_KEY_CMD` when needed.

One interactive step on a new machine: open the 1Password app, sign in, and enable
**Settings → Developer → "Integrate with 1Password CLI"**. After that,
`mise run secrets` lets sops call `op read` to fetch the key (the first call can
prompt for Touch ID). The check reads the key and discards it, so the desktop app
can approve it; `op whoami` is not used because it can report no session before
the app authorizes a command. `env.sh` is replaced only after every file decrypts;
a failure keeps the previous file.

```sh
OP_AGE_REF="op://Private/sops/SOPS_PRIVATE_KEY"   # default; override per machine via env
sops secrets/env.sops.yaml      # opens decrypted in $EDITOR, re-encrypts on save
mise run secrets                # regenerate ~/.config/secrets/env.sh
```

Keys in `secrets/env.sops.yaml`: `CLOUDFLARE_API_TOKEN`, `HA_ACCESS_TOKEN`, `SEARXNG_URL`, `CONTEXT7_API_KEY`,
`GITHUB_TOOLSETS`, `CAMOFOX_API_KEY`, `ORCAROUTER_API_KEY`, `JIRA_API_TOKEN`, `ORCA_KEY`.
The agents' MCP servers inherit them from the login-shell environment. **This repo
is public**: the internal SearxNG URL and all tokens stay in the encrypted files.

## GitHub accounts by directory

`home/.local/bin/gh` is linked to `~/.local/bin/gh`. It selects a saved GitHub
account from the current directory, including subdirectories:

| Profile | Directory | GitHub account |
| --- | --- | --- |
| `github-personal` | `~/Projects/personal/` | `DylansDecoded` |
| `github-rnp` | `~/Projects/work/robots-and-pencils/` | `dylan-robson-rp` |

The launcher reads the account's token from `gh` credential storage and passes
it to that command only. It overrides inherited `GH_TOKEN` and `GITHUB_TOKEN`
inside these trees, so personal and work shells can run at the same time.
Other directories use normal `gh` account selection. Git commit identities
remain controlled by `home/.config/git/config` includes; SSH keys and host aliases
remain in the machine-local `~/.ssh/config`.

On a new machine, run `gh auth login --hostname github.com` once for each
account. A missing account causes commands in its tree to fail instead of using
the other account. `gh auth` management commands pass through without token
overrides. The launcher works in scripts as well as shells when `~/.local/bin`
precedes Homebrew on `PATH`; calling Homebrew's `gh` by absolute path bypasses it.

## Agents

- One instruction file, `home/AGENTS.md`, reached as `~/.claude/CLAUDE.md`,
  `~/.codex/AGENTS.md`, `~/.pi/agent/AGENTS.md`, and `~/.config/opencode/AGENTS.md`
  through repo-internal links.
- One skills tree, `home/.agents/skills/`, linked to `~/.agents/skills` (Codex,
  OpenCode, Pi) and `~/.claude/skills` (Claude Code). A skill created or installed
  there lands in the repo directly.
- `advisor-strategy` is a git submodule; clone with `--recurse-submodules`.

## Manual post-install steps

- **1Password**: sign in and enable CLI integration (see Secrets). The 1Password SSH
  agent backs git/ssh auth (`SSH_AUTH_SOCK` is set in `zprofile`).
- **SSH config**: `~/.ssh/config` is intentionally not tracked.
- **OAuth re-auth**: Gmail, Google Calendar, Vercel, and Google Tasks MCP integrations.
  Google Tasks: follow `home/.agents/skills/gtasks/SETUP.md`.
- **Apps outside Homebrew**: see `macos/applications.csv`.
- **crawler MCP**: if the repository moves, run `CRAWLER_REPO_URL=<clone-url> mise run mcp-repos`.
- **Firstmate FM_HOME**: private; see [docs/fm-home-backup.md](docs/fm-home-backup.md).

## Keeping snapshots current

```sh
brew bundle dump --force --file=macos/Brewfile
jq '{plugins: (.plugins | keys)}' ~/.claude/plugins/installed_plugins.json \
  > home/.claude/plugins-snapshot.json   # then re-add the _comment field
```

## Tests

`python3 -m unittest discover -s tests -v` covers the secrets, bootstrap, Grok
installer, and gh launcher behaviour in a temporary home without real secrets.
Run `mise run doctor` to check this Mac after installation.
