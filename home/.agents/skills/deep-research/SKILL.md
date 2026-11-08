---
name: deep-research
description: "Multi-source research that fans out across the web, YouTube, X/Twitter, and GitHub at the same time, with NotebookLM as the optional durable corpus layer. Use this skill whenever the user wants to research a topic deeply, investigate what people are saying about something, do competitive or ecosystem research, or understand the state of a subject across many independent sources. Triggers on phrases like 'deep research on', 'research [topic] across everything', 'full research on', 'what are people saying about', 'research this topic', or any request that implies gathering intel from multiple platforms about a single subject. Do not use it for a single factual lookup, one API signature, flag, version number, or error message, a summary of one document the user already has, or a question you can answer from this repository, from a command's --help output, or from one fetch."
version: 2.1.0
license: MIT
compatibility: "Runs on Claude Code, Codex, and Pi. The NotebookLM corpus track needs the notebooklm executable from notebooklm-py and an authenticated NotebookLM session. The direct-discovery track needs only a web search tool and a URL fetch tool."
metadata:
  tags: [research, notebooklm, web, youtube, twitter, github, synthesis]
  related_skills: [notebooklm, yt-search, yt-pipeline]
---

# Deep Research

Build a short, cited, multi-source research brief. Two tracks run at the same time: direct discovery across the web, YouTube, X/Twitter, and GitHub, and an optional NotebookLM corpus that stays available for follow-up questions. You do the synthesis; NotebookLM only gathers and grounds.

## When to use this skill

Use it when the answer depends on the state of the world outside this machine, a correct answer needs three or more independent sources, and a person will make a decision from the result.

Do not use it for a single factual lookup, one API signature or config key, one version number, one error message, one changelog entry, a summary of one document the user already has, or a question you can answer from this repository or from one fetch. Answer those directly.

## Prerequisites

Check the NotebookLM track before you create anything:

```bash
command -v notebooklm
notebooklm --version
notebooklm doctor --json
notebooklm auth check --test --json
```

Rules that have no exception:

- Never run `notebooklm login`. It opens a browser and blocks, so an unattended worker hangs there.
- Never install or upgrade a package. Do not run `uv tool install`, `pip install`, or any equivalent.
- If `notebooklm` is absent, or `doctor` or `auth check` fails, stop the NotebookLM track and report a concrete blocker that names the failing command and its message. Ask the operator to run `notebooklm login`. Then either deliver the brief from direct discovery alone and state the limitation, or stop, depending on what the caller asked for.
- Never read, print, copy, or commit NotebookLM cookies or storage-state files.
- `notebooklm-py` uses unofficial Google APIs. Report upstream breakage as a blocker. Never invent results to cover it.

## Tools, by what the runtime actually has

Pick the first available option in each row. Do not require a tool this runtime lacks.

| Need | Preferred | Fallback |
|---|---|---|
| Web search | `mcp__crawler__search` | the runtime's own web search tool, then a shell HTTP client |
| Fetch a known URL | `WebFetch` or the runtime's fetch tool | `curl -sL <URL>` |
| GitHub activity | `gh-axi` | `gh`, then `curl` against `api.github.com` |
| YouTube metadata | the `yt-search` skill | `site:youtube.com/watch` search queries |
| Video transcripts and a video-only corpus | the `yt-pipeline` skill | skip the track and cite video metadata only |

On Claude Code, `WebSearch` is denied by policy. Use `mcp__crawler__search` there. Do not plan a step around a denied tool.

Treat `yt-pipeline` as an escalation for genuinely video-centric questions, not a default. It builds its own separate notebook, which duplicates this skill's corpus.

## Workflow

### 1. Frame the research question

Extract the exact topic, the desired outcome, the time horizon, and the relevant geography, audience, or competitors. List the likely synonyms and the per-platform query variants.

Ask one clarifying question only when the ambiguity changes which sources you would gather. Otherwise proceed and write your assumptions into the report.

### 2. Decide whether NotebookLM is warranted

NotebookLM is the corpus layer, not the default. Create a notebook only when the topic justifies a durable, reusable, citation-anchored corpus: roughly five or more substantive sources, or a corpus the caller will return to. Below that, direct discovery alone is enough and you must not create a notebook.

Never create a second notebook for a question an existing notebook already covers. Check `notebooklm list` first when the topic may already have one.

### 3. Create the notebook and capture its ID

```bash
notebooklm create --json "Deep Research - <TOPIC> - <YYYY-MM-DD>"
```

Parse the notebook ID from the JSON output and pass `-n <ID>` on every later command.

