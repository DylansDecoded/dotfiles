#!/usr/bin/env python3
"""PostToolUse hook for ExitPlanMode.

Fires the moment a plan is finalized and nudges Claude to generate an executive
HTML brief via the plan-executive-brief skill. The hook does no summarization
itself — distilling a plan needs judgment, so that work belongs to Claude. The
hook only injects a cue.

Wired in settings.json:
  "PostToolUse": [{ "matcher": "ExitPlanMode",
    "hooks": [{ "type": "command",
      "command": "python3 /Users/dylan/.claude/skills/plan-executive-brief/scripts/plan_brief_hook.py" }] }]
"""
import json
import sys

PLANS_DIR = "/Users/dylan/.claude/plans"

# Best-effort rejection detection: if the user rejected the plan, Claude stays
# in plan mode (and can't write files), so there's nothing to generate.
REJECTION_MARKERS = (
    "doesn't want to proceed",
    "does not want to proceed",
    "keep planning",
    "not approved",
    "rejected the plan",
    "wants to continue planning",
)

CONTEXT = (
    "A plan was just finalized via ExitPlanMode. If the plan was approved and "
    "plan mode has been exited, invoke the `plan-executive-brief` skill now to "
    f"produce an executive HTML brief from the most recent plan file in {PLANS_DIR}, "
    "then continue with the user's request. If the user rejected the plan, ignore this."
)


def main():
    try:
        payload = json.load(sys.stdin)
    except Exception:
        payload = {}

    response_blob = json.dumps(payload.get("tool_response", "")).lower()
    if any(marker in response_blob for marker in REJECTION_MARKERS):
        sys.exit(0)  # plan not approved; nothing to do

    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": CONTEXT,
        }
    }))
    sys.exit(0)


if __name__ == "__main__":
    main()
