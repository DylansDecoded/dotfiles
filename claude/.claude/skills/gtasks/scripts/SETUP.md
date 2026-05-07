# gtasks skill — one-time setup

Run these once on a new machine. After this, the skill works from any Claude Code session.

## 1. Install `uv`

The script uses [`uv`](https://docs.astral.sh/uv/) to resolve its inline dependencies on first run.

```bash
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
```

## 2. Create OAuth credentials in Google Cloud Console

1. Go to <https://console.cloud.google.com/>.
2. Create or select a project.
3. **APIs & Services → Library** → search "Tasks API" → enable.
4. **APIs & Services → OAuth consent screen** → configure as External, add yourself as a test user.
5. **APIs & Services → Credentials** → **Create credentials** → **OAuth client ID** → application type **Desktop app** → create.
6. Download the JSON for the OAuth client.

## 3. Place the OAuth client file

```bash
mkdir -p ~/.config/gtasks && chmod 700 ~/.config/gtasks
mv ~/Downloads/client_secret_*.json ~/.config/gtasks/oauth-keys.json
```

## 4. Run the auth flow

```bash
~/.claude/skills/gtasks/scripts/gtasks.py auth
```

A browser opens for Google sign-in. After approval, credentials are saved to `~/.config/gtasks/credentials.json` (mode 0600). Output is JSON: `{"ok": true, "credentialsPath": "..."}`.

## 5. Smoke test

```bash
~/.claude/skills/gtasks/scripts/gtasks.py list-tasklists
```

You should see a JSON object with your task lists.

## Notes

- **OAuth scope:** full read/write to Google Tasks (`https://www.googleapis.com/auth/tasks`).
- **Override config dir:** set `GTASKS_CONFIG_DIR=/some/path` to relocate `oauth-keys.json` and `credentials.json`.
- **Re-auth:** if the script reports `code: "AUTH_MISSING"` (e.g. token revoked), delete `~/.config/gtasks/credentials.json` and re-run step 4.
- **Independent of the gtasks-mcp repo:** this skill does not read from `~/Projects/personal/mcps/gtasks-mcp` and does not use the legacy `.gtasks-server-credentials.json` file.
