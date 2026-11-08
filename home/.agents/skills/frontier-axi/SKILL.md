---
name: frontier-axi
description: Track unresolved feature requirements and architecture questions with frontier-axi, record settled answers, and promote ready work into tasks-axi. Use for persistent planning frontiers or explicit frontier-axi requests.
---

# Frontier AXI

Local adapter for https://github.com/oguzalp7/frontier-axi (upstream has no skill).

Run `frontier-axi --help` for commands and `<command> --help` for arguments.
The local CLI is built at `~/.local/share/frontier-axi` and linked from `~/.local/bin/frontier-axi`.
On another machine, clone the upstream repository, run `npm ci --ignore-scripts` and `npm run build`, then run `node dist/bin/frontier-axi.js` from that checkout.

Run commands from the target project. Storage uses `.frontier.toml` and a generated `frontier.md` view. Use `--file <path>` or `FRONTIER_FILE` for another store.

1. Inspect the dashboard with `frontier-axi` and existing items with `frontier-axi list`.
2. Inspect an item with `frontier-axi show <id> --full`.
3. Stage a topic with `frontier-axi add <id> "<title>" --body "<requirements>"`.
4. Record questions with `frontier-axi question add <id> "<question>"`.
5. Record supported answers with `frontier-axi question resolve <id> <number> --answer "<answer>"`. Distinguish observed facts from decisions that need user input.
6. Preview promotion with `frontier-axi promote <id> --dry-run`. Inspect the generated acceptance criteria for concrete, verifiable outcomes before promotion.
7. When ready and within the requested scope, use `frontier-axi promote <id>`. This invokes the separate `tasks-axi` CLI and changes the backlog. Do not use `--force` to bypass unresolved questions by default.

Use `done`, `cancel`, and `reopen` for item lifecycle changes. Inspect command help before changing unfamiliar fields.
