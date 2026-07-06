---
name: yt-pipeline
description: "End-to-end YouTube research pipeline — searches YouTube, auto-selects the best videos, creates a NotebookLM notebook, adds them as sources, runs analysis, and optionally generates deliverables (podcasts, reports, quizzes, etc). Trigger on phrases like 'research X on YouTube', 'find YouTube videos about X and analyze them', 'what are YouTubers saying about Z', 'create a podcast from YouTube videos about Y'."
---

# YouTube Research Pipeline

Fully automated pipeline: YouTube search → smart video selection → NotebookLM notebook → analysis → deliverable. Runs end-to-end without asking for input mid-flow unless the request is genuinely too vague.

## When This Skill Activates

**Intent detection — activate when the user wants to:**
- Research a topic using YouTube as a source
- Find and analyze YouTube videos on a topic
- Create a deliverable (podcast, report, quiz, etc.) from YouTube content
- Understand what YouTubers are saying about something

**Example triggers:**
- "Research what YouTubers are saying about Claude Code"
- "Find YouTube videos about AI agents and make a podcast"
- "What's the YouTube consensus on [topic]?"
- "Search YouTube for [topic] and summarize the findings"
- "Create a study guide from YouTube videos about [topic]"

**Do NOT activate for:**
- Simple YouTube searches with no analysis intent (use `/yt-search` instead)
- NotebookLM tasks that don't involve YouTube (use `/notebooklm` instead)

## Pipeline Steps

### Step 0 — Pre-flight Check

Before starting the pipeline, verify NotebookLM auth is working:
```bash
notebooklm status
```
If it fails or shows no authentication, tell the user to run `notebooklm login` and stop. This catches auth issues early instead of discovering them mid-pipeline after the search and selection work is already done.

### Step 1 — Understand the Request

Extract from the user's message:
- **Search query** — the topic to search for
- **Analysis goal** — what they want to learn (optional)
- **Deliverable type** — podcast, report, quiz, etc. (optional)

**If the request is too vague** to form a useful YouTube search query (e.g. "research stuff"), ask ONE short clarifying question, then proceed.

**Otherwise, proceed immediately.** Do not ask unnecessary questions. Infer reasonable defaults.

### Step 2 — Search YouTube

Run the yt-search script:
```bash
python ~/.claude/skills/yt-search/scripts/search.py <query> --count 10 --months <M>
```

- Craft the best search query from the user's intent — this may differ from their exact words
- Default to `--months 6` unless the topic warrants a wider window (evergreen content → `--months 12` or `--no-date-filter`)
- **Show the full results to the user** — present all videos with their complete metadata (title, channel, subs, views, duration, date, views-to-subs ratio, URL). The script already formats this nicely, so present its output directly.

**If no results:** Automatically retry with a broader query or `--no-date-filter` before reporting failure.

### Step 3 — Auto-Select Videos

Immediately after showing results, auto-select the best videos. **Do not wait for user input.**

**Selection criteria (in priority order):**
1. **Relevance** — does the title/channel match the user's intent?
2. **Engagement** — views-to-subs ratio outliers signal high-quality content
3. **Recency** — prefer newer content when quality is comparable
4. **Depth** — prefer longer videos (10+ min) over shorts/clips for research purposes
5. **Source diversity** — prefer videos from different channels over multiple from the same creator

**Drop obvious mismatches:** wrong topic, unrelated shorts, clickbait with low engagement.

**Target 5-8 videos.** NotebookLM works best with focused source sets. Fewer if only a few are relevant; more if the topic is broad.

**Tell the user which videos were selected and briefly why**, then keep moving. Example:
> "Selected 6 videos — these had the strongest relevance to [topic] and engagement ratios. Dropped #3 (off-topic) and #9 (duplicate channel)."

### Step 4 — Create Notebook & Add Sources

1. Create notebook:
   ```bash
   notebooklm create "YT Research: <topic>" --json
   ```
   Parse the notebook ID from the JSON output.

2. Set context:
   ```bash
   notebooklm use <notebook_id>
   ```

3. Add each selected video as a source:
   ```bash
   notebooklm source add "<youtube_url>" --json
   ```
   Collect source IDs from the JSON output.

