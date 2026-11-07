# Firstmate home private backup

FM_HOME holds captain-private fleet state (`config/`, `data/`, optional `state/`).
It must not be committed to the public dotfiles repo.

## What to back up

Include:

- `config/` (dispatch, harness pins, budgets)
- `data/` (captain prefs, backlog, briefs, reports, learnings, migration notes)
- `data/projects.md`, `data/secondmates.md`

Optional:

- Selective `state/` (open decisions). Prefer fresh state after restore if workers are gone.

Exclude:

- Live locks, watchers, huge logs
- Secrets that already live in 1Password / sops env
- `projects/` clones (re-link from Projects layout)

## Example archive (source machine)

```sh
FM_HOME="${FM_HOME:-$HOME/Projects/tools/firstmate}"
ts=$(date +%Y%m%d)
tar -C "$FM_HOME" -czf "$HOME/Desktop/fm-home-$ts.tgz" config data
# encrypt or copy to the laptop / external drive
```

## Restore

```sh
FM_HOME="$HOME/Projects/tools/firstmate"
mkdir -p "$FM_HOME"
tar -C "$FM_HOME" -xzf fm-home-YYYYMMDD.tgz
# re-link projects/* into ~/Projects/...
```

Then start firstmate from that home and run session start.
