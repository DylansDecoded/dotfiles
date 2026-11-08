# Post-wipe Mac restore

End-to-end order to redeploy this machine after a clean macOS install.
Dotfiles restore the toolchain and agent wiring. Git remotes, 1Password, and
provider logins restore identity. Firstmate home and Projects restore fleet
memory and code checkouts.

Related: [docs/projects-layout.md](docs/projects-layout.md),
[docs/fm-home-backup.md](docs/fm-home-backup.md), [README.md](README.md).

## Suggested fresh-Mac order (post-wipe)

1. Install macOS → user account → enable FileVault.
2. Install 1Password → sign in → CLI integration
   (Settings → Developer → Integrate with 1Password CLI).
3. `curl -fsSL https://raw.githubusercontent.com/DylansDecoded/dotfiles/main/bootstrap.sh | bash`
   (or `git clone --recurse-submodules git@github.com:DylansDecoded/dotfiles.git ~/dotfiles && ~/dotfiles/bootstrap.sh`).
4. New login shell → `mise run doctor`.
5. `gh auth login` (DylansDecoded; add R&P when needed).
6. Claude / Codex sign-in.
7. Verify the crawler repo installed by `mise bootstrap` (retry with `mise run mcp-repos` if needed).
8. Clone hot repos into the Projects layout created by `mise bootstrap`.
9. Restore FM_HOME private backup; start firstmate.
10. Clone/link second-brain; open Obsidian.
11. Verify one agent turn.

## What each step restores

| Step | Restores | Does not restore |
| --- | --- | --- |
| 3 `bootstrap.sh` | Brew packages, linked configs, agent CLIs, shared skills, MCP env secrets | OAuth tokens, chat sessions |
| 5 `gh auth` | GitHub API/git HTTPS as that user | Other hosts until you add them |
| 6 provider sign-in | Model access for each CLI | Prior local credential files |
| 7 `mcp-repos` | Code deps for local MCP servers (e.g. searxNcrawl) | Running SearxNG service itself |
| 8 Projects | Empty bucket dirs + your clones | Unpushed WIP unless you backed it up |
| 9 FM_HOME | Fleet backlog, captain prefs, task data | Live worker panes |
| 10 second-brain | Vault knowledge | NotebookLM / Google side state |

## Before you wipe (source machine)

1. Commit and push this repo (`main` or merge the restore-pack PR).
2. `brew bundle dump --force --file=macos/Brewfile` and commit if changed.
3. Refresh Claude plugin snapshot (see README).
4. Confirm `sops secrets/env.sops.yaml` has real values (still ciphertext in git).
5. `mise run doctor` green on the source machine.
6. Private backup of Firstmate home (`config/` + `data/`; optional selective `state/`).
   See [docs/fm-home-backup.md](docs/fm-home-backup.md).
7. Confirm product branches and second-brain exist on remotes or the laptop.
8. Export SSH host aliases if you rely on `~/.ssh/config` (not tracked here).

## After `mise bootstrap`

```sh
mise run doctor
# Retry mise run mcp-repos or mise run projects-scaffold if bootstrap reported a failure.
# Clone hot repos into the buckets (see docs/projects-layout.md).
```

### GitHub multi-account

- Personal product repos: `gh auth login` as DylansDecoded (HTTPS origin).
- R&P repos: separate login or `github-rnp` SSH host; do not assume one login sees both.
- Prefer HTTPS + `gh` for personal private repos when the default SSH key is a work account.

### Agent auth notes

- Do not commit `~/.config/anthropic/credentials/`.
- Re-run provider login if every agent turn fails with credentials ENOENT/EACCES.

### Firstmate FM_HOME

Dotfiles do not store FM_HOME (private fleet memory). After Projects exist:

1. Clone firstmate code (often `~/Projects/tools/firstmate`).
2. Restore the private backup into that home's `config/` and `data/` (and `projects/` links).
3. Open a primary session and run the home's session-start path.
4. Re-attach remote secondmates from `data/secondmates.md` if present.

### Second-brain

Canonical path: `~/Projects/personal/second-brain` (or `~/Projects/knowledge/second-brain` if you adopt that bucket).
Open the folder as an Obsidian vault. Do not commit vault content into public dotfiles.

## Verify one agent turn

```sh
claude --version
claude -p "reply with ok"   # confirm a reply
```

If doctor is green but agents fail, the problem is almost always provider login or MCP path (run `mise run mcp-repos`).
