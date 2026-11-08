---
name: gtasks
description: Use when the user wants to create, list, search, update, complete, delete, or clear tasks in their Google Tasks. Triggers on "add a task", "create a task", "remind me to", "put X on my todo list", "what tasks do I have", "mark X done", "delete the X task", "clear completed tasks", and similar Google Tasks operations.
---

# Google Tasks (gtasks)

Manage Google Tasks via a local Python CLI. The CLI handles auth and the API calls; this skill describes when to invoke each subcommand and how to interpret the JSON response.

## Prerequisites

Before any subcommand, verify auth is set up:

```bash
test -f ~/.config/gtasks/credentials.json
```

If missing, stop and tell the user to follow `~/.claude/skills/gtasks/scripts/SETUP.md`. Do not attempt to run subcommands until credentials exist.

## Calling the CLI

Always invoke by absolute path so it works from any cwd:

```bash
~/.claude/skills/gtasks/scripts/gtasks.py <subcommand> [flags]
```

Output contract: success → single-line JSON on stdout, exit 0. Failure → single-line JSON on stderr (`{"ok": false, "error": "...", "code": "..."}`), non-zero exit. Always parse stdout as JSON; surface stderr as-is to the user on failure.

## Subcommands

| Subcommand | Use when | Key flags |
|---|---|---|
| `list-tasklists` | User names a list ("my Work list") and you need its id. | — |
| `create` | User wants to add a task. | `--title` (required), `--list` (default `@default`), `--due YYYY-MM-DD`, `--notes` |
| `list` | User asks "what's on my list?" or wants to see tasks. | `--list` (optional; omit for all lists), `--cursor` for paging |
| `search` | User asks about a specific task by keyword. | `--query` (required), `--list` (optional) |
| `update` | User wants to mark done, rename, reschedule, or edit notes. | `--id` (required), `--list`, `--title`, `--notes`, `--status` (`needsAction`\|`completed`), `--due` |
| `delete` | User wants to remove a task entirely. | `--id`, `--list` (both required) |
| `clear` | User wants to clear completed tasks from a list. | `--list` (default `@default`) |
| `auth` | First-time setup only — see SETUP.md. | — |

## Choosing a task list

- Default to `@default` (the user's primary list). Pass nothing or `--list @default`.
- If the user names a list by title (e.g. "add to my Work list"), call `list-tasklists` first, find the list whose `title` matches case-insensitively, and use its `id`.
- If multiple lists match, ask the user which one. Don't guess.

## Date handling

You have today's date in env context (`currentDate`). Convert natural language ("tomorrow", "next Friday", "in 3 days") to `YYYY-MM-DD` yourself, then pass `--due YYYY-MM-DD`.

Do not pass times — Google Tasks only stores the date portion, and the CLI normalizes any ISO 8601 input to UTC midnight regardless. If the user gives no date, omit `--due`.

## Marking a task done

Use `update --status completed --id <id> --list <listId>`. Always pass `--id` exactly as returned from `list` or `search`. `update` uses patch semantics — fields you don't pass stay intact, so it's safe to update only `--status`.

## Reporting back

Keep confirmations short and concrete. Examples:
- After `create`: `Added "Call the dentist" to your default list (due 2026-04-30).`
- After `update --status completed`: `Marked "Call the dentist" done.`
- After `delete`: `Removed "Call the dentist".`
- On `code: "AUTH_MISSING"`: tell the user to run setup; do not retry.

## Common mistakes

- Passing a list **title** instead of its `id` to `--list`. Always run `list-tasklists` first when the user named a list.
- Calling `update` without `--id`. Get the id from `list` or `search` output.
- Including a time component in `--due` (e.g. `2026-04-30T15:00:00`). Pass date-only.
- Forgetting that omitted `update` fields are preserved. To clear `notes`, the API needs an explicit empty string; surface this to the user rather than silently dropping data.