Do not pass `--use`. Do not run `notebooklm use`. The machine has one shared NotebookLM profile, so the global current-notebook context is shared state: two concurrent research tasks that rely on it will overwrite each other's notebook. Explicit `-n <ID>` is the only safe form.

Do not delete or rename an existing notebook unless the caller asks for it.

### 4. Write the report breadcrumb before anything slow

Create the report file at its final path now and write the notebook ID plus `NotebookLM deep research started, not yet complete` into it.

This is the duplicate-job guard. If this worker is killed or times out, the ID survives on disk and the next worker checks status instead of starting a second server-side research job.

### 5. Start deep research without blocking

```bash
notebooklm source add-research -n <ID> \
  --mode deep --import-all --cited-only --no-wait --json \
  "<RESEARCH QUERY>"
```

`--no-wait` returns immediately so the direct-discovery track can proceed. Monitor with `research status` and `research wait` in step 7.

If you ever call `source add-research` without `--no-wait`, know that `--timeout` is a per-phase budget. It applies independently to the research poll and to the `--import-all` retry, so `--timeout 1800` has a worst case near 3600 seconds of wall time.

### 6. Run direct discovery while research runs

This is real work, not waiting. Batch the independent searches together:

1. Broad web: `"<TOPIC>" <CURRENT_YEAR>`
2. Guides and news: `"<TOPIC>" tutorial OR guide OR announcement`
3. YouTube: `site:youtube.com/watch "<TOPIC>"`
4. X current: `site:x.com "<TOPIC>"`
5. X legacy: `site:twitter.com "<TOPIC>"`
6. GitHub: `site:github.com "<TOPIC>"`
7. GitHub projects: `"<TOPIC>" GitHub repo OR library OR tool`

Use the current year from the system date. Never hard-code a year into the query.

For every promising source: verify the URL and the title, record the author or creator, the publication date, and any relevant activity metric, and prefer the primary source over a summary of it.

Add only the high-signal sources that NotebookLM missed:

```bash
notebooklm source add -n <ID> --type url --json "<URL>"
notebooklm source add -n <ID> --type youtube --json "<YOUTUBE_URL>"
```

Do not bulk-add search results. The notebook is a curated evidence set, not a link dump.

### 7. Confirm the corpus is complete

Check research first, then the sources.

```bash
notebooklm research status -n <ID> --json
notebooklm research wait -n <ID> --timeout 900 --import-all --cited-only --json
```

A timeout means your polling ended. It does not prove the server-side job failed. On timeout, re-run `research status -n <ID> --json`. Never re-issue `source add-research`, because that starts a duplicate job.

If research is still in progress and this worker reports status to a supervisor, report a paused state that names the notebook ID and the next check time, then check again. Do not sit in a silent blocking wait.

To wait on individual sources, read the source IDs first and wait on each one. `source wait` needs a concrete `SOURCE_ID` positional argument; there is no whole-corpus form of it.

```bash
notebooklm source list -n <ID> --json
notebooklm source wait -n <ID> --timeout 900 <SOURCE_ID>
```

Polling `notebooklm metadata -n <ID> --json` until every intended source appears is an equally valid and cheaper check, and it is the one that matches the completion criterion below.

Completion criterion: the corpus holds multiple independent publishers, it covers the source classes the request needs, and every source you intend to cite appears in `metadata`. If one important class is missing, run one targeted discovery pass and add only the strongest missing sources.

### 8. Curate with grounded questions

Ask separate questions so the synthesis stays auditable. `--json` keeps the source references; `--save-as-note` keeps the curated output in the notebook.

```bash
notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Consensus and key findings" \
  "Identify the strongest recurring findings across independent sources. Cite every finding and separate evidence from interpretation."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Contradictions and uncertainty" \
  "Where do sources disagree? For each conflict, say whether it comes from evidence, date, scope, incentives, or opinion. Cite both sides."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Actors, gaps, and opportunities" \
  "Map the major actors, approaches, and themes. Identify underserved questions or gaps, and cite the evidence for each gap."

notebooklm ask -n <ID> --json --save-as-note \
  --note-title "Research brief evidence pack" \
  "Produce a short evidence pack: key claims, supporting sources, dates, notable metrics, and caveats. Make no uncited claim."
```

Do not pass `--new`. It deletes the notebook's server-side conversation.

Adapt the questions to the caller's outcome. For competitive research, ask for positioning, differentiation, traction, complaints, and switching triggers. For content research, ask what creators repeat, what audiences still ask, and which angles are absent.

### 9. Synthesize across both tracks

