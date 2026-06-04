# dotfiles

Personal macOS developer environment: shell, terminal, editors, window manager,
git, and the LLM/agent toolchain (Claude Code, Codex, opencode, Gemini). Managed
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
| `just claude-plugins` | Restores the 13 user-scope plugins from `claude/.claude/plugins-snapshot.json`. |
| `just age-key` | Pulls the sops age private key from 1Password into `~/.config/sops/age/keys.txt`. |
| `just secrets` | Runs `age-key`, then decrypts `secrets/env.sops.yaml` into `~/.config/secrets/env.sh` (sourced by `.zprofile`). |
| `just doctor` | Verifies a deployed machine (tooling, symlinks, secrets, 1Password, plugins). |

The op-gated steps (`age-key`, `secrets`) run last in `install` so an un-ready 1Password
doesn't block the rest. Enable 1Password CLI integration, then re-run `just install`.

## Secrets (sops + age)

Encrypted values live in `secrets/env.sops.yaml` (committed as ciphertext). The
age **private key never enters this repo** — it's escrowed in 1Password and lands at
`~/.config/sops/age/keys.txt` on each machine.

On a new machine, one interactive setup step that can't be scripted: open the 1Password
app, sign in, and enable **Settings → Developer → "Integrate with 1Password CLI"**. After
that, `just secrets` (run automatically by `just install`) calls `op read` to restore the
key — the first call prompts Touch ID — then decrypts the secrets. No manual `op` commands.

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

Keys captured: `SEARXNG_URL`, `CONTEXT7_API_KEY`, `GITHUB_TOKEN`, `GITHUB_TOOLSETS`.
They are consumed by the MCP servers in Claude Code, Codex, opencode, and Gemini,
which inherit them from the login-shell environment. **This repo is public** — the
internal SearxNG URL and all tokens stay only in the encrypted file, never in the
plaintext tool configs.

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
- **OAuth re-auth**: Gmail, Google Calendar, Vercel, and Google Tasks MCP integrations
  need re-authentication. Google Tasks: follow `claude/.claude/skills/gtasks/SETUP.md`.
- **Apps outside Homebrew**: see `macos/applications.csv`. `mac-app-store` apps reinstall
  from the App Store; `direct-download` apps must be fetched from their vendors.
- **searxncrawl MCP**: the `~/.local/bin/searxncrawl-mcp` binary is an external build,
  not tracked here. Rebuild/reinstall it separately, or the searxncrawl MCP server will
  fail to start.

Not tracked (set up separately if wanted): Neovim, tmux, VS Code `settings.json`.

## Keeping snapshots current

```sh
# Brewfile — after installing/removing brews, casks, or extensions:
brew bundle dump --force --file=macos/Brewfile

# Claude plugin list:
jq '{plugins: (.plugins | keys)}' ~/.claude/plugins/installed_plugins.json \
  > claude/.claude/plugins-snapshot.json   # then re-add the _comment field
```

## Notes

- Packages stowed: `aerospace claude codex direnv fish gemini ghostty git mise
  opencode ssh starship zellij zsh`. `macos/` and `secrets/` are not stow packages.
- On a machine that already has real (non-symlink) config files, `just stow` will
  report conflicts instead of clobbering them. Remove the pre-existing file, or
  reconcile manually, then re-run.
