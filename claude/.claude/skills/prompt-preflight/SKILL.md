---
name: prompt-preflight
description: Prompt preflight for messy agent instructions. Always convert the rough ask into a modular execution-ready prompt, print the improved prompt for Ali to inspect, execute it, and print receipts for the prompt, actions, files, commands, checks, blockers, and verification.
---

# Prompt Preflight

Use this skill to convert a rough user instruction into a clean prompt, show that prompt to Ali, and then execute it.

The goal is not to make the prompt sound polished. The goal is to preserve Ali's intent while separating the parts that often get tangled:

- target or scope
- source material
- requested actions
- conflicts and ambiguities
- constraints
- execution order
- verification
- final report requirements

## Core Behavior

Always follow this sequence:

1. Build an improved execution prompt from Ali's rough instruction.
2. Print the improved prompt in a fenced `text` code block so Ali can see exactly what will be run.
3. Execute the improved prompt immediately.
4. Print receipts for what happened: files opened or changed, commands or checks run, sources used, blockers, assumptions, and verification. If a receipt category does not apply, say `None`.
5. Finish with the requested result plus a concise note on verification, blockers, or assumptions.

Keep the improved prompt specific to the user's provided context. Do not leave placeholder fields unless the user is explicitly designing a reusable template.

## Preflight Process

1. Extract the actual job.
   - Identify what the next agent is supposed to do.
   - Identify the target files, URLs, screenshots, repo paths, apps, people, or records.
   - Preserve exact file paths, links, names, numbers, and user wording when they matter.

2. Split the prompt into modules.
   Use only the modules that fit the task:
   - `Task`
   - `Target`
   - `Inputs`
   - `Required Actions`
   - `Constraints`
   - `Conflict Handling`
   - `Execution Order`
   - `Verification`
   - `Receipts`
   - `Output Format`

3. Surface ambiguity instead of silently resolving it.
   - If the rough prompt conflicts with an image, file, transcript, or earlier instruction, make the conflict explicit.
   - Tell the executing agent when to proceed with a reasonable interpretation and when to pause.

4. Add verification proportional to risk.
   - For file edits: reread changed files and summarize the exact changes.
   - For research: cite sources and distinguish primary from secondary.
   - For external actions: draft or preview first unless the user explicitly asked to send/post/modify live state.
   - For code: run the relevant tests or a smoke check when feasible.

5. Keep the output compact.
   - Do not turn a small prompt into a giant operating manual.
   - Prefer short bullets with concrete verbs.
   - Remove duplicate instructions and vague intensifiers.

## Default Output

Use this structure unless the user asks for something else:

```markdown
Here is the preflighted prompt:

\`\`\`text
[copy-pasteable prompt]
\`\`\`

Now I will run it.

[execution result]

Receipts:
- Files opened or changed: ...
- Commands or checks run: ...
- Sources used: ...
- Blockers or assumptions: ...

Verification:
- ...
```

If execution is blocked by missing information, unavailable files, permissions, or unsafe external action, still print the improved prompt first, then state the blocker and the smallest needed next input.

## Copy-Paste Prompt Shape

Inside the fenced prompt, usually use:

```text
Task:

Target:

Inputs:

Required actions:

Constraints:

Conflict handling:

Verification:

Receipts:

Output:
```

Omit sections that would be empty or silly for the task.

## Examples

### Screenshot plus typed edits

User:
`delete 7 and make all the edits in the screenshot for obsidian://open?...`

Good response shape:

````markdown
Here is the preflighted prompt:

```text
Task:
Edit one Obsidian note.

Target:
obsidian://open?...

Inputs:
- Use the attached screenshot as the edit list.
- Use my typed instruction as an additional instruction.

Required actions:
- Delete Clip 7.
- Apply each readable edit from the screenshot.

Conflict handling:
- If the typed instruction and screenshot conflict on a clip number, pause and state the conflict before editing.

Constraints:
- Edit only the target note.
- Preserve unrelated content and formatting.

Verification:
- Re-read the note after editing.
- Summarize exactly what changed and what could not be completed.

Receipts:
- Report the target note path, whether the screenshot was available, and any changed lines or unresolved edits.
```

Now I will run it.

[edit the target note, reread it, and report exactly what changed or what could not be completed]
````

## When to Ask a Question

Avoid blocking unless a wrong assumption would materially change the work. If a prompt can safely instruct the next agent how to handle ambiguity, encode that in `Conflict handling` instead of asking Ali a question.