4. Wait for all sources to process:
   ```bash
   notebooklm source wait <source_id>
   ```
   Run these sequentially. Each takes 10-60 seconds.

**Error handling:**
- Auth failure → tell user to run `notebooklm login`
- Individual source failure → skip it, continue with others, report skipped sources at the end
- If all sources fail → stop and report the error

### Step 5 — Analysis

Run analytical questions via `notebooklm ask "..."` tailored to the user's goal.

**If user specified an analysis goal**, tailor all questions to that angle. Example goals and matching questions:
- "what's the consensus" → "Where do these creators agree? Where do they disagree?"
- "best practices" → "What actionable advice do the creators share? What do they recommend?"
- "how to" → "What are the step-by-step approaches described? What tools/methods are recommended?"

**Default questions (no specific goal):**
1. `notebooklm ask "What are the key themes and main points across these videos?" --new`
2. `notebooklm ask "Where do the creators agree and where do they have different perspectives?"`
3. `notebooklm ask "What are the most actionable takeaways someone could apply immediately?"`

Use `--new` on the first question to start a fresh conversation. Subsequent questions are follow-ups in the same conversation thread (no `--new` flag).

**Present findings to the user** in a clear, structured summary with a `## Key Takeaways` section.

**If in an Obsidian vault:** Offer to save the analysis as a research note to `/research/` following vault conventions (date, source, key findings, wiki links to related projects).

### Step 6 — Generate Deliverable (If Requested)

Only if the user asked for a specific deliverable (podcast, report, quiz, study guide, etc.).

**Map user intent to NotebookLM generation commands:**

| User says | Command |
|-----------|---------|
| "podcast" / "audio" | `notebooklm generate audio "Focus on [goal]" --json` |
| "video" | `notebooklm generate video "Focus on [goal]" --json` |
| "report" / "summary" / "write-up" | `notebooklm generate report --format briefing-doc` |
| "study guide" | `notebooklm generate report --format study-guide` |
| "quiz" | `notebooklm generate quiz --json` |
| "flashcards" | `notebooklm generate flashcards --json` |
| "mind map" | `notebooklm generate mind-map` |
| "slide deck" / "slides" | `notebooklm generate slide-deck --json` |
| "infographic" | `notebooklm generate infographic --json` |

**Important:** When the user explicitly asked for a deliverable (e.g. "make a podcast"), that counts as consent — proceed with generation without asking for additional confirmation. The notebooklm skill's "ask before generating" rule is satisfied by the user's original request.

**For long-running artifacts (audio, video, quiz, flashcards, slide-deck, infographic):**
- Parse the `task_id` / `artifact_id` from the `--json` output
- Spawn a background agent to wait and download:
  ```
  Agent(
    prompt="Wait for artifact <artifact_id> in notebook <notebook_id> to complete, then download.
            Use: notebooklm artifact wait <artifact_id> -n <notebook_id> --timeout 1200
            Then: notebooklm download <type> ./<filename> -a <artifact_id> -n <notebook_id>
            Report the result back.",
    subagent_type="general-purpose"
  )
  ```
- Tell the user generation has started and they'll be notified when it's ready

**For instant/fast artifacts (report, mind map, data table):**
- Generate and present immediately
- Offer to save to the vault if applicable

## Autonomy Rules

**Run the full pipeline automatically.** The entire point of this skill is end-to-end automation. Do not pause for confirmation between steps unless something fails.

**The only acceptable pause points:**
- Step 1: Request is too vague to search → ask ONE clarifying question
- Step 4: Auth failure → tell user to run `notebooklm login`
- Step 6: Before generating a deliverable the user didn't explicitly ask for

**Everything else flows automatically:** search → show results → select → notebook → sources → analysis → deliverable.

## Output Style

- Show YouTube search results in full (the script output is well-formatted)
- Keep selection reasoning to 1-2 sentences
- Present analysis findings in bullet points with a `## Key Takeaways` section
- Use progress updates between steps: "Searching YouTube...", "Creating notebook...", "Adding 6 sources...", "Analyzing content..."
