---
name: deep-research
description: "Use when researching one topic deeply across many sources."
version: 2.0.0
author: Dylan + Hermes Agent
license: MIT
compatibility: "Requires notebooklm from notebooklm-py and authenticated Google NotebookLM access."
metadata:
  hermes:
    tags: [research, notebooklm, web, youtube, twitter, github, synthesis]
    related_skills: [youtube-content, xurl, github-repo-management, obsidian]
---

# Deep Research

## Overview

Build a concise, cited, multi-source research brief by combining NotebookLM deep research with direct web, YouTube, X/Twitter, and GitHub discovery. NotebookLM is the grounded gathering and curation layer; Hermes verifies source metadata, checks current facts, identifies cross-source patterns, and writes the final brief.

The default output location is Dylan's shared Obsidian brain:

`/Users/dylan/Projects/second-brain/output/YYYY-MM-DD-<topic-slug>-deep-research.md`

Use a user-specified destination instead when provided. Create `output/` if needed.

## When to Use

Use this skill for requests such as:

- "deep research on ..."
- "research this across everything"
- "what are people saying about ..."
- competitive, market, creator, ecosystem, or content-landscape research
- a grounded research corpus that should remain available in NotebookLM

Do not use it for a single factual lookup, one-document summary, or a request constrained to one source.

## Prerequisite: notebooklm-py

The executable is `notebooklm`; the package is `notebooklm-py`.

Check readiness before creating anything:

```bash
command -v notebooklm
notebooklm --version
notebooklm doctor
```

If the executable is absent, install the supported CLI with its browser authentication extra:

```bash
uv tool install "notebooklm-py[browser]"
notebooklm login
notebooklm auth check --test --json
```

If it is already installed, do not reinstall it. If auth fails, ask the user to complete `notebooklm login`; never read, print, copy, or commit NotebookLM cookies or storage-state files. The package uses unofficial Google APIs, so report upstream breakage rather than inventing results.

## Workflow

### 1. Frame the research question

Extract:

- exact topic and desired outcome
- time horizon, geography, audience, and competitors when relevant
- likely synonyms and platform-specific query variants
- evidence standard: claims must link to sources, and current claims need current sources

Ask one clarification only if ambiguity materially changes the research corpus. Otherwise proceed with explicit assumptions.

### 2. Create a dedicated NotebookLM notebook

Use JSON output when IDs will be parsed programmatically:

```bash
notebooklm create --use --json "Deep Research — <TOPIC> — <YYYY-MM-DD>"
notebooklm status
```

Capture the notebook ID from command output. Pass `-n <ID>` on later commands rather than relying solely on mutable global context when multiple research tasks may run concurrently.

Do not delete or overwrite an existing notebook unless the user explicitly requests it.

### 3. Launch NotebookLM deep research and direct discovery in parallel

NotebookLM is the primary corpus-building track:

```bash
notebooklm source add-research -n <ID> \
  --mode deep --import-all --cited-only --timeout 1800 --json \
  "<RESEARCH QUERY>"
```

Use `--no-wait` plus `notebooklm research status/wait` when other work should continue while deep research runs. A timeout means polling ended; it does not prove the server-side job failed. Inspect status before retrying so duplicate research jobs are not created.

At the same time, run direct discovery with Hermes tools. Batch independent searches together:

1. Broad web: `"<TOPIC>" <CURRENT_YEAR>`
2. Guides/news: `"<TOPIC>" tutorial OR guide OR announcement`
3. YouTube: `site:youtube.com/watch "<TOPIC>"`
4. X current: `site:x.com "<TOPIC>"`
5. X legacy: `site:twitter.com "<TOPIC>"`
6. GitHub: `site:github.com "<TOPIC>"`
7. GitHub projects: `"<TOPIC>" GitHub repo OR library OR tool`

Use the dedicated `xurl` skill for deeper X search when available and `gh`/GitHub skills for repository activity, issues, releases, and stars. Use the `youtube-content` skill when a promising video's transcript needs inspection.

For every promising direct-discovery source:

- verify the URL and title
- record author/creator, publication date, and relevant activity metrics when available
- prefer primary sources over summaries
- add high-signal sources omitted by NotebookLM:

```bash
notebooklm source add -n <ID> --type url --json "<URL>"
# YouTube URLs may be explicit:
notebooklm source add -n <ID> --type youtube --json "<YOUTUBE_URL>"
```

Do not bulk-add low-quality search results. The notebook should be a curated evidence set, not a link dump.

### 4. Verify corpus completion

Wait for all sources to finish processing, then export the source inventory:

