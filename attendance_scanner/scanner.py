#!/usr/bin/env python3

import argparse
import asyncio
import json
import os
import re
import sys
import time
import uuid
from dataclasses import dataclass
from typing import Dict, Optional, Tuple


APPLE_COMPANY_ID = 0x004C
IBEACON_PREFIX = bytes([0x02, 0x15])


DEFAULT_SUPABASE_URL = "https://bpfptwqysbouppknzaqk.supabase.co"


_HEX64_RE = re.compile(r"^[0-9a-fA-F]{64}$")


def _looks_like_scanner_key(value: str) -> bool:
    return bool(_HEX64_RE.match(value.strip()))


@dataclass(frozen=True)
class BeaconFrame:
    user_id: str
    token_u32: int
    major: int
    minor: int
    rssi: int


def parse_ibeacon(manufacturer_data: bytes, rssi: int) -> Optional[BeaconFrame]:
    """Parse Apple iBeacon manufacturer data into (uuid, major, minor)."""
    if len(manufacturer_data) < 2 + 16 + 2 + 2 + 1:
        return None

    if manufacturer_data[0:2] != IBEACON_PREFIX:
        return None

    uuid_bytes = manufacturer_data[2:18]
    major = int.from_bytes(manufacturer_data[18:20], byteorder="big")
    minor = int.from_bytes(manufacturer_data[20:22], byteorder="big")

    try:
        user_uuid = str(uuid.UUID(bytes=bytes(uuid_bytes)))
    except Exception:
        return None

    token_u32 = (major << 16) | minor
    return BeaconFrame(
        user_id=user_uuid,
        token_u32=token_u32,
        major=major,
        minor=minor,
        rssi=rssi,
    )


class AttendanceGateway:
    def __init__(
        self,
        supabase_url: str,
        gym_id: int,
        scanner_key: str,
        scanner_id: str,
        min_rssi: int,
    ) -> None:
        self.supabase_url = supabase_url.rstrip("/")
        self.gym_id = gym_id
        self.scanner_key = scanner_key
        self.scanner_id = scanner_id
        self.min_rssi = min_rssi

        # Throttle: (user_id, token_u32) -> last_sent_epoch
        self._last_sent: Dict[Tuple[str, int], float] = {}

        # Scan diagnostics (these are updated from the Bleak callback thread)
        self.adv_seen = 0
        self.adv_with_mfg = 0
        self.adv_ibeacon_prefix = 0
        self.enqueued = 0
        self.dropped_queue_full = 0
        self.poll_cycles = 0
        self.poll_devices = 0
        self.last_poll_at: Optional[float] = None

        self.frames_seen = 0
        self.frames_parsed = 0
        self.requests_sent = 0
        self.requests_ok = 0
        self.requests_err = 0
        self.last_seen: Optional[BeaconFrame] = None
        self.last_ok_at: Optional[float] = None
        self.last_err_at: Optional[float] = None
        self.last_ok: Optional[str] = None
        self.last_err: Optional[str] = None

    def should_send(self, frame: BeaconFrame) -> bool:
        self.frames_seen += 1
        self.last_seen = frame
        if frame.rssi < self.min_rssi:
            return False

        key = (frame.user_id, frame.token_u32)
        now = time.time()
        last = self._last_sent.get(key, 0)
        if now - last < 25:
            return False

        self._last_sent[key] = now
        return True

    def verify(self, frame: BeaconFrame) -> None:
        import requests

        self.requests_sent += 1
        endpoint = f"{self.supabase_url}/functions/v1/attendance-verify-scan"
        headers = {
            "Content-Type": "application/json",
            "x-scanner-key": self.scanner_key,
        }
        payload = {
            "user_id": frame.user_id,
            "gym_id": self.gym_id,
            "token_u32": frame.token_u32,
            "scanner_id": self.scanner_id,
            "rssi": frame.rssi,
        }

        try:
            res = requests.post(endpoint, headers=headers, data=json.dumps(payload), timeout=6)
        except Exception as e:
            self.last_err_at = time.time()
            self.last_err = f"network error: {e}"
            return

        if res.status_code == 200:
            self.requests_ok += 1
            self.last_ok_at = time.time()
            try:
                data = res.json()
            except Exception:
                data = res.text
            self.last_ok = str(data)
            return

        self.requests_err += 1
        self.last_err_at = time.time()
        try:
            err = res.json()
        except Exception:
            err = res.text

        if res.status_code == 401:
            self.last_err = (
                "Unauthorized (401). Verify ATTENDANCE_SCANNER_KEY and that your scanner is registered as active "
                f"for gym_id={self.gym_id} and scanner_id={self.scanner_id}."
            )
        else:
            self.last_err = f"status={res.status_code} -> {err}"


