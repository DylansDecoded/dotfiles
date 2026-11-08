---
name: graphify-crew
description: Query the shared graphify code graph before grepping or reading source when working in a repo that has one (ToyBox / di-toybox-data-agent today). Use at the start of any task that needs to locate code, callers, definitions, or data flow in a large repo.
---

# graphify-crew

A code knowledge graph for this repo lives OUTSIDE the worktree in a shared cache. Use it to find code instead of grepping; it costs under 2k tokens per query.

## 1. Resolve the graph

```sh
repo=$(basename -s .git "$(git remote get-url origin)")
graph=$HOME/.cache/graphify/$repo/graphify-out/graph.json
[ -f "$graph" ] || echo "no graph for $repo"
```

If the file is absent, skip this skill and work normally. Never build or update a graph from inside a worktree (`graphify extract` / `graphify update` are run from the primary clone by `graphify-refresh-<repo>`).

## 2. Query before the first grep or read

For any "where is / what calls / what depends on" question, run this before grep, find, or reading a source file:

```sh
GRAPHIFY_QUERY_LOG_ENABLE=1 graphify query "<question in the repo's own vocabulary>" --graph "$graph"
```

- Use identifiers, file names, and domain nouns that exist in the code (e.g. `featureFlags`, `accessRegistry`, `buildDuckdbInitStatements`), not prose.
- Exit 0: use the `NODE … [src=file loc=Ln]` and `EDGE … at=file:loc` lines to open only those files at those lines.
- Exit 3 (ambiguous): retry once with a narrower name. Exit 4 or empty output: fall back to grep immediately. Do not loop on the graph.
- `GRAPHIFY_QUERY_LOG_ENABLE=1 graphify path "A" "B" --graph "$graph"` for call or data flow between two symbols; `GRAPHIFY_QUERY_LOG_ENABLE=1 graphify explain "X" --graph "$graph"` for one symbol.
- Queries are logged to `~/.cache/graphify-queries.log` so hit rate can be measured; leave the env prefix in place.

## 3. Rules

- Read raw files only at the lines the graph (or an earlier read) located.
- Do not read `GRAPH_REPORT.md` unless the task is an architecture review.
- The graph is a snapshot of `origin/main`. If a located line does not match the file, trust the file and continue; do not rebuild.
- Put this instruction in any subagent prompt that explores code.
- In your final report, state how many graph queries you ran and how many hit.
