---
name: obsidian-axi
description: "Read, search, write and organise notes in an Obsidian vault - list files, read notes, full-text and tag search, create and append notes, patch a heading section or frontmatter field, delete and rename notes, inspect backlinks and broken links, and list tags. Use whenever a task touches an Obsidian vault, markdown notes, a personal knowledge base, or a Zettelkasten. Works straight from the filesystem with no plugin, no server and no API key, whether or not Obsidian is running."
user-invocable: false
author: Anders Hoffmann
metadata:
  hermes:
    tags: [obsidian, notes, markdown, knowledge-base, search]
    category: productivity
---

# obsidian-axi

Agent ergonomic CLI for Obsidian vaults - read, search, write, and link notes. Use this instead of reading or grepping vault files yourself.

Nothing needs installing. Run it with `npx -y @andershoffmann/obsidian-axi <command>`.
If the output suggests a follow-up command starting with `obsidian-axi`, run that as
`npx -y @andershoffmann/obsidian-axi ...` instead.

There is no setup. It reads the vault straight from disk, so it needs no plugin, no server
and no API key, and it works whether or not Obsidian is running.

## When to use

Any task involving an Obsidian vault or a folder of markdown notes. That covers listing and
reading notes, searching by text or tag or frontmatter field or date, creating and appending
to notes, editing a single heading section or block or frontmatter field in place, deleting
and renaming notes, checking backlinks and broken links and orphans, and listing tags.

## Workflow

1. Run `npx -y @andershoffmann/obsidian-axi` with no arguments first. It shows which vault it resolved
   and what changed recently.
2. Find things with `search <query>`. Narrow it with `--tag`, `--path`,
   `--frontmatter k=v` or `--modified-since 7d`. Add `--context 2` for surrounding lines.
3. Read with `read <path>`, or several at once with `read a.md b.md`. Bodies stop at 1000
   characters. Use `--full` for everything, or `--metadata` when you only need frontmatter
   and counts.
4. Prefer `patch` over `write`. It changes one part of a note instead of replacing it.
5. To use a different vault, put `--vault <name|path>` after the command. Flags before the
   command are rejected. `vault list` shows what is available.
6. Every response ends with `help:` suggestions. Follow them.

## Commands

```
commands[16]:
  (none)|home=dashboard, ls, read, search, recent, write, append, patch, rm, mv,
  links, tags, active, open, vault, setup
```

A globally installed copy also gets the SDK's `update` command. Run
`obsidian-axi update --check` to compare it against npm. With `npx -y @andershoffmann/obsidian-axi`
that is unnecessary, since npx resolves the package each time.

Run `npx -y @andershoffmann/obsidian-axi --help` for the global flags, or
`npx -y @andershoffmann/obsidian-axi <command> --help` for one command.

## Things to know

- Output is TOON, which is compact already. Only pipe through grep or head when a list is
  genuinely long. Lists include a `count:` line, so you rarely need a second call just to
  count something.
- List rows carry several columns on purpose. If you only want paths, `--fields path` cuts
  about a quarter. The bigger saving is `read --metadata`, which answers "what tags does
  this note have and how big is it" without pulling in the body.
- Exit codes: 0 worked, including no-ops. 1 something failed. 2 the command was wrong.
  Errors print to stdout as TOON with a `code:` and a suggestion.
- `-h` does nothing. Use `--help`, and at the top level it has to be the only argument.
- Writes are safe to retry. Appending text a note already ends with, deleting a note that is
  already gone, and moving a note onto itself all do nothing and exit 0.
- `patch --target-type heading` only touches that heading's own content and leaves nested
  subsections alone. To write inside a child, name it with `::`, as in
  `--target "Tasks::Today"`. Using `--op delete` removes the heading and everything below
  it.
- Frontmatter patches take their value in the target, so `--target status=done`, not
  `--content`.
- For content with newlines in it, write it to a file and use `--content-file <path>`, or
  pipe it in.
- `rm` moves the note to `.trash` so it can be recovered. `--permanent` deletes it.
- `active` and `recent --opened` read Obsidian's saved workspace file, which is only
  written when the layout changes. Treat them as the last saved state, not what is on screen
  now.
- Dataview, Templater, semantic search and the command palette all need a running Obsidian,
  so they are out of scope. Those return `UNSUPPORTED` rather than guessing.
- If a note is open in Obsidian with unsaved changes, a write here can be overwritten when
  Obsidian next saves. Check `active` first when that matters.
