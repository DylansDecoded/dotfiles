---
name: outline-content
version: 1.0.0
description: "Turn a content idea into a platform-neutral outline — working title, hook/angle, ordered key points, and references. With no topic, it reads the newest morning-report digest in the Obsidian inbox and outlines the top idea from its 'Worth Writing About' shortlist; pass a topic to outline that instead. Use whenever the user wants to outline something to write or record, or says things like 'outline this', 'outline content', 'draft an outline', 'outline the top idea', 'outline the top idea from today's digest', 'turn the digest into an outline', or 'what should I write about and how'. This is the bridge between the morning-report scan and the adapt-for-platform drafter — fire it after a scan to move an idea toward production."
---

# Outline Content v1.0.0

Take one content idea and produce a tight, platform-neutral outline the user can hand to `adapt-for-platform` (which shapes it into a YouTube script, tweet thread, LinkedIn post, or blog). The outline captures *what the piece says and in what order* — not how a specific platform formats it. Keeping it neutral means one outline can feed every platform without being un-shaped first.

## Where the idea comes from

Two modes, decided by whether the user named a topic:

**Mode A — no topic given (default).** Pull the top idea from today's scan.
1. Find the newest digest: glob `/Users/dylan/Projects/personal/obsidian/Inbox/*-morning-report.md` and take the file with the latest date in its name.
2. Read it and parse the `## Worth Writing About` section — a numbered list, ranked best-first, where each item is a **bold title/angle** + a one-line "why now", followed by a `Sources:` sub-bullet of links.
3. Outline item 1 (the strongest idea). If the user asked for more ("outline the top 3"), outline that many, each as its own outline.
4. Carry that item's `Sources:` links through into the outline's references — they're the evidence the idea is built on.

**Mode B — topic given.** The user names a subject ("outline a video on MCP server security"). Skip the digest entirely and outline that topic directly. Do a light bit of research if the topic is thin and you'd otherwise be guessing, but don't turn this into a deep-research run — the user wants an outline, fast.

### When the digest isn't there

If no `*-morning-report.md` file exists, or the newest one has an empty or missing `## Worth Writing About` section, don't invent an idea. Say so plainly and ask the user for a topic (or suggest they run a morning scan first). A fabricated outline built on nothing wastes their time and erodes trust in the chain.

## The outline

Keep it lean — an outline is a skeleton, not a draft. The user fills in the prose later (or `adapt-for-platform` does). Aim for something they can look at and immediately know what the piece argues and in what order.

Use this structure:

```markdown
# [Working title]

**Angle:** [one sentence — the specific take or promise. Not "a video about X" but "why X breaks the way everyone sets it up, and the 3-line fix"]

**Hook:** [the opening beat — the first thing said/shown that earns the next 30 seconds. A question, a claim, a surprising result.]

## Key points
1. **[Point]** — [what it covers, one line]
2. **[Point]** — [what it covers, one line]
3. **[Point]** — [what it covers, one line]
   (as many as the idea needs — usually 3–6)

**Payoff:** [what the audience walks away with — the takeaway or the thing they can now do]

## References
- [Source link carried from the digest, or found while researching a given topic]
- [...]
```

Notes on the shape:
- **Working title** is a real, usable title, not a placeholder — it's the first thing the user judges the idea by. Make it specific.
- **Angle** is the load-bearing field. A weak angle produces a generic piece. Push for the specific, opinionated take the user (a data/AI engineer moving into AI engineering, who publishes on Claude Code / Codex / LLM topics) would actually stand behind.
- **Key points** are ordered — the sequence is the argument. Don't just list subtopics; put them in the order that builds.
- **References** must be real. In Mode A carry the digest's `Sources:` links verbatim. In Mode B include only links you actually found. Never fabricate a URL.

## Save it

Write the outline to the Obsidian inbox alongside the digests:

**Path:** `/Users/dylan/Projects/personal/obsidian/Inbox/YYYY-MM-DD-outline-<slug>.md`

- `<slug>` is a short kebab-case version of the working title (e.g. `mcp-server-security`).
- Use today's date. If that exact file already exists, append `-2`, `-3`, etc. — never overwrite.
- The `-outline.md` suffix and dated filename are a contract with `adapt-for-platform`, which finds outlines by globbing `Inbox/*-outline*.md`. Keep the suffix and date stable.

> **Placeholder — revisit in Part 2 (Obsidian memory layer).** The inbox path mirrors `morning-report`'s and isn't finalized. If the vault's inbox moves, update this path and `adapt-for-platform`'s glob together.

Then show the outline in chat too, so the user can react without opening the file. If you outlined multiple ideas, save each to its own file and show them in order.

## What NOT to do

- Don't shape the outline for a specific platform — no "intro/outro", no "tweet 1/2/3", no word counts. That's `adapt-for-platform`'s job. Staying neutral is the whole point of this step.
- Don't write the full piece. An outline that's really a first draft is slower to skim and harder to restructure.
- Don't fabricate references or invent an idea when the digest is empty — ask instead.
- Don't run a deep-research pass for a Mode B topic. Light grounding only; keep it fast.