```bash
notebooklm source wait -n <ID> --timeout 900
notebooklm metadata -n <ID> --json
```

Check that the corpus includes multiple independent publishers and the source classes relevant to the request. If one important class is missing, run one targeted discovery pass and add only the strongest missing sources.

Completion criterion: the notebook has a processed, diverse corpus and every source intended for synthesis appears in metadata.

### 5. Curate with grounded NotebookLM questions

Ask separate questions so synthesis remains auditable. Use `--json` to retain source references and `--save-as-note` for durable curated outputs.

```bash
notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Consensus and key findings" \
  "Identify the strongest recurring findings across independent sources. Cite every finding and distinguish evidence from interpretation."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Contradictions and uncertainty" \
  "Where do sources disagree? Explain whether each conflict comes from evidence, date, scope, incentives, or opinion. Cite both sides."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Landscape, gaps, and opportunities" \
  "Map the major actors, approaches, and themes. Identify underserved questions or content gaps, and cite the evidence for each gap."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Research brief evidence pack" \
  "Produce a concise evidence pack: key claims, supporting sources, dates, notable metrics, and caveats. Do not make uncited claims."
```

Adapt questions to the user's outcome. For competitive research, ask for positioning, differentiation, traction, complaints, and switching triggers. For content research, ask what creators repeat, what audiences still ask, and which angles are absent.

### 6. Synthesize across all tracks

Do not paste NotebookLM answers unchanged. Cross-check them against direct search results and source dates. Specifically look for:

- consensus repeated by independent source types
- contradictions and likely reasons for them
- velocity: rising, stable, or fading activity
- gaps between creator coverage and community demand
- primary evidence behind quantitative claims
- uncertainty, missing data, and potential source bias

Treat search snippets as discovery aids, not final evidence. Fetch or inspect the underlying page before citing a substantive claim.

### 7. Write the research brief

Use today's actual date from the system. Slugify the topic as lowercase ASCII words separated by hyphens. Write this structure unless the user asks for another format:

```markdown
# Deep Research: <Topic>

**Date:** YYYY-MM-DD
**Research question:** <question>
**NotebookLM notebook:** <URL or notebook ID>

## Executive Summary
- 4–7 cross-source findings, each with citations

## Evidence and Key Themes
### <Theme>
- Finding, evidence, contradiction/caveat, and links

## YouTube Landscape
| Video | Creator | Published | Signal | Relevance |
|---|---|---:|---:|---|

## Web / Primary Sources
- [Title](URL) — why it matters

## X / Community Pulse
- Sentiment, recurring questions, notable voices, and linked examples

## GitHub / Builder Activity
- Repositories, releases, stars/activity as verified, and notable issues or discussions

## Contradictions and Uncertainty
- Claim versus counterclaim, source dates, and interpretation

## Gaps and Opportunities
- Evidence-backed gaps, underserved questions, or strategic openings

## Recommended Next Actions
- Prioritized, concrete follow-ups

## Sources
- Deduplicated source list with title, publisher/creator, date, and URL
```

Use Obsidian `[[wikilinks]]` only when the target note actually exists. Mention related projects in the vault only after verifying them.

Completion criterion: the file exists at the requested path, citations resolve, NotebookLM ID/link is included, and conclusions distinguish evidence from inference.

## Common Pitfalls

1. **Using search snippets as evidence.** Open the source and verify the claim.
2. **Starting synthesis before NotebookLM finishes.** Check research and source status first.
3. **Blindly importing every result.** Prefer a smaller, diverse, high-signal corpus.
4. **Losing notebook identity.** Capture the ID and pass `-n <ID>` in concurrent workflows.
5. **Retrying after a client timeout without checking status.** This can create duplicate research jobs.
6. **Exposing auth state.** Never display or copy cookie/storage files.
7. **Raw platform dumps.** The deliverable is cross-source synthesis, not stacked search results.
8. **Invented social sentiment or metrics.** State when access is incomplete and cite only verified observations.
9. **Overwriting the user's vault structure.** Default to the shared brain's `output/` folder, but honor an explicit destination.

## Verification Checklist

- [ ] `notebooklm doctor` passes
- [ ] Dedicated notebook created and its ID captured
- [ ] Deep research completed or its residual limitation is stated
- [ ] Curated sources are processed and present in notebook metadata
- [ ] NotebookLM curation answers include source references
- [ ] Direct web/social/GitHub claims were checked at their original URLs
- [ ] Final brief includes consensus, contradictions, gaps, uncertainty, and sources
- [ ] Output file was read back and the notebook ID/link was recorded
