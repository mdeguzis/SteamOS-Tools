"""Generic "sync a local folder to an rclone remote" helper.

Collapses what were 4 near/fully-duplicate bash scripts
(gdrive-path-sync/*, steam-screenshot-sync/*) into one parameterized module.

Unlike the original scripts, this does NOT self-install a pinned rclone
version from a zip -- that was flagged as stale/fragile in the conversion
survey. rclone is a standard Arch/Bazzite package; installation is left to
the system package manager, and `check_available()` raises a clear error
pointing that out if it's missing.
"""

from __future__ import annotations

import logging
import shutil
from dataclasses import dataclass
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.rclone_sync")


class RcloneNotAvailableError(RuntimeError):
    pass


@dataclass
class RcloneRemoteTarget:
    remote_name: str
    remote_path: str

    @property
    def remote_spec(self) -> str:
        return f"{self.remote_name}:{self.remote_path}"


class RcloneSync:
    def __init__(
        self,
        source_dir: Path,
        remote: RcloneRemoteTarget,
        *,
        excludes: list[str] | None = None,
    ):
        self.source_dir = source_dir
        self.remote = remote
        self.excludes = excludes or []

    def check_available(self) -> None:
        if shutil.which("rclone") is None:
            raise RcloneNotAvailableError(
                "rclone is not on PATH. Install it via your package manager "
                "(e.g. `sudo pacman -S rclone`) and configure a remote with "
                "`rclone config` before running this tool."
            )

    def mkdir_remote(self) -> None:
        self.check_available()
        run(["rclone", "mkdir", self.remote.remote_spec])
        logger.info("Ensured remote directory exists: %s", self.remote.remote_spec)

    def list_remote(self) -> list[str]:
        self.check_available()
        result = run(["rclone", "lsf", self.remote.remote_spec])
        return [line for line in result.stdout.splitlines() if line]

    def sync(self) -> None:
        """One-way sync: source_dir -> remote."""
        self.check_available()
        cmd = ["rclone", "sync", "-vv", "-L", "-P", str(self.source_dir), self.remote.remote_spec]
        for pattern in self.excludes:
            cmd.append(f"--exclude={pattern}")
        run(cmd, capture=False)
        logger.info("Synced %s -> %s", self.source_dir, self.remote.remote_spec)
