# Reviewer adapters

What `scripts/council-run.sh` does per CLI, and why. Every adapter meets the same contract: start a session in round 1 and save its id; resume that same session in later rounds so the reviewer remembers its prior findings; enforce read-only; write the critique to `<out>/<reviewer>.round<N>.txt`; wrap every call in a 600s `perl alarm` ceiling (macOS has no `timeout`).

| CLI | Read-only enforcement | Session id | Resume | Verified |
|-----|----------------------|------------|--------|----------|
| codex | `-s read-only` (round 1), `-c sandbox_mode="read-only"` (resume — `resume` rejects `-s`; without this it inherits `config.toml`, which here is `workspace-write`) | `thread.started` line of `--json` stream | `codex exec resume <id>` | 2026-06-04 |
| claude | `--permission-mode plan` + `--tools "Read,Grep,Glob"` (belt and braces; write attempt refused, verified) | `session_id` in `--output-format json` | `--resume <id>` | 2026-08-21 |
| grok | `--tools "read_file,grep,list_dir,glob" --disallowed-tools Agent --deny Write --deny Edit --deny Bash`. **`--permission-mode plan` is NOT read-only** — it wrote a file when asked. The allowlist is what blocks writes, on fresh and resumed sessions. | `sessionId` in `--output-format json` | `--resume <id>` | 2026-08-21 |
| opencode | `--agent plan` (built-in read-only agent; write attempt refused, verified incl. on resume) | `sessionID` on every `--format json` event | `--session <id>` | 2026-08-21 |
| kimi | **None.** Prompt mode executes tools including writes without asking. Contract in the prompt + the host's post-round `git status` diff is the only guard. | `session_<uuid>` resume hint on the last stdout line | `-S <id> -p` (documented flag; the hint says `-r`, `-S` is what works) | 2026-07-21 (kimi 0.28.1) |

## Quirks worth knowing

- **codex** reads stdin in addition to the prompt arg; under a non-TTY driver it hangs at 0% CPU waiting for EOF. `< /dev/null` on every call is mandatory. `2>/dev/null` hides cosmetic MCP/auth noise. Needs `codex --version` ≥ 0.130.
- **claude** `--tools` is variadic: anything after it is eaten as a tool name, so the prompt must come before it (the script does this). Nested `claude -p` inside a Claude Code host works, but it reloads ~90k tokens of global context per call — the most expensive seat on the council. Not a reason to skip it; a reason to say so.
- **grok** tool names are internal ids (`read_file`, not `Read`); `--deny` rules use the `Write`/`Edit`/`Bash` prefixes. `--tools`/`--disallowed-tools` are headless-only, which is fine here.
- **opencode** uses the model from `opencode.json`; `--format json` is a JSONL event stream, the critique is the concatenation of `type: "text"` parts.
- **kimi** if the output file is empty or has no resume hint, the run failed (auth/model). If the repo has uncommitted work the user can't afford to risk, drop kimi from the council for that run.
- **gemini** is not adapted. If `gemini` appears on PATH, either add an adapter after verifying its read-only and resume flags the same way (ask it to create a file; confirm it can't), or leave it off. Don't guess flags into the script.

## Adding a CLI

Verify three things empirically before adding a `case` branch: (1) a headless call that returns the critique and a session id; (2) a resume call that recalls the prior round; (3) a write attempt under your chosen flags that fails. Record the date in the table above.
