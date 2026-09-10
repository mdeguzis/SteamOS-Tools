"""Trigger a Decky Cloud Save backup via its bundled rclone binary.

Port of utilities/steam-deck/run-decky-cloud-save.sh.
"""

from __future__ import annotations

import logging
import socket
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.decky_cloud_save")

DECKY_HOMEBREW_DIR = Path.home() / "homebrew"
RCLONE_BIN = DECKY_HOMEBREW_DIR / "plugins" / "decky-cloud-save" / "rclone"
FILTER_FILE = DECKY_HOMEBREW_DIR / "settings" / "decky-cloud-save" / "sync_paths_filter.txt"


class DeckyCloudSaveNotInstalledError(RuntimeError):
    pass


def run_backup(
    *,
    hostname: str | None = None,
    rclone_bin: Path = RCLONE_BIN,
    filter_file: Path = FILTER_FILE,
) -> None:
    if not rclone_bin.exists():
        raise DeckyCloudSaveNotInstalledError(
            f"{rclone_bin} not found -- is the Decky Cloud Save plugin installed?"
        )
    hostname = hostname or socket.gethostname()
    run(
        [
            str(rclone_bin), "copy",
            "--filter-from", str(filter_file),
            "/", f"backend:decky-cloud-save-{hostname}",
            "--copy-links", "--verbose", "--verbose",
        ],
        capture=False,
    )
    logger.info("Decky Cloud Save backup complete for host %s", hostname)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("decky-cloud-save", help="trigger a Decky Cloud Save backup")
    sub = parser.add_subparsers(dest="decky_cloud_save_command", required=True)
    sub.add_parser("backup", help="run the bundled rclone copy").set_defaults(func=_cmd_backup)


def _cmd_backup(args) -> int:
    run_backup()
    return 0
