#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "google-api-python-client>=2.0",
#   "google-auth-oauthlib>=1.2",
#   "google-auth>=2.0",
# ]
# ///
"""Google Tasks CLI for the gtasks Claude Code skill.

All output is single-line JSON: success on stdout (exit 0), errors on stderr
with a non-zero exit code. Run any subcommand with --help for argument detail.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("GTASKS_CONFIG_DIR", str(Path.home() / ".config" / "gtasks")))
OAUTH_KEYS = CONFIG_DIR / "oauth-keys.json"
CREDENTIALS = CONFIG_DIR / "credentials.json"
SCOPES = ["https://www.googleapis.com/auth/tasks"]
MAX_RESULTS = 100

EXIT_USAGE = 1
EXIT_AUTH = 2
EXIT_API = 3


class GTasksError(Exception):
    def __init__(self, message: str, code: str, exit_code: int) -> None:
        super().__init__(message)
        self.code = code
        self.exit_code = exit_code


def fail(message: str, code: str, exit_code: int) -> None:
    raise GTasksError(message, code, exit_code)


def normalize_due_date(due: str | None) -> str | None:
    """Mirror src/Tasks.ts normalizeDueDate: emit RFC 3339 at UTC midnight."""
    if due is None or due == "":
        return None
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", due):
        return f"{due}T00:00:00.000Z"
    try:
        dt = datetime.fromisoformat(due.replace("Z", "+00:00"))
    except ValueError:
        fail(
            f'Invalid due date format: "{due}". Use YYYY-MM-DD or ISO 8601 format.',
            code="USAGE",
            exit_code=EXIT_USAGE,
        )
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    dt_utc = dt.astimezone(timezone.utc)
    return dt_utc.strftime("%Y-%m-%dT00:00:00.000Z")


def get_service():
    """Build the authenticated Tasks v1 client, refreshing tokens if needed."""
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from googleapiclient.discovery import build

    if not CREDENTIALS.exists():
        fail(
            f"Credentials not found at {CREDENTIALS}. Run `gtasks.py auth` first.",
            code="AUTH_MISSING",
            exit_code=EXIT_AUTH,
        )

    creds = Credentials.from_authorized_user_file(str(CREDENTIALS), SCOPES)
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            creds.refresh(Request())
            CREDENTIALS.write_text(creds.to_json())
            os.chmod(CREDENTIALS, 0o600)
        else:
            fail(
                "Saved credentials are invalid or expired. Re-run `gtasks.py auth`.",
                code="AUTH_MISSING",
                exit_code=EXIT_AUTH,
            )

    return build("tasks", "v1", credentials=creds, cache_discovery=False)


def project_task(task: dict) -> dict:
    """Trim an API task to the fields callers actually need."""
    return {
        "id": task.get("id"),
        "title": task.get("title"),
        "notes": task.get("notes"),
        "due": task.get("due"),
        "status": task.get("status"),
        "completed": task.get("completed"),
        "updated": task.get("updated"),
        "selfLink": task.get("selfLink"),
        "parent": task.get("parent"),
        "position": task.get("position"),
    }


def cmd_auth(_args: argparse.Namespace) -> dict:
    from google_auth_oauthlib.flow import InstalledAppFlow

    if not OAUTH_KEYS.exists():
        fail(
            f"OAuth client keys not found at {OAUTH_KEYS}. See scripts/SETUP.md.",
            code="AUTH_MISSING",
            exit_code=EXIT_AUTH,
        )

    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(CONFIG_DIR, 0o700)

    flow = InstalledAppFlow.from_client_secrets_file(str(OAUTH_KEYS), SCOPES)
    with contextlib.redirect_stdout(sys.stderr):
        creds = flow.run_local_server(port=0, open_browser=True)

    CREDENTIALS.write_text(creds.to_json())
    os.chmod(CREDENTIALS, 0o600)
    return {"ok": True, "credentialsPath": str(CREDENTIALS)}


def cmd_list_tasklists(_args: argparse.Namespace) -> dict:
    service = get_service()
    response = service.tasklists().list(maxResults=MAX_RESULTS).execute()
    items = [{"id": tl["id"], "title": tl["title"]} for tl in response.get("items", [])]
    return {"ok": True, "lists": items}


def fetch_all_tasklist_ids(service) -> list[str]:
    response = service.tasklists().list(maxResults=MAX_RESULTS).execute()
    return [tl["id"] for tl in response.get("items", []) if tl.get("id")]


def cmd_list(args: argparse.Namespace) -> dict:
    service = get_service()
    tasks: list[dict] = []
    next_token: str | None = None

    if args.list:
        params = {"tasklist": args.list, "maxResults": MAX_RESULTS}
        if args.cursor:
            params["pageToken"] = args.cursor
        response = service.tasks().list(**params).execute()
        tasks.extend(project_task(t) for t in response.get("items", []))
        next_token = response.get("nextPageToken")
    else:
        for tasklist_id in fetch_all_tasklist_ids(service):
            response = service.tasks().list(tasklist=tasklist_id, maxResults=MAX_RESULTS).execute()
            for t in response.get("items", []):
                projected = project_task(t)
                projected["tasklistId"] = tasklist_id
                tasks.append(projected)
            if response.get("nextPageToken"):
                next_token = response["nextPageToken"]

    return {"ok": True, "tasks": tasks, "nextPageToken": next_token}


def cmd_search(args: argparse.Namespace) -> dict:
    service = get_service()
    query = args.query.lower()
    matches: list[dict] = []

    list_ids = [args.list] if args.list else fetch_all_tasklist_ids(service)
    for tasklist_id in list_ids:
        response = service.tasks().list(tasklist=tasklist_id, maxResults=MAX_RESULTS).execute()
        for t in response.get("items", []):
            title = (t.get("title") or "").lower()
            notes = (t.get("notes") or "").lower()
            if query in title or query in notes:
                projected = project_task(t)
                projected["tasklistId"] = tasklist_id
                matches.append(projected)

    return {"ok": True, "tasks": matches}


def cmd_create(args: argparse.Namespace) -> dict:
    service = get_service()
    body: dict[str, str] = {"title": args.title}
    if args.notes:
        body["notes"] = args.notes
    due = normalize_due_date(args.due)
    if due:
        body["due"] = due

    result = service.tasks().insert(tasklist=args.list, body=body).execute()
    task = project_task(result)
    task["tasklistId"] = args.list
    return {"ok": True, "task": task}


def cmd_update(args: argparse.Namespace) -> dict:
    service = get_service()
    body: dict[str, str] = {"id": args.id}
    if args.title is not None:
        body["title"] = args.title
    if args.notes is not None:
        body["notes"] = args.notes
    if args.status is not None:
        body["status"] = args.status
    due = normalize_due_date(args.due)
    if due:
        body["due"] = due

    result = service.tasks().patch(tasklist=args.list, task=args.id, body=body).execute()
    task = project_task(result)
    task["tasklistId"] = args.list
    return {"ok": True, "task": task}


def cmd_delete(args: argparse.Namespace) -> dict:
    service = get_service()
    service.tasks().delete(tasklist=args.list, task=args.id).execute()
    return {"ok": True, "id": args.id, "tasklistId": args.list}


def cmd_clear(args: argparse.Namespace) -> dict:
    service = get_service()
    service.tasks().clear(tasklist=args.list).execute()
    return {"ok": True, "tasklistId": args.list}


class JSONErrorParser(argparse.ArgumentParser):
    """Emit the same JSON envelope on parse errors that handlers emit at runtime."""

    def error(self, message: str) -> None:  # type: ignore[override]
        print(json.dumps({"ok": False, "error": message, "code": "USAGE"}), file=sys.stderr)
        raise SystemExit(EXIT_USAGE)


def build_parser() -> argparse.ArgumentParser:
    parser = JSONErrorParser(
        prog="gtasks.py",
        description="Google Tasks CLI for the gtasks Claude Code skill.",
    )
    subs = parser.add_subparsers(dest="command", required=True, parser_class=JSONErrorParser)

    subs.add_parser("auth", help="Run OAuth flow and save credentials.")
    subs.add_parser("list-tasklists", help="List all task lists with id and title.")

    p_list = subs.add_parser("list", help="List tasks (all lists by default).")
    p_list.add_argument("--list", help="Restrict to a specific task list id.")
    p_list.add_argument("--cursor", help="Page token for pagination.")

    p_search = subs.add_parser("search", help="Filter tasks by title or notes substring.")
    p_search.add_argument("--query", required=True)
    p_search.add_argument("--list", help="Restrict to a specific task list id.")

    p_create = subs.add_parser("create", help="Create a task.")
    p_create.add_argument("--title", required=True)
    p_create.add_argument("--list", default="@default", help="Task list id (default: @default).")
    p_create.add_argument("--due", help="YYYY-MM-DD or ISO 8601.")
    p_create.add_argument("--notes")

    p_update = subs.add_parser("update", help="Patch fields on an existing task.")
    p_update.add_argument("--id", required=True)
    p_update.add_argument("--list", default="@default", help="Task list id (default: @default).")
    p_update.add_argument("--title")
    p_update.add_argument("--notes")
    p_update.add_argument("--status", choices=["needsAction", "completed"])
    p_update.add_argument("--due", help="YYYY-MM-DD or ISO 8601.")

    p_delete = subs.add_parser("delete", help="Delete a task.")
    p_delete.add_argument("--id", required=True)
    p_delete.add_argument("--list", required=True, help="Task list id.")

    p_clear = subs.add_parser("clear", help="Remove completed tasks from a list.")
    p_clear.add_argument("--list", default="@default", help="Task list id (default: @default).")

    return parser


HANDLERS = {
    "auth": cmd_auth,
    "list-tasklists": cmd_list_tasklists,
    "list": cmd_list,
    "search": cmd_search,
    "create": cmd_create,
    "update": cmd_update,
    "delete": cmd_delete,
    "clear": cmd_clear,
}


def main() -> int:
    args = build_parser().parse_args()
    try:
        result = HANDLERS[args.command](args)
    except GTasksError as exc:
        print(json.dumps({"ok": False, "error": str(exc), "code": exc.code}), file=sys.stderr)
        return exc.exit_code
    except Exception as exc:
        from googleapiclient.errors import HttpError
        if isinstance(exc, HttpError):
            try:
                detail = json.loads(exc.content).get("error", {}).get("message", str(exc))
            except Exception:
                detail = str(exc)
            print(json.dumps({"ok": False, "error": detail, "code": "API_ERROR"}), file=sys.stderr)
            return EXIT_API
        print(json.dumps({"ok": False, "error": str(exc), "code": "API_ERROR"}), file=sys.stderr)
        return EXIT_API
    print(json.dumps(result))
    return 0


if __name__ == "__main__":
    sys.exit(main())