Never paste a NotebookLM answer unchanged. Cross-check each answer against the sources you fetched and against their dates. Look for:

- consensus repeated by independent source types
- contradictions, and the likely reason for each one
- velocity: rising, stable, or fading activity
- gaps between what creators cover and what communities still ask
- the primary evidence behind every quantitative claim
- missing data and probable source bias

Citation rules:

- A snippet in a search result is not a source. Fetch the page or omit the claim.
- Every substantive claim carries a resolvable link.
- A claim about the present needs a current source, and you state its date.
- Mark inference as inference. Never present it as evidence.
- Never invent a URL, a metric, a date, or a social sentiment. When access is incomplete, say which part is unverified.

### 10. Write the report

Destination, in priority order:

1. A caller-supplied absolute report path wins. When the caller names one, for example a supervising orchestrator that requires `report.md` at a fixed path, write the report there. That path is authoritative.
2. Otherwise write `~/Documents/second-brain/output/YYYY-MM-DD-<topic-slug>-deep-research.md`. Create `output/` if it is missing.

Use today's real date from the system. Slugify the topic as lowercase ASCII words joined by hyphens. Writing a second copy to the vault when the caller supplied a path is optional and needs no permission.

Use this structure unless the caller asks for another format. Drop a section that has no verified content rather than filling it with guesses.

```markdown
# Deep Research: <Topic>

**Date:** YYYY-MM-DD
**Research question:** <question>
**NotebookLM notebook:** <notebook ID, or "not used" with the reason>

## Executive Summary
- 4 to 7 cross-source findings, each with citations

## Evidence and Key Themes
### <Theme>
- Finding, evidence, contradiction or caveat, and links

## YouTube
| Video | Creator | Published | Signal | Relevance |
|---|---|---|---|---|

## Web and Primary Sources
- [Title](URL) - why it matters

## X and Community Pulse
- Sentiment, recurring questions, notable voices, and linked examples

## GitHub and Builder Activity
- Repositories, releases, verified activity metrics, and notable issues

## Contradictions and Uncertainty
- Claim against counterclaim, source dates, and your reading of it

## Gaps and Opportunities
- Evidence-backed gaps and underserved questions

## Limitations
- What you could not verify, what access was incomplete, and any NotebookLM work that was still running at write time

## Recommended Next Actions
- Prioritized, concrete follow-ups

## Sources
- Deduplicated list: title, publisher or creator, date, URL
```

Use Obsidian `[[wikilinks]]` only when the target note exists. Verify a vault project before you mention it.

The report never blocks on NotebookLM. If deep research has not finished when you must write, write the brief from direct discovery plus whatever NotebookLM returned, and state the residual limitation exactly: `NotebookLM deep research incomplete at write time; notebook <ID>; N of M sources processed`.

Completion criteria:

- The file exists at the authoritative path and you read it back.
- Every citation resolves.
- The notebook ID appears in the file, or the file says why no notebook was used.
- Conclusions separate evidence from inference, and the Limitations section names what is unverified.

## Common pitfalls

1. Using a search snippet as evidence. Open the source and verify the claim.
2. Relying on the global current-notebook context. Capture the ID and pass `-n <ID>` every time.
3. Retrying after a client timeout without checking status. That creates duplicate research jobs.
4. Calling `source wait` without a `SOURCE_ID`. There is no whole-corpus form.
5. Blocking on NotebookLM before the breadcrumb is on disk. Write the ID first.
6. Running `notebooklm login` or a package install unattended. Report a blocker instead.
7. Creating a notebook for a lookup. Keep NotebookLM for broad, durable corpora.
8. Importing every result. A smaller, diverse, high-signal corpus beats a link dump.
9. Exposing auth state. Never display or copy cookie or storage files.
10. Stacking raw platform dumps. The deliverable is cross-source synthesis.
11. Overwriting the caller's chosen destination with the vault default.

## Verification checklist

- [ ] `notebooklm doctor --json` and `auth check --test --json` passed, or the NotebookLM track was skipped with a stated blocker
- [ ] Notebook created only when a durable corpus was warranted, and its ID captured
- [ ] Every `notebooklm` command carried `-n <ID>`; `notebooklm use` was never called
- [ ] Notebook ID written into the report before any long-running call
- [ ] Deep research completed, or its residual limitation is stated in the report
- [ ] Curated sources are processed and present in `notebooklm metadata`
- [ ] Every direct-discovery claim was checked at its original URL
- [ ] Report holds consensus, contradictions, gaps, limitations, and a source list
- [ ] Report is at the caller-supplied path when one was given, and it was read back
