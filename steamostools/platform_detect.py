"""Distro/platform detection.

Several existing scripts assumed a single distro flavor (pacman-only,
Fedora ostree-only) and failed with confusing errors deep inside a package
manager call when run on the wrong one. This module lets a tool assert its
requirement up front with a clear message instead.
"""

from __future__ import annotations

import shutil
from enum import Enum
from pathlib import Path


class Platform(Enum):
    STEAMOS_ARCH = "steamos-arch"
    CHIMERAOS = "chimeraos"
    BAZZITE_OSTREE = "bazzite-ostree"
    UNSUPPORTED = "unsupported"


class UnsupportedPlatformError(RuntimeError):
    """Raised when a tool requires a platform it did not detect."""


def _read_os_release(path: Path = Path("/etc/os-release")) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(errors="replace").splitlines():
        if "=" not in line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip().strip('"')
    return values


def detect_platform() -> Platform:
    os_release = _read_os_release()
    os_id = os_release.get("ID", "")
    id_like = os_release.get("ID_LIKE", "")

    if Path("/usr/bin/frzr-unlock").exists():
        return Platform.CHIMERAOS
    if shutil.which("rpm-ostree") is not None:
        return Platform.BAZZITE_OSTREE
    if os_id == "arch" or "arch" in id_like:
        return Platform.STEAMOS_ARCH
    return Platform.UNSUPPORTED


def require_platform(*allowed: Platform) -> Platform:
    """Assert the current platform is one of `allowed`, or raise a clear error."""
    current = detect_platform()
    if current not in allowed:
        allowed_names = ", ".join(p.value for p in allowed)
        raise UnsupportedPlatformError(
            f"This tool requires one of: {allowed_names}. Detected: {current.value}."
        )
    return current
