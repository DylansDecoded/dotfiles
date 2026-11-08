---
name: adapt-for-platform
version: 1.0.0
description: "Reshape a content outline or writeup into a platform-ready draft — YouTube long-form script, X/Twitter thread, LinkedIn post, or blog post. With no source given, it uses the newest outline in the Obsidian inbox; you can also paste or name a source. Use whenever the user wants to turn an idea, outline, or draft into a specific platform's format, or says things like 'make this a thread', 'turn this into a LinkedIn post', 'adapt for YouTube', 'write this up as a blog post', 'adapt the outline for X', 'platform-ify this', or 'draft the newest outline as a video script'. This is the last step of the content pipeline after morning-report (scan) and outline-content (outline) — fire it to take an idea to a publishable draft."
---

# Adapt for Platform v1.0.0

Take one idea — usually a platform-neutral outline from `outline-content` — and turn it into a draft shaped for a specific platform. The outline says *what* the piece argues and in what order; this skill decides *how* it's said for YouTube, a thread, LinkedIn, or a blog. The angle, the ordered key points, and the references survive the reshaping; only the form changes.

## Step 1: Resolve the source

- If the user pasted text or named a file, use that.
- Otherwise, default to the newest outline in the inbox: glob `/Users/dylan/Projects/personal/obsidian/Inbox/*-outline*.md` and take the file with the latest date in its name. Read it.
- If no outline exists and the user gave no source, say so and ask for one (or suggest running `outline-content` first). Don't invent content to adapt — a platform draft built on nothing is worse than no draft.

A source can also be a fuller writeup, not just an outline. Same job: preserve its argument and sources, reshape the form.

## Step 2: Get the target platform

The platform decides everything about the shape, so it can't be guessed. If the user named one ("make this a thread", "adapt for YouTube"), use it. If they didn't, ask — this is the one question worth stopping for:

> Which platform — YouTube long-form, X/Twitter thread, LinkedIn post, or blog post?

## Step 3: Shape to the platform

Preserve across every platform: the **angle** (the specific take), the **ordered key points** (the sequence is the argument), and the **references** (carry the source links through — a data-engineering audience checks them). What changes is length, rhythm, and structure.

### YouTube long-form
A spoken-style script — write how someone talks, not how they write. Include:
- **Title** — specific and clickable without being clickbait.
- **Script** — open with the hook in the first 10 seconds (no "hey guys, welcome back"), then move through the key points as segments with natural spoken transitions, and close with a short outro + one call to action.
- **Description** — 2–3 sentence summary, then the reference links as resources.

### X/Twitter thread
- Numbered tweets, each standalone-readable, each under ~280 characters (count them — an overflowing tweet breaks the thread).
- **Tweet 1 is the whole game**: it earns the click to expand. Lead with the angle or the surprising result, not a throat-clear.
- One idea per tweet; let the key points map to tweets. End with a takeaway tweet, and put reference links in a final tweet (links mid-thread suppress reach).

### LinkedIn post
- **Hook line** first — one line that survives the "see more" truncation and makes someone expand it.
- Short paragraphs (1–3 lines), whitespace between them; no walls of text.
- Professional but not stiff — the voice below still applies.
- End with a **soft CTA** — a question or invitation to discuss, not "smash follow". Drop reference links at the end or as a comment note.

### Blog post
- Headed sections (`##`) following the key points, with a real intro that sets up the angle and a conclusion that pays it off.
- Room to breathe — this is the long form, so develop the points rather than compressing them.
- Inline the references as markdown links where they support a claim, and/or a closing references list.

## Step 4: Voice

Write as the user would: a data architect / data engineer moving into AI engineering, publishing on Claude Code, Codex, and LLM topics. That means technically precise, opinionated, concrete — specifics and real tool names over hype. Avoid the generic-AI-blog register.

After drafting, run the **`humanizer`** skill on the text to strip AI-tell patterns (the "it's not just X, it's Y" constructions, empty intensifiers, uniform paragraph rhythm). This is a real quality gate, not a formality — a draft that reads as AI-generated undercuts the user's credibility with a technical audience. If `humanizer` isn't available for some reason, self-edit for the same patterns before finishing.

## Step 5: Save and show

Save the draft to the inbox:

**Path:** `/Users/dylan/Projects/personal/obsidian/Inbox/YYYY-MM-DD-<slug>-<platform>.md`

- `<slug>` is the kebab-case working title; `<platform>` is one of `youtube`, `thread`, `linkedin`, `blog`.
- Today's date. Don't overwrite — append `-2`, `-3` if the file exists. The `-<platform>.md` suffix keeps drafts distinguishable from outlines and digests in the same folder.
- Then show the full draft in chat so the user can react and edit without opening the file.

> **Placeholder — revisit in Part 2 (Obsidian memory layer).** The inbox path mirrors `morning-report` and `outline-content`. If the vault's inbox moves, update all three together.

## What NOT to do

- Don't drop the references — carrying sources through is part of the contract with `outline-content`.
- Don't change the angle or reorder the key points to fit a format. Adapt the form, keep the argument.
- Don't produce more than the requested platform's draft. One platform per run unless the user asks for several — then save each to its own file.
- Don't skip the humanizer pass. The technical audience is exactly who notices AI-generated phrasing.
