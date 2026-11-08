# Budget Check-in — not configured yet

I can't run the check: no config file at `~/.config/budget-checkin/config.json`. I won't guess at numbers, so let's set it up (one-time, ~2 minutes).

**1. Create the config**

```bash
mkdir -p ~/.config/budget-checkin
cat > ~/.config/budget-checkin/config.json <<'EOF'
{
  "source": "actual",
  "actual": {
    "serverURL": "http://localhost:5006",
    "password": "FILL_ME_IN",
    "syncId": "FILL_ME_IN",
    "encryptionPassword": null
  }
}
EOF
chmod 600 ~/.config/budget-checkin/config.json
```

**2. Fill in the two values**

- `serverURL`: your Actual Budget server (default above is a local install).
- `syncId`: in Actual, Settings → Show advanced settings → Sync ID.
- Password: prefer the `ACTUAL_PASSWORD` env var over putting it in the file. If it goes in the file, the `chmod 600` above keeps it private either way.

**3. Install the Actual API package (first run only)**

```bash
npm install --prefix ~/.claude/skills/budget-checkin/scripts
```

No Actual server? Set `"source": "fixture"` with `"fixture": { "path": "/path/to/normalized.json" }` to demo against a static file instead.

Once that's done, say "budget check" again and I'll run the real thing.
