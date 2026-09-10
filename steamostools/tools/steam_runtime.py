"""Fixes for the bundled Steam Linux Runtime conflicting with host libraries.

Port of utilities/fix-swrast-libGL-steam.sh. Intended only for systems with
conflicting system libraries (e.g. a ChromeOS chroot); see
https://wiki.archlinux.org/index.php/Steam/Troubleshooting. Must be re-run
after Steam updates, since Steam will likely re-bundle the conflicting libs.
"""

from __future__ import annotations

import logging
from pathlib import Path

logger = logging.getLogger("steamostools.steam_runtime")

DEFAULT_STEAM_ROOT = Path.home() / ".steam" / "root"
CONFLICTING_LIB_PATTERNS = ("libgcc_s.so*", "libstdc++.so*", "libxcb.so*", "libgpg-error.so*")


def find_conflicting_libs(steam_root: Path = DEFAULT_STEAM_ROOT) -> list[Path]:
    found = []
    for pattern in CONFLICTING_LIB_PATTERNS:
        found.extend(steam_root.rglob(pattern))
    return sorted(found)


def fix_swrast_libgl(steam_root: Path = DEFAULT_STEAM_ROOT) -> list[Path]:
    """Delete Steam-bundled libs known to conflict with host libGL/libstdc++
    on systems like a ChromeOS chroot. Returns the paths removed (may be
    empty -- that's a legitimate "nothing to fix" outcome, not an error)."""
    removed = []
    for lib in find_conflicting_libs(steam_root):
        lib.unlink()
        removed.append(lib)
        logger.info("Removed conflicting bundled lib: %s", lib)
    return removed


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("fix", help="misc compatibility fixes")
    sub = parser.add_subparsers(dest="fix_command", required=True)
    swrast = sub.add_parser(
        "swrast-libgl",
        help="remove Steam-bundled libs that conflict with host libGL (e.g. ChromeOS chroot)",
    )
    swrast.add_argument("--steam-root", type=Path, default=DEFAULT_STEAM_ROOT)
    swrast.set_defaults(func=_cmd_fix_swrast)


def _cmd_fix_swrast(args) -> int:
    removed = fix_swrast_libgl(args.steam_root)
    logger.info("Removed %d conflicting file(s)", len(removed))
    return 0