async def main() -> None:
    parser = argparse.ArgumentParser(description="LiftCo attendance scanner gateway")
    parser.add_argument(
        "--supabase-url",
        help="Supabase project URL (e.g. https://<ref>.supabase.co). Can also be set via SUPABASE_URL env var.",
    )
    parser.add_argument(
        "--adapter",
        default=os.environ.get("ATTENDANCE_BLE_ADAPTER"),
        help="Linux BlueZ adapter name (e.g. hci0, hci1). Env: ATTENDANCE_BLE_ADAPTER",
    )
    parser.add_argument(
        "--gym-id",
        type=int,
        help="Gym id (public.gyms.id). Can also be set via ATTENDANCE_GYM_ID env var.",
    )
    parser.add_argument(
        "--scanner-key",
        help="Scanner secret (ATTENDANCE_SCANNER_KEY). Can also be set via ATTENDANCE_SCANNER_KEY env var.",
    )
    parser.add_argument(
        "--scanner-id",
        default=os.environ.get("ATTENDANCE_SCANNER_ID", "laptop-1"),
        help="Identifier stored for audit (default: laptop-1). Env: ATTENDANCE_SCANNER_ID",
    )
    parser.add_argument(
        "--min-rssi",
        default=int(os.environ.get("ATTENDANCE_MIN_RSSI", "-85")),
        type=int,
        help="Ignore weak signals (default: -85). Env: ATTENDANCE_MIN_RSSI",
    )
    parser.add_argument(
        "--strict-apple-id",
        action="store_true",
        help="Only accept iBeacon frames where company_id == 0x004C (Apple). Default: accept any company_id if payload matches iBeacon prefix.",
    )
    parser.add_argument(
        "--debug-adv",
        action="store_true",
        help="Print manufacturer data seen (for debugging when scanner doesn't detect beacons).",
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Print every verify result (OK/ERR). Default: quiet when live UI is enabled.",
    )
    parser.add_argument("--no-ui", action="store_true", help="Disable live UI dashboard")
    parser.add_argument(
        "--scan-seconds",
        type=float,
        default=float(os.environ.get("ATTENDANCE_PREFLIGHT_SECONDS", "1.2")),
        help="Preflight scan duration seconds (default: 1.2). Env: ATTENDANCE_PREFLIGHT_SECONDS",
    )
    args = parser.parse_args()

    try:
        from bleak import BleakScanner
        from rich.console import Console
        from rich.live import Live
        from rich.panel import Panel
        from rich.table import Table
        from rich.prompt import Confirm, IntPrompt, Prompt
    except ModuleNotFoundError as e:
        # Keep --help usable even without deps (argparse exits before this).
        print(
            "Missing Python dependencies. Install them with:\n\n"
            "  python3 -m venv .venv && source .venv/bin/activate\n"
            "  pip install -r attendance_scanner/requirements.txt\n\n"
            f"Error: {e}\n",
            file=sys.stderr,
        )
        sys.exit(2)

    console = Console()

    def explain_secrets() -> None:
        console.print(
            Panel(
                "\n".join(
                    [
                        "[b]Where do I get the scanner key?[/b]",
                        "- You provision it with the admin tool: `python3 attendance_scanner/manage_scanners.py add ...`",
                        "- The key is stored hashed in the database table [b]public.attendance_scanners[/b].",
                        "- Keep the plaintext key in your password manager (you only see it at creation time).",
                        "",
                        "[b]Recommended (avoid shell history):[/b]",
                        "- Export env vars in your current shell session:",
                        "  - SUPABASE_URL=...",
                        "  - ATTENDANCE_SCANNER_ID=...",
                        "  - ATTENDANCE_SCANNER_KEY=...",
                        "  - ATTENDANCE_GYM_ID=...",
                    ]
                ),
                title="Help",
            )
        )

    def require_tty_or_exit(missing_label: str) -> None:
        if sys.stdin is not None and sys.stdin.isatty():
            return
        console.print(
            Panel(
                f"Missing required value: {missing_label}\n\n"
                "This command is running non-interactively, so prompting is disabled.\n"
                "Provide the missing values via flags or environment variables.",
                title="[red]Missing arguments[/red]",
            )
        )
        explain_secrets()
        sys.exit(2)

    # Fill from env first.
    args.supabase_url = (args.supabase_url or os.environ.get("SUPABASE_URL") or DEFAULT_SUPABASE_URL).strip()
    if args.gym_id is None:
        env_gym_id = os.environ.get("ATTENDANCE_GYM_ID")
        if env_gym_id:
            try:
                args.gym_id = int(env_gym_id)
            except ValueError:
                pass
    args.scanner_key = args.scanner_key or os.environ.get("ATTENDANCE_SCANNER_KEY")

    # Interactive prompts for missing values.
    # NOTE: supabase_url defaults to this project's Supabase URL, so it should
    # almost never be missing in practice.
    if not args.supabase_url:
        require_tty_or_exit("--supabase-url / SUPABASE_URL")
        console.print(
            Panel(
                "Enter your Supabase project URL.\n"
                f"Example: {DEFAULT_SUPABASE_URL}",
                title="Supabase URL",
            )
        )
        args.supabase_url = Prompt.ask("Supabase URL").strip()

    if args.gym_id is None:
        require_tty_or_exit("--gym-id / ATTENDANCE_GYM_ID")
        console.print(
            Panel(
                "Enter the gym id (public.gyms.id) that this laptop is scanning for.\n"
                "Tip: pick the gym you are demoing and keep one scanner per gym.",
                title="Gym ID",
            )
        )
        args.gym_id = IntPrompt.ask("Gym ID")

    if not args.scanner_key:
        require_tty_or_exit("--scanner-key / ATTENDANCE_SCANNER_KEY")
        explain_secrets()
        if not Confirm.ask("Continue and enter ATTENDANCE_SCANNER_KEY now?", default=True):
            sys.exit(0)
        console.print(
            Panel(
                "Enter the [b]scanner key[/b] (secret).\n\n"
                "- This is [b]NOT[/b] the scanner_id.\n"
                "- Expected format: 64 hex characters (generated by manage_scanners.py).\n"
                "- If you paste something like 'laptop-1', verification will always return 401.",
                title="Scanner Key",
            )
        )

        while True:
            entered = Prompt.ask("ATTENDANCE_SCANNER_KEY", password=True).strip()
            if _looks_like_scanner_key(entered):
                args.scanner_key = entered
                break
            console.print(
                "[red]That doesn't look like a scanner key.[/red] Expected 64 hex characters. Try again."
            )
    else:
        if not _looks_like_scanner_key(str(args.scanner_key)):
            console.print(
                Panel(
                    "ATTENDANCE_SCANNER_KEY does not look like the expected 64-hex scanner key.\n"
                    "If verification returns 401, double-check you didn't paste scanner_id instead of the key.",
                    title="[yellow]Warning[/yellow]",
                )
            )

    # Final validation.
    if not args.supabase_url.startswith("https://"):
        console.print(
            Panel(
                "Supabase URL should start with https://\n"
                f"Received: {args.supabase_url}",
                title="[red]Invalid SUPABASE_URL[/red]",
            )
        )
        sys.exit(2)

    gateway = AttendanceGateway(
        supabase_url=args.supabase_url,
        gym_id=args.gym_id,
        scanner_key=args.scanner_key,
        scanner_id=args.scanner_id,
        min_rssi=args.min_rssi,
    )

    console.print(
        Panel.fit(
            "\n".join(
                [
                    "[b]LiftCo Attendance Scanner[/b] (iBeacon)",
                    f"Supabase: {args.supabase_url}",
                    f"Gym ID: {args.gym_id}",
                    f"Scanner ID: {args.scanner_id}",
                    f"Min RSSI: {args.min_rssi} dBm",
                    f"Adapter: {args.adapter or '(default)'}",
                ]
            ),
            title="Startup",
        )
    )

    # Preflight: attempt a short scan to ensure BLE works (BlueZ running, permissions ok).
    try:
        kwargs = {}
        if args.adapter:
            kwargs["bluez"] = {"adapter": args.adapter}

        devices = await BleakScanner.discover(timeout=args.scan_seconds, **kwargs)

        # Discover can return empty without raising; treat that as a warning.
        if not devices:
            uid = os.geteuid() if hasattr(os, "geteuid") else None
            console.print(
                Panel(
                    "BLE preflight completed but found 0 devices.\n\n"
                    "Common causes on Linux:\n"
                    "- Bluetooth is off or no adapter present\n"
                    "- BlueZ not running\n"
                    "- Insufficient permissions (try running with sudo for a quick test)\n"
                    "- Wrong adapter selected (use --adapter hci0)\n\n"
                    f"Tip: current euid={uid}",
                    title="[yellow]Preflight warning[/yellow]",
                )
            )
        else:
            console.print(
                f"[green]Preflight OK:[/green] BLE scanning works (saw {len(devices)} devices)"
            )
    except Exception as e:
        console.print(
            Panel(
                f"BLE scan preflight failed: {e}\n\n"
                "On Linux, common fixes:\n"
                "- Ensure BlueZ is running: `sudo systemctl status bluetooth`\n"
                "- Start it if needed: `sudo systemctl start bluetooth`\n"
                "- Check adapter: `bluetoothctl show`\n"
                "- Some distros require running as root or adding capabilities for BLE scan.",
                title="[red]Not Ready[/red]",
            )
        )
        sys.exit(2)

    def detection_callback(device, adv_data):
        gateway.adv_seen += 1
        _handle_advertisement(device.address, adv_data.rssi, adv_data.manufacturer_data)

    def _handle_advertisement(address: str, rssi: int, manufacturer_data) -> None:
        md = manufacturer_data or {}
        if not md:
            return

        gateway.adv_with_mfg += 1

        items = []
        if args.strict_apple_id:
            if APPLE_COMPANY_ID in md:
                items = [(APPLE_COMPANY_ID, md[APPLE_COMPANY_ID])]
        else:
            items = list(md.items())

        if not items:
            return

        frame = None
        for company_id, payload in items:
            try:
                payload_bytes = bytes(payload)
            except Exception:
                payload_bytes = payload

            if payload_bytes[:2] == IBEACON_PREFIX:
                gateway.adv_ibeacon_prefix += 1

            if args.debug_adv:
                head = payload_bytes[:8].hex()
                console.print(
                    f"[dim]ADV[/dim] {address} rssi={rssi} company=0x{company_id:04x} bytes={len(payload_bytes)} head={head}"
                )

            candidate = parse_ibeacon(payload_bytes, rssi)
            if candidate is not None:
                frame = candidate
                break

        if frame is None:
            return

        gateway.frames_parsed += 1

        if not gateway.should_send(frame):
            return

        try:
            verify_queue.put_nowait(frame)
            gateway.enqueued += 1
        except asyncio.QueueFull:
            gateway.dropped_queue_full += 1
            return

    # Don't block Bleak's callback/event loop on network I/O.
    verify_queue: asyncio.Queue[BeaconFrame] = asyncio.Queue(maxsize=256)

    async def verify_worker() -> None:
        while True:
            frame = await verify_queue.get()
            try:
                before_ok = gateway.requests_ok
                before_err = gateway.requests_err
                await asyncio.to_thread(gateway.verify, frame)

                should_print = args.no_ui or args.verbose
                if should_print:
                    if gateway.requests_ok != before_ok:
                        console.print(
                            f"[green][OK][/green] {frame.user_id} token={frame.token_u32} rssi={frame.rssi} -> {gateway.last_ok}"
                        )
                    elif gateway.requests_err != before_err:
                        console.print(
                            f"[red][ERR][/red] {frame.user_id} token={frame.token_u32} rssi={frame.rssi} -> {gateway.last_err}"
                        )
            finally:
                verify_queue.task_done()

    scanner_kwargs = {}
    if args.adapter:
        scanner_kwargs["bluez"] = {"adapter": args.adapter}

    scanner = BleakScanner(detection_callback=detection_callback, **scanner_kwargs)

    worker_task = asyncio.create_task(verify_worker())

    async def poll_worker() -> None:
        """Fallback for platforms/backends where detection_callback is flaky.

        On some Linux/BlueZ setups, Bleak's callback may not fire even though the
        scanner collects discovered devices. Polling the discovered map keeps the
        UI/live metrics moving and still lets us parse manufacturer data.
        """

        # Small initial delay so the scanner can start.
        await asyncio.sleep(0.25)
        while True:
            await asyncio.sleep(0.75)
            gateway.poll_cycles += 1
            gateway.last_poll_at = time.time()

            try:
                discovered = getattr(scanner, "discovered_devices_and_advertisement_data", {})
                gateway.poll_devices = len(discovered)
                if not discovered:
                    continue

                for _addr, (dev, adv) in list(discovered.items()):
                    _handle_advertisement(getattr(dev, "address", "?"), adv.rssi, adv.manufacturer_data)
            except Exception as e:
                # Don't crash scanning on occasional backend issues.
                gateway.last_err_at = time.time()
                gateway.last_err = f"poll error: {e}"

    poll_task = asyncio.create_task(poll_worker())

    def render_table() -> Table:
        t = Table(title="Scanner Status", expand=True)
        t.add_column("Metric")
        t.add_column("Value", justify="right")
        t.add_row("Adv callbacks", str(gateway.adv_seen))
        t.add_row("Poll cycles", str(gateway.poll_cycles))
        t.add_row("Poll devices", str(gateway.poll_devices))
        t.add_row("Adv w/ manufacturer", str(gateway.adv_with_mfg))
        t.add_row("iBeacon prefix seen", str(gateway.adv_ibeacon_prefix))
        t.add_row("Frames seen", str(gateway.frames_seen))
        t.add_row("iBeacon parsed", str(gateway.frames_parsed))
        t.add_row("Enqueued", str(gateway.enqueued))
        if gateway.dropped_queue_full:
            t.add_row("Dropped (queue full)", f"[red]{gateway.dropped_queue_full}[/red]")
        t.add_row("Verify requests", str(gateway.requests_sent))
        t.add_row("Verify OK", f"[green]{gateway.requests_ok}[/green]")
        t.add_row("Verify ERR", f"[red]{gateway.requests_err}[/red]")
        if gateway.last_seen:
            t.add_row("Last UUID", gateway.last_seen.user_id)
            t.add_row("Last token_u32", str(gateway.last_seen.token_u32))
            t.add_row("Last RSSI", f"{gateway.last_seen.rssi} dBm")
        if gateway.last_ok_at:
            t.add_row("Last OK", time.strftime('%H:%M:%S', time.localtime(gateway.last_ok_at)))
        if gateway.last_err_at:
            t.add_row("Last ERR", time.strftime('%H:%M:%S', time.localtime(gateway.last_err_at)))
        if gateway.last_err:
            t.add_row("Last error", gateway.last_err)
        return t

    console.print("Scanning for iBeacon frames… (Ctrl+C to stop)")
    try:
        async with scanner:
            if args.no_ui:
                while True:
                    await asyncio.sleep(1)
            else:
                with Live(render_table(), console=console, refresh_per_second=4):
                    while True:
                        await asyncio.sleep(0.25)
    finally:
        worker_task.cancel()
        poll_task.cancel()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
