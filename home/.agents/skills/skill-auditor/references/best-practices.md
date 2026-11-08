# Skill Authoring Best Practices

Distilled from Anthropic's official guidance. Every checklist item in the audit maps to a rule here.

## Contents

- [Frontmatter Rules](#frontmatter-rules)
- [Body Rules](#body-rules)
- [Structure & Progressive Disclosure](#structure--progressive-disclosure)
- [Design Patterns](#design-patterns)
- [Scripts Rules](#scripts-rules)
- [Discoverability Rules](#discoverability-rules)
- [Anti-Patterns](#anti-patterns)

---

## Frontmatter Rules

### `name` field

- Maximum 64 characters
- Lowercase letters, numbers, and hyphens only — no underscores, spaces, or special characters
- Must start and end with an alphanumeric character
- Cannot contain the substrings `anthropic` or `claude`
- Cannot contain XML tags
- Gerund form preferred (`processing-pdfs`) but noun phrases and action phrases are acceptable
- Avoid vague names: `helper`, `utils`, `tools`, `documents`, `data`

### `description` field

- Maximum 1,024 characters; must be non-empty
- Cannot contain XML tags
- Written in **third person** — the description is injected into the system prompt; first/second person causes discovery problems
  - Good: `"Processes Excel files and generates reports"`
  - Bad: `"I can help you process Excel files"` / `"You can use this to process Excel files"`
- Must describe **what** the skill does AND **when** to use it
- Include at least one "Use when..." trigger phrase so Claude knows when to invoke the skill
- Include ≥3 searchable domain keywords (not just generic verbs)
- The description is the primary discovery mechanism — Claude selects from potentially 100+ skills using only name + description

---

## Body Rules

### Length

- Keep SKILL.md body under **500 lines** for optimal performance
- Word count target: under **5,000 words**
- If approaching 500 lines, move detailed content into `references/` files and add clear pointers

### Content quality

- No hardcoded absolute paths (use `~` or relative paths; `/Users/username/...` is wrong)
- No Windows-style paths (`\`) — always use forward slashes; they work cross-platform
- No time-sensitive claims: avoid `"as of 2024"`, `"currently"`, `"recently added"`. Put deprecated info in a collapsible "old patterns" section
- Consistent terminology: pick one term per concept and use it throughout (`endpoint` not `endpoint`/`URL`/`route`/`path`)
- Complex multi-step workflows should use a **checklist pattern** (copy-and-check-off steps) so Claude tracks progress
- Provide a default when presenting options — don't leave choices open-ended
  - Bad: `"You can use pypdf, pdfplumber, or PyMuPDF..."`
  - Good: `"Use pdfplumber. For scanned PDFs requiring OCR, use pdf2image instead."`
- Don't assume tool or package availability without explicit install instructions

### Conciseness

- Challenge every paragraph: does Claude already know this? Only add context Claude doesn't have
- Don't explain what PDFs, APIs, or common libraries are — Claude already knows
- Avoid over-explaining the "why" of obvious choices

---

## Structure & Progressive Disclosure

### File and folder naming

- The main file must be named exactly `SKILL.md` (case-sensitive)
- The skill folder must use **kebab-case** naming (`my-skill`, not `MySkill` or `my_skill`)

### Three-level loading

Skills use a three-level loading system — content at each level should be appropriate to that level:

1. **Frontmatter** (name + description) — always in context; ~100 words maximum; drives discovery
2. **SKILL.md body** — loaded when skill triggers; keep under 500 lines; overview + navigation
3. **Bundled resources** — loaded as needed; no size limit; reference files, scripts, assets

### Reference files

- Keep reference files **one level deep** from SKILL.md — no `references/sub/file.md`
  - Nested references may be partially read via `head` rather than fully loaded
- Reference files ≥100 lines must include a **table of contents** at the top
- Name files descriptively: `form_validation_rules.md` not `doc2.md`
- Organize by domain when a skill covers multiple domains:
  ```
  bigquery-skill/
  ├── SKILL.md
  └── reference/
      ├── finance.md
      ├── sales.md
      └── product.md
  ```

### Freedom level

State or imply the freedom level so Claude knows how strictly to follow instructions:

- **High freedom**: multiple valid approaches, use text instructions
- **Medium freedom**: preferred pattern exists, pseudocode with parameters
- **Low freedom**: fragile/exact sequence required, specific scripts with `"Run exactly this command"`

### Feedback loops

Include validation loops for quality-critical or iterative tasks:
- Run → validate → fix → repeat
- For code: run validator script, fix errors, re-run before proceeding
- For content: check against style guide checklist before finalizing

---

## Design Patterns

Identify which pattern a skill follows so the body structure can be evaluated for fit.

### Sequential

Steps must run in a fixed order; each step depends on the previous. Body is structured as a numbered workflow. Example: database migrations, form filling with validate-then-execute.

### Orchestrator

The skill fans out to sub-agents or parallel tracks, then assembles results. Body describes: intake/scoping (main agent), fan-out (sub-agents), gate/review, assembly. Example: research pipelines, multi-track writing workflows.

### Iterative

A loop: run → evaluate → improve → repeat. Body describes the loop criteria, what triggers another iteration, and when to stop. Example: eval-driven skill creation, iterative design refinement.

### Adaptive

Branches based on context detected at runtime. Body contains decision logic: if X then follow path A, if Y then follow path B. Example: domain-routing skills, multi-format document processors.

---

## Scripts Rules

Apply when a skill includes a `scripts/` folder or embeds bash/Python code blocks with external tool invocations.

- MCP tools must use **fully qualified names**: `ServerName:tool_name` format. Without the server prefix, Claude may fail to locate the tool when multiple MCP servers are present
- No unexplained magic numbers — document every constant:
  - Good: `REQUEST_TIMEOUT = 30  # HTTP requests typically complete within 30s`
  - Bad: `TIMEOUT = 47`
- Scripts must **handle errors explicitly** rather than failing and punting to Claude
- List all required packages with install instructions — don't assume availability
- Distinguish clearly between "execute this script" and "read this script as reference"
- Validation/verification steps required for destructive or batch operations

---

## Discoverability Rules

- The "Use when..." trigger phrase must be **clear and specific** — not generic
- Include ≥3 searchable domain keywords in the description
- Define scope: what does this skill NOT cover? Boundaries help Claude choose the right skill
- Include concrete user phrasings that should trigger the skill, not just abstract descriptions
- Avoid vague triggers that match too broadly (`"Use when working with data"`)

---

## Anti-Patterns

| Anti-pattern | Why it fails | Correct approach |
|---|---|---|
| Windows-style paths (`\`) | Breaks on Unix systems | Always use forward slashes |
| Hardcoded absolute paths (`/Users/dylan/...`) | Breaks on other machines | Use `~` or relative paths |
| Too many options without a default | Claude wastes tokens deciding | Pick one default; note the alternative for edge cases |
| Time-sensitive claims | Become wrong as platform evolves | Use "old patterns" sections for deprecated info |
| Nested reference files (depth > 1) | May be partially read via `head` | Keep all references one level deep from SKILL.md |
| Magic constants in scripts | Opaque and unmaintainable | Document every non-obvious value |
| Punting errors to Claude | Unreliable | Handle errors in scripts explicitly |
| Vague description | Wrong skill selected | Include what + when + specific triggers |
| First/second person in description | Discovery problems | Third person throughout |
| Assumed package availability | Runtime failure | List all dependencies with install commands |
| `name` containing `claude`/`anthropic` | Validation failure | Use different identifier |
