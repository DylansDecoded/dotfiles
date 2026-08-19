# dotfiles

Personal macOS developer environment: shell, terminal, editors, window manager,
git, and base AI applications/CLIs. Managed
with [GNU Stow](https://www.gnu.org/software/stow/), orchestrated with
[`just`](https://github.com/casey/just), secrets encrypted with
[sops](https://github.com/getsops/sops) + [age](https://github.com/FiloSottile/age).

## Fresh Mac deploy

One command on a brand-new machine:

```sh
curl -fsSL https://raw.githubusercontent.com/DylansDecoded/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` installs Xcode Command Line Tools, Homebrew, and the minimal
toolchain (`just stow age sops jq 1password-cli`), clones this repo to
`~/dotfiles`, then runs `just install`.

This repo is intended to be a full, idempotent restore path for a new machine.
AI tools are installed without repository-owned configuration so they start from
their vendor defaults.

If you already have the repo checked out:

```sh
cd ~/dotfiles && just install
```

## Recipes

`just` with no argument lists everything. The pieces, in the order `install` runs them:

| Recipe | What it does |
| --- | --- |
| `just brew` | `brew bundle` — all brews, casks, fonts, VS Code extensions from `macos/Brewfile`. |
| `just stow` | Symlinks every package into `$HOME`. Dry-runs first. |
| `just macos` | Runs `macos/defaults` (Dock, Finder, trackpad, screenshots, etc.). |
| `just claude-cli` | Installs the Claude Code CLI if missing. |
| `just codex-cli` | Installs the Codex CLI if missing. |
| `just grok-cli` | Installs the Grok CLI if missing. |
| `just opencode-cli` | Installs the OpenCode CLI if missing. |
| `just pi-cli` | Installs the Pi coding-agent CLI if missing. |
| `just secrets` | Decrypts `secrets/env.sops.yaml` into `~/.config/secrets/env.sh` (sourced by `.zprofile`). Keyless — sops fetches the age key live from 1Password via `SOPS_AGE_KEY_CMD`. |
| `just doctor` | Verifies a deployed machine (tooling, symlinks, secrets, 1Password, and installed CLIs). |

Every recipe also exists as a **mise task** (`mise.toml` at the repo root) during the
migration to mise-based orchestration: `mise run install`, `mise run stow`,
`mise run secrets`, `mise run doctor`, etc. Run `mise tasks` to list them. Both runners
work; `just` remains the canonical path until the migration completes.

The op-gated `secrets` step runs last in `install` so an un-ready 1Password
doesn't block the rest. Enable 1Password CLI integration, then re-run `just install`.

## Secrets (sops + age)

Encrypted values live in `secrets/env.sops.yaml` (committed as ciphertext). The
age **private key never enters this repo and never touches disk** — sops (>= 3.10)
fetches it live from 1Password via `SOPS_AGE_KEY_CMD` (exported in `.zprofile`).

On a new machine, one interactive setup step that can't be scripted: open the 1Password
app, sign in, and enable **Settings → Developer → "Integrate with 1Password CLI"**. After
that, `just secrets` (run automatically by `just install`) decrypts the secrets — the
first `op` call prompts Touch ID. No manual `op` commands.

The 1Password reference is configurable; the default assumes the `Private` vault:

```sh
# default baked into the Justfile — override per-machine via env if yours differs
OP_AGE_REF="op://Private/sops/SOPS_PRIVATE_KEY"   # item "sops", field "SOPS_PRIVATE_KEY"
```

To edit or fill secret values (the API keys ship as `REPLACE_ME` placeholders):

```sh
cd ~/dotfiles
sops secrets/env.sops.yaml      # opens decrypted in $EDITOR, re-encrypts on save
just secrets                    # regenerate ~/.config/secrets/env.sh
```

Keys captured: `SEARXNG_URL`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `GITHUB_TOOLSETS`, `CAMOFOX_API_KEY`.
They are exported to the login-shell environment. **This repo is public** — the
internal SearxNG URL and all tokens stay only in the encrypted file.

## AI tools

`just install` installs the supported AI CLIs, but this repository intentionally
tracks none of their configuration. There are no shared instructions, skills,
plugins, hooks, MCP definitions, themes, model settings, or custom launchers.
Each tool creates its own default local state on first launch.

## Manual post-install steps

Not automated (interactive, secret, or external):

- **1Password**: sign in to the app and enable CLI integration (see Secrets above). The
  1Password SSH agent backs all git/ssh auth (`SSH_AUTH_SOCK` is set in `.zprofile`);
  private keys live there, not on disk. The age key is restored from 1Password by
  `just secrets` once integration is enabled.
- **SSH config**: `~/.ssh/config` is a stowed package (`ssh/.ssh/config`) — host aliases
  only (`github.com`, `github-work` for the `git/config-work` URL rewrite, MyNymBox), no
  private key material; the 1Password agent serves the actual keys. The `1Password/config`
  include is also tracked, but the 1Password app **regenerates it per machine**: if the app
  has already written `~/.ssh/1Password/config`, `just stow` reports a conflict — remove the
  live file first, then re-stow. Expect the app to rewrite it afterward (occasional git
  churn on `ssh/.ssh/1Password/`).
- **Apps outside Homebrew**: see `macos/applications.csv`. `mac-app-store` apps reinstall
  from the App Store; `direct-download` apps must be fetched from their vendors.

Not tracked (set up separately if wanted): Neovim, tmux, VS Code `settings.json`.

## Keeping snapshots current

```sh
brew bundle dump --force --file=macos/Brewfile
```

## Notes

- Packages stowed: `aerospace direnv fish ghostty git mise starship zellij zsh`.
  `macos/` and `secrets/` are not stow packages.
- On a machine that already has real (non-symlink) config files, `just stow` will
  report conflicts instead of clobbering them. Remove the pre-existing file, or
  reconcile manually, then re-run.
