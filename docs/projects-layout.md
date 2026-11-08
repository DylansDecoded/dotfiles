# Projects layout

Canonical disk layout for code and knowledge on this machine.
Dotfiles do not clone every repo; they define buckets and restore helpers.

## Buckets

```text
~/Projects/
  work/                 # Employer / client (e.g. robots-and-pencils/)
  personal/
    products/           # Optional subfolder for shippable apps
    home/               # Optional: homeassistant, homelab, finance
    … or flat personal/* while migrating
  tools/                # CLIs, MCP servers, firstmate, agent platform
  labs/                 # Experiments; safe to delete
  knowledge/            # Optional: second-brain vault if not under personal/
  .archive/             # Cold storage
  .runtime/             # worktrees, playwright profiles, lavish cache (not products)
```

## Rules

1. Sort by ownership and lifetime, not language.
2. One directory = one git root (unless a true monorepo).
3. Names match GitHub slugs.
4. Agent platform (`firstmate`, searx MCP code) lives under `tools/`, not inside product apps.
5. Firstmate `projects/<name>` entries are symlinks into this tree.

## Hot repos (restore shortlist)

Clone what you need after `mise run projects-scaffold`:

| Repo | Suggested path |
| --- | --- |
| firstmate | `~/Projects/tools/firstmate` |
| searxNcrawl | `~/Projects/tools/searxNcrawl` |
| tangle | `~/Projects/personal/tangle` or `…/products/tangle` |
| second-brain | `~/Projects/personal/second-brain` |
| orbit | `~/Projects/personal/orbit` or under work if applicable |
| roboworks-pantheon | `~/Projects/work/robots-and-pencils/roboworks-pantheon` |
| aws-lakehouse-accelerator | `~/Projects/personal/aws-lakehouse-accelerator` |

## Scaffold

```sh
cd ~/dotfiles && mise run projects-scaffold
```

Creates empty bucket directories only. It does not delete existing trees.
