"""Unlock the read-only SteamOS filesystem and install base dev tools.

Port of utilities/unlock-steam-deck.sh.
"""

from __future__ import annotations

import logging

from steamostools.platform_detect import Platform, require_platform
from steamostools.process import run

logger = logging.getLogger("steamostools.unlock")


def unlock_and_prepare() -> None:
    """Disable the read-only filesystem, refresh the pacman keyring, and
    install base-devel. Raises on the first failing step -- these steps
    are not independent, so continuing after a failure would leave the
    system in a half-configured state."""
    require_platform(Platform.STEAMOS_ARCH)

    logger.info("Unlocking filesystem")
    run(["sudo", "steamos-readonly", "disable"])

    logger.info("Adding/updating Arch Linux keyrings")
    run(["sudo", "pacman-key", "--init"])
    run(["sudo", "pacman-key", "--populate", "holo"])

    logger.info("Updating repository index")
    run(["sudo", "pacman", "-Syy"])

    logger.info("Installing basic devtools")
    run(["sudo", "pacman", "-S", "--noconfirm", "base-devel"])


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "unlock", help="disable the SteamOS read-only filesystem and install base-devel"
    )
    parser.set_defaults(func=_cmd_unlock)


def _cmd_unlock(args) -> int:
    unlock_and_prepare()
    return 0
