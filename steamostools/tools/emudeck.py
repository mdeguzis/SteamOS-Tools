"""Trigger EmuDeck's own bundled updater scripts.

Port of utilities/update-emudeck.sh -- this is a thin delegation shim, not
a reimplementation of EmuDeck's update logic (which lives in, and changes
with, EmuDeck itself).
"""

from __future__ import annotations

import logging
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.emudeck")

EMUDECK_TOOLS_DIR = Path.home() / ".config" / "EmuDeck" / "backend" / "tools"


class EmuDeckNotInstalledError(RuntimeError):
    pass


def updater_paths(tools_dir: Path = EMUDECK_TOOLS_DIR) -> tuple[Path, Path]:
    return tools_dir / "flatpakupdate" / "flatpakupdate.sh", tools_dir / "binupdate" / "binupdate.sh"


def update_emudeck(tools_dir: Path = EMUDECK_TOOLS_DIR) -> None:
    """Run EmuDeck's bundled flatpak and binary updaters. Raises
    EmuDeckNotInstalledError if either is missing, rather than silently
    doing nothing."""
    flatpak_updater, bin_updater = updater_paths(tools_dir)
    for updater in (flatpak_updater, bin_updater):
        if not updater.exists():
            raise EmuDeckNotInstalledError(f"{updater} not found -- is EmuDeck installed?")

    logger.info("Running EmuDeck flatpak updater")
    run(["bash", str(flatpak_updater)], capture=False)
    logger.info("Running EmuDeck binary updater")
    run(["bash", str(bin_updater)], capture=False)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("emudeck", help="run EmuDeck's bundled updaters")
    sub = parser.add_subparsers(dest="emudeck_command", required=True)
    sub.add_parser("update", help="update EmuDeck-managed emulators/binaries").set_defaults(
        func=_cmd_update
    )


def _cmd_update(args) -> int:
    update_emudeck()
    return 0
