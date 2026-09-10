"""Enable X11 forwarding over SSH.

Port of utilities/setup-x11-forwarding.sh.
"""

from __future__ import annotations

import logging
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.x11_forwarding")

SSHD_CONFIG = Path("/etc/ssh/sshd_config")
REQUIRED_LINES = ("X11Forwarding yes", "X11DisplayOffset 10")


def missing_lines(sshd_config: Path = SSHD_CONFIG) -> list[str]:
    if not sshd_config.exists():
        return list(REQUIRED_LINES)
    text = sshd_config.read_text()
    return [line for line in REQUIRED_LINES if line not in text]


def enable_x11_forwarding(sshd_config: Path = SSHD_CONFIG) -> list[str]:
    """Append any missing X11Forwarding directives to sshd_config and
    SIGHUP sshd to pick them up. Returns the lines that were added (empty
    if sshd_config was already configured -- a legitimate no-op, not an
    error)."""
    to_add = missing_lines(sshd_config)
    for line in to_add:
        run(["sudo", "bash", "-c", f'echo "{line}" >> {sshd_config}'])
        logger.info("Added to %s: %s", sshd_config, line)

    if to_add:
        run(["sudo", "bash", "-c", "kill -1 $(cat /var/run/sshd.pid)"])

    if not Path("/usr/bin/xauth").exists():
        logger.warning("xauth is missing -- X11 forwarding needs it to work")

    return to_add


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("x11-forwarding", help="enable X11 forwarding over SSH")
    sub = parser.add_subparsers(dest="x11_forwarding_command", required=True)
    sub.add_parser("enable", help="add X11Forwarding directives to sshd_config").set_defaults(
        func=_cmd_enable
    )


def _cmd_enable(args) -> int:
    enable_x11_forwarding()
    return 0
