# Audit Steps: Scoring, Reporting, and Fixing

Implements Steps 3–6 from SKILL.md. Follow exactly.

## Contents

- [Step 3: Score Five Dimensions](#step-3-score-five-dimensions)
- [Step 4: Report Format](#step-4-report-format)
- [Step 5: Offer Optimized Version](#step-5-offer-optimized-version)
- [Step 6: Write-to-Disk Confirmation](#step-6-write-to-disk-confirmation)
- [Regression Risk Reference](#regression-risk-reference)

---

## Step 3: Score Five Dimensions

Each dimension is worth 0, 1, or 2 points. Max score: 10. Award points based on evidence from the file — not intent.

### Dimension 1: Frontmatter Quality (0–2)

**2 pts** — All of the following are true:
- `name` is ≤64 chars, lowercase/numbers/hyphens only, no `anthropic`/`claude` substrings
- `description` is ≤1,024 chars, non-empty, written in third person
- Description contains at least one "Use when..." trigger phrase
- Description contains ≥3 searchable domain keywords

**1 pt** — `name` is valid but description has one of: no trigger phrase, first/second person, too few keywords, or is near the character limit.

**0 pts** — `name` is invalid (wrong chars, reserved word, too long), or description is missing/empty, or description has multiple of the above problems.

### Dimension 2: Body Quality (0–2)

**2 pts** — All of the following are true:
- Body is under 500 lines and under 5,000 words
- No hardcoded absolute paths or Windows-style paths (`\`)
- No time-sensitive claims (`"as of 2024"`, `"currently"`, `"recently added"`)
- Terminology is consistent throughout
- Options have a stated default (no open-ended "you can use X or Y or Z")
- Any assumed tools/packages have explicit install instructions

**1 pt** — Body is within limits and mostly clean but has one violation: a hardcoded path, an inconsistent term, an open option list, or a time-sensitive claim.

**0 pts** — Body exceeds 500 lines or 5,000 words, or has multiple content anti-patterns.

### Dimension 3: Structure & Progressive Disclosure (0–2)

**2 pts** — All of the following are true:
- File is named exactly `SKILL.md` (case-sensitive)
- Folder uses kebab-case
- Content is distributed across three levels (frontmatter → body → references) where appropriate — bulk detail is not stuffed into the body
- All reference files are at depth ≤1 from SKILL.md
- Reference files ≥100 lines include a table of contents
- Freedom level is stated or clearly implied
- Feedback loops are present for quality-critical or iterative tasks

**1 pt** — Structure is mostly correct but one element is missing: no ToC on a long reference file, or a slightly wrong folder name, or freedom level is unstated, or no feedback loop where one would help.

**0 pts** — File is not named `SKILL.md`, or reference files are nested deeper than one level, or all detail is crammed into SKILL.md with no reference structure where one is clearly needed.

### Dimension 4: Design Pattern Fit (0–2)

**2 pts** — A design pattern is identifiable (Sequential, Orchestrator, Iterative, or Adaptive), and the body structure matches it: steps for Sequential, fan-out/gate/assembly for Orchestrator, loop criteria for Iterative, branch logic for Adaptive.

**1 pt** — A pattern is identifiable but the body structure only partially matches it (e.g., a Sequential skill has no numbered steps, or an Orchestrator skill describes sub-agents but not the gate/review phase).

**0 pts** — No identifiable pattern, or the body structure contradicts the apparent intent.

### Dimension 5: Discoverability (0–2)

**2 pts** — All of the following are true:
- "Use when..." trigger phrase is specific (not `"Use when working with data"`)
- Description includes ≥3 domain keywords that would appear in real user requests
- Scope is defined — what the skill does NOT cover is stated or clearly implied
- Trigger phrases cover multiple user phrasings, not just one narrow case

**1 pt** — Trigger phrase is present but generic, or scope is undefined, or keywords are sparse.

**0 pts** — No trigger phrase, or description is so vague that Claude would struggle to select this skill over alternatives.

---

## Step 4: Report Format

Use this exact template. Fill every section — do not omit any.

```
## Audit: <skill-name>

### Metrics

| Metric              | Value                                 |
|---------------------|---------------------------------------|
| Total lines         | <N>                                   |
| Word count (body)   | <N>                                   |
| Frontmatter fields  | name, description[, <extras>]         |
| Body lines          | <N>                                   |
| Reference files     | <list or "none">                      |
| Folder structure    | <list subdirs or "SKILL.md only">     |
| Design pattern      | <Sequential / Orchestrator / Iterative / Adaptive / None identified> |

Guidelines Source: <"references/best-practices.md (static)" or "platform.claude.com (live, fetched <date>)" or "platform.claude.com (fetch failed — fell back to static)">

### Scores

| Dimension                       | Score | Evidence                                      |
|---------------------------------|-------|-----------------------------------------------|
| 1. Frontmatter Quality          | <0–2> | <specific finding>                            |
| 2. Body Quality                 | <0–2> | <specific finding>                            |
| 3. Structure & Progressive Disc | <0–2> | <specific finding>                            |
| 4. Design Pattern Fit           | <0–2> | <specific finding>                            |
| 5. Discoverability              | <0–2> | <specific finding>                            |
| **Total**                       | **/10**  |                                            |

### Regression Risk

<Filled from git comparison — see Regression Risk Reference below.
If git check was skipped, write: "Skipped — <reason>">

### Grade

<Choose one>
- **Excellent (9–10):** Follows all best practices. Ship it.
- **Good (7–8):** Minor issues only. Worth fixing before broad distribution.
- **Needs work (5–6):** Several gaps. Fix before using with other people.
- **Fails best practices (<5):** Significant structural or content problems.

### Findings

<Numbered list of specific, actionable issues, each citing the rule from best-practices.md.
If no issues, write: "No findings — skill meets all criteria.">
```

---

## Step 5: Offer Optimized Version

After the report, offer to generate a corrected SKILL.md.

**Rules for generating the corrected version:**

1. Fix only what the findings flagged. Do not refactor, rename, or restructure unflagged content.
2. **Never change the `name` field.** Changing the name is a breaking change (see Regression Risk).
3. **Preserve all description trigger phrases.** You may add or reword triggers but never remove existing ones.
4. When fixing body content: replace anti-patterns inline; do not restructure the document unless structure was a flagged finding.
5. When fixing frontmatter: apply the minimum change that makes the field valid.
6. Present the corrected version as a full file in a code block, or as a unified diff if the file is long. State which findings each fix addresses.
7. Do **not** write to disk in this step — that requires explicit confirmation in Step 6.

---

## Step 6: Write-to-Disk Confirmation

Only write to disk after receiving an explicit second confirmation from the user.

**Confirmation prompt to give the user:**

> I can write the corrected version to `<path>`. This will overwrite the current file. Confirm to proceed.

**After confirmed write:**

- Write to the same path as the audited file
- State which regression-risk checks the new version passes:
  - `name` unchanged: ✓
  - All description trigger phrases preserved: ✓ / ✗ (list any removed)
  - Reference files unchanged: ✓ / ✗ (list any removed)
  - Line count change: `<before> → <after>` (flag if >30% reduction)

---

## Regression Risk Reference

Used in Step 2c. Compare the current SKILL.md against `git show HEAD:<path>` output.

| Check | Severity | How to detect |
|---|---|---|
| `name:` field changed | **BREAKING** | Compare name values; any change breaks existing references and triggering |
| Description trigger phrases removed | **BREAKING** | Any "Use when..." clause or named trigger present in HEAD but absent now |
| Activation intent weakened | **WARNING** | `Use when...` clause gone, or ≥3 domain keywords from HEAD are absent in current |
| Reference files removed | **WARNING** | Any `references/` path present in HEAD that no longer exists in the folder |
| Line count reduced >30% | **WARNING** | `current_lines / head_lines < 0.70` — significant content loss |
| New anti-patterns introduced | **INFO** | Anti-patterns (hardcoded paths, Windows paths, time-sensitive claims) present now but not in HEAD |

Report each finding under "Regression Risk" using BREAKING / WARNING / INFO severity labels. If no issues found, write: "No regressions detected."
