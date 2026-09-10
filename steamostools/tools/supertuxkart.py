"""Backup SuperTuxKart config/data.

Port of utilities/games/backup-supertuxkart-data.sh. The original hardcoded
a "steam" system user and used sudo cp/chown -- that matched the legacy
SteamOS single-shared-account model. Modern Steam Deck / desktop Linux use
runs as whichever user is logged in, so this operates on the current user's
home directory (Path.home()) with no sudo, matching the rest of this
package's conventions (screenshots.py, proton_ge.py, etc).
"""

from __future__ import annotations

import logging
import shutil
from datetime import date
from pathlib import Path

logger = logging.getLogger("steamostools.supertuxkart")


def default_paths(user_home: Path | None = None) -> tuple[Path, Path]:
    user_home = user_home or Path.home()
    return user_home / ".config" / "supertuxkart", user_home / ".local" / "share" / "supertuxkart"


def backup_supertuxkart(*, config_dir: Path, data_dir: Path, backup_root: Path) -> Path:
    """Copy SuperTuxKart's config and data dirs into a dated backup
    directory under backup_root. A source dir that doesn't exist is
    skipped (logged, not an error -- a fresh install may not have data
    yet)."""
    today = date.today().isoformat()
    backup_dir = backup_root / f"{today}-backup"
    backup_dir.mkdir(parents=True, exist_ok=True)

    for source in (config_dir, data_dir):
        if not source.is_dir():
            logger.info("No directory found at %s, skipping", source)
            continue
        logger.info("Backing up %s -> %s", source, backup_dir)
        shutil.copytree(source, backup_dir / source.name, dirs_exist_ok=True)

    return backup_dir


def copy_backup_to(backup_dir: Path, alt_location: Path) -> Path:
    alt_location.mkdir(parents=True, exist_ok=True)
    dest = alt_location / backup_dir.name
    shutil.copytree(backup_dir, dest, dirs_exist_ok=True)
    return dest


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("supertuxkart", help="SuperTuxKart data tools")
    sub = parser.add_subparsers(dest="supertuxkart_command", required=True)

    backup = sub.add_parser("backup", help="backup config/data to a dated backup dir")
    backup.add_argument(
        "--backup-root", type=Path, default=Path.home() / "backups" / "supertuxkart"
    )
    backup.add_argument("--alt-location", type=Path, default=None, help="also copy the backup here")
    backup.set_defaults(func=_cmd_backup)


def _cmd_backup(args) -> int:
    config_dir, data_dir = default_paths()
    backup_dir = backup_supertuxkart(config_dir=config_dir, data_dir=data_dir, backup_root=args.backup_root)
    if args.alt_location:
        copy_backup_to(backup_dir, args.alt_location)
    logger.info("Backup complete: %s", backup_dir)
    return 0
