#!/usr/bin/env python3

import argparse
import os
import secrets
import sys
import time
from dataclasses import dataclass
from typing import Any, Dict, List, Optional


def sha256_hex(value: str) -> str:
    import hashlib

    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def require_env(name: str) -> str:
    value = os.environ.get(name)
    if value:
        return value
    print(f"Missing env var: {name}")
    print(
        "Set these before running:\n"
        "  export SUPABASE_URL=https://<ref>.supabase.co\n"
        "  export SUPABASE_SERVICE_ROLE_KEY=<service_role_key>\n",
        file=sys.stderr,
    )
    sys.exit(2)


def postgrest_request(method: str, url: str, headers: Dict[str, str], json: Any = None):
    import requests

    return requests.request(method, url, headers=headers, json=json, timeout=10)


def make_headers(service_role_key: str) -> Dict[str, str]:
    return {
        "apikey": service_role_key,
        "Authorization": f"Bearer {service_role_key}",
        "Content-Type": "application/json",
    }


@dataclass
class ScannerRow:
    id: str
    gym_id: int
    scanner_id: str
    key_hint: Optional[str]
    is_active: bool
    created_at: str
    revoked_at: Optional[str]


def list_scanners(base_url: str, headers: Dict[str, str], gym_id: int) -> List[ScannerRow]:
    from urllib.parse import quote

    # Filter: gym_id=eq.<id>
    endpoint = (
        f"{base_url}/rest/v1/attendance_scanners"
        f"?gym_id=eq.{gym_id}"
        f"&select=id,gym_id,scanner_id,key_hint,is_active,created_at,revoked_at"
        f"&order=created_at.desc"
    )

    res = postgrest_request("GET", endpoint, headers=headers)
    if res.status_code != 200:
        raise RuntimeError(f"List failed ({res.status_code}): {res.text}")

    rows = res.json()
    return [
        ScannerRow(
            id=r["id"],
            gym_id=r["gym_id"],
            scanner_id=r["scanner_id"],
            key_hint=r.get("key_hint"),
            is_active=r.get("is_active", False),
            created_at=r.get("created_at", ""),
            revoked_at=r.get("revoked_at"),
        )
        for r in rows
    ]


def add_scanner(base_url: str, headers: Dict[str, str], gym_id: int, scanner_id: str, key: Optional[str]) -> None:
    try:
        from rich.console import Console
        from rich.panel import Panel
        from rich.prompt import Confirm, Prompt
    except ModuleNotFoundError:
        print("Install UI deps: pip install -r attendance_scanner/requirements.txt", file=sys.stderr)
        sys.exit(2)

    console = Console()

    if scanner_id.strip() == "":
        raise RuntimeError("scanner_id cannot be empty")

    if key is None:
        # 32 bytes -> 43 chars base64url-ish; we keep hex for copy/paste.
        key = secrets.token_hex(32)
    else:
        # We expect a 64-hex token (token_hex(32)). If someone pastes a label
        # like 'laptop-1' here, provisioning will succeed but scanners will
        # always get 401 Unauthorized.
        import re

        if not re.fullmatch(r"[0-9a-fA-F]{64}", key.strip()):
            console.print(
                Panel(
                    "The provided --scanner-key does not look like the expected 64-hex key.\n"
                    "Proceeding will likely break verification (401 Unauthorized).\n\n"
                    "Tip: omit --scanner-key to generate a correct key automatically.",
                    title="[yellow]Warning[/yellow]",
                )
            )

    key_hash = sha256_hex(key)
    key_hint = key[-6:]  # last 6 chars (non-sensitive hint)

    payload = {
        "gym_id": gym_id,
        "scanner_id": scanner_id,
        "key_hash_sha256_hex": key_hash,
        "key_hint": key_hint,
        "is_active": True,
    }

    console.print(
        Panel(
            "\n".join(
                [
                    "This will register a scanner key for a gym.",
                    "- The key is stored hashed (SHA-256).",
                    "- You will only see the plaintext key now.",
                    "- scanner_id is just a label (e.g. laptop-1).",
                ]
            ),
            title="Register Scanner",
        )
    )

    if not Confirm.ask(f"Create scanner '{scanner_id}' for gym_id={gym_id}?", default=True):
        return

    endpoint = f"{base_url}/rest/v1/attendance_scanners"
    res = postgrest_request("POST", endpoint, headers=headers, json=payload)

    if res.status_code not in (200, 201):
        raise RuntimeError(f"Insert failed ({res.status_code}): {res.text}")

    console.print(
        Panel(
            "\n".join(
                [
                    "[green]Scanner registered.[/green]",
                    "",
                    "Set these on the laptop that will run the scanner:",
                    f"  export SUPABASE_URL={base_url}",
                    f"  export ATTENDANCE_GYM_ID={gym_id}",
                    f"  export ATTENDANCE_SCANNER_ID={scanner_id}",
                    f"  export ATTENDANCE_SCANNER_KEY={key}",
                    "",
                    "Then run:",
                    "  python3 attendance_scanner/scanner.py",
                    "",
                    "Notes:",
                    "- ATTENDANCE_SCANNER_ID is the label you chose above.",
                    "- ATTENDANCE_SCANNER_KEY is the secret (64-hex).",
                ]
            ),
            title="Provisioning",
        )
    )


