"""Shared subprocess execution and privilege-check helpers.

Per the project's no-silent-failures rule: a failed command is never
swallowed into an empty/None return. It is logged with full context and
raised, so callers can't mistake "command failed" for "command produced no
output."
"""

from __future__ import annotations

import logging
import os
import shutil
import subprocess

logger = logging.getLogger("steamostools.process")


class PrivilegeError(PermissionError):
    """Raised when a privileged operation is requested but cannot be run."""


def is_root() -> bool:
    return os.geteuid() == 0


def require_root(reason: str) -> None:
    """Raise PrivilegeError if not running as root and sudo is unavailable.

    Args:
        reason: Human-readable description of why root is needed, included
            in the raised error so the user knows what to do.
    """
    if is_root():
        return
    if shutil.which("sudo") is None:
        raise PrivilegeError(
            f"Root privileges required ({reason}), but this process is not "
            "root and 'sudo' is not available on PATH."
        )


def run(
    cmd: list[str],
    *,
    check: bool = True,
    capture: bool = True,
    cwd: str | None = None,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess:
    """Run a command, logging the invocation and outcome.

    Raises subprocess.CalledProcessError (with stderr attached) on failure
    when check=True. Never returns a sentinel value for failure -- callers
    that want to handle failure explicitly should catch the exception.
    """
    logger.debug("Running command: %s", " ".join(cmd))
    try:
        result = subprocess.run(
            cmd,
            check=check,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
            cwd=cwd,
            env=env,
        )
    except subprocess.CalledProcessError as exc:
        logger.error(
            "Command failed: %s (returncode=%d) stderr=%s",
            " ".join(cmd),
            exc.returncode,
            (exc.stderr or "").strip(),
        )
        raise
    except FileNotFoundError as exc:
        logger.error("Command not found: %s (%s)", cmd[0], exc)
        raise

    logger.debug(
        "Command succeeded: %s (returncode=%d)",
        " ".join(cmd),
        result.returncode,
    )
    return result
