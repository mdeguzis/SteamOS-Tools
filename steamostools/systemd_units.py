"""systemd --user unit lifecycle helper.

Replaces the copy-pasted install/enable/disable systemd blocks found in
the screenshot-sync scripts.
"""

from __future__ import annotations

import logging
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.systemd_units")

USER_UNIT_DIR = Path.home() / ".config" / "systemd" / "user"


class SystemdUserUnit:
    """Manage the lifecycle of one or more systemd --user unit files sharing
    a name prefix (e.g. "sync-screenshots" -> .path/.service/.timer)."""

    def __init__(self, unit_names: list[str], unit_dir: Path = USER_UNIT_DIR):
        self.unit_names = unit_names
        self.unit_dir = unit_dir

    def install(self, unit_sources: dict[str, str]) -> None:
        """Write unit file contents (name -> content) into the user unit dir."""
        self.unit_dir.mkdir(parents=True, exist_ok=True)
        for name, content in unit_sources.items():
            dest = self.unit_dir / name
            dest.write_text(content)
            logger.info("Installed systemd user unit: %s", dest)
        self.daemon_reload()

    def enable_now(self) -> None:
        for name in self.unit_names:
            run(["systemctl", "--user", "enable", "--now", name])
            logger.info("Enabled systemd user unit: %s", name)

    def disable(self) -> None:
        for name in self.unit_names:
            run(["systemctl", "--user", "disable", "--now", name], check=False)
            logger.info("Disabled systemd user unit: %s", name)

    def status(self, name: str) -> str:
        result = run(["systemctl", "--user", "status", name], check=False)
        return result.stdout

    def daemon_reload(self) -> None:
        run(["systemctl", "--user", "daemon-reload"])

    def uninstall(self) -> None:
        self.disable()
        for name in self.unit_names:
            unit_file = self.unit_dir / name
            if unit_file.exists():
                unit_file.unlink()
                logger.info("Removed systemd user unit file: %s", unit_file)
        self.daemon_reload()