def revoke_scanner(base_url: str, headers: Dict[str, str], gym_id: int) -> None:
    try:
        from rich.console import Console
        from rich.panel import Panel
        from rich.prompt import Confirm, IntPrompt, Prompt
        from rich.table import Table
    except ModuleNotFoundError:
        print("Install UI deps: pip install -r attendance_scanner/requirements.txt", file=sys.stderr)
        sys.exit(2)

    console = Console()

    scanners = list_scanners(base_url, headers, gym_id)
    if not scanners:
        console.print(Panel(f"No scanners found for gym_id={gym_id}", title="Nothing to revoke"))
        return

    table = Table(title=f"Scanners for gym_id={gym_id}")
    table.add_column("#")
    table.add_column("scanner_id")
    table.add_column("active")
    table.add_column("key_hint")
    table.add_column("created_at")
    table.add_column("revoked_at")

    for idx, s in enumerate(scanners, start=1):
        table.add_row(
            str(idx),
            s.scanner_id,
            "yes" if s.is_active else "no",
            s.key_hint or "",
            s.created_at,
            s.revoked_at or "",
        )

    console.print(table)

    choice = IntPrompt.ask("Revoke which scanner number?", default=1)
    if choice < 1 or choice > len(scanners):
        console.print("Invalid choice")
        return

    target = scanners[choice - 1]

    if not target.is_active:
        console.print(Panel("That scanner is already inactive.", title="No-op"))
        return

    reason = Prompt.ask("Reason (optional)", default="")
    if not Confirm.ask(f"Revoke scanner '{target.scanner_id}'?", default=False):
        return

    patch_endpoint = f"{base_url}/rest/v1/attendance_scanners?id=eq.{target.id}"
    payload = {
        "is_active": False,
        "revoked_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "revoked_reason": reason or None,
    }

    res = postgrest_request("PATCH", patch_endpoint, headers=headers, json=payload)
    if res.status_code not in (200, 204):
        raise RuntimeError(f"Revoke failed ({res.status_code}): {res.text}")

    console.print(Panel("[green]Revoked.[/green]", title="Done"))


def main() -> None:
    parser = argparse.ArgumentParser(description="Manage LiftCo attendance scanner keys")
    sub = parser.add_subparsers(dest="cmd", required=True)

    add = sub.add_parser("add", help="Register a scanner key for a gym")
    add.add_argument("--gym-id", type=int, required=True)
    add.add_argument("--scanner-id", required=True)
    add.add_argument(
        "--scanner-key",
        help="Optional plaintext key to register; if omitted, a secure random key is generated.",
    )

    rm = sub.add_parser("revoke", help="Revoke (disable) a scanner key for a gym")
    rm.add_argument("--gym-id", type=int, required=True)

    ls = sub.add_parser("list", help="List scanners for a gym")
    ls.add_argument("--gym-id", type=int, required=True)

    args = parser.parse_args()

    supabase_url = require_env("SUPABASE_URL").rstrip("/")
    service_role = require_env("SUPABASE_SERVICE_ROLE_KEY").strip()

    base_url = supabase_url
    headers = make_headers(service_role)

    if args.cmd == "add":
        add_scanner(base_url, headers, args.gym_id, args.scanner_id, args.scanner_key)
    elif args.cmd == "revoke":
        revoke_scanner(base_url, headers, args.gym_id)
    elif args.cmd == "list":
        try:
            from rich.console import Console
            from rich.table import Table
        except ModuleNotFoundError:
            print("Install UI deps: pip install -r attendance_scanner/requirements.txt", file=sys.stderr)
            sys.exit(2)

        console = Console()
        rows = list_scanners(base_url, headers, args.gym_id)
        table = Table(title=f"Scanners for gym_id={args.gym_id}")
        table.add_column("scanner_id")
        table.add_column("active")
        table.add_column("key_hint")
        table.add_column("created_at")
        table.add_column("revoked_at")
        for r in rows:
            table.add_row(
                r.scanner_id,
                "yes" if r.is_active else "no",
                r.key_hint or "",
                r.created_at,
                r.revoked_at or "",
            )
        console.print(table)


if __name__ == "__main__":
    main()
