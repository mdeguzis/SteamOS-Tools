"""Copy ROMs/files from a local source path to a destination, with
permission cleanup for the classic 'steam'/'desktop' shared-account setup.

Port of utilities/local-roms-transfer.sh. The original was a fully
interactive prompt loop with a "remember last value between runs" trick
that only worked when the script was `source`d rather than executed --
replaced here with plain CLI flags, which are scriptable and testable.
"""

from __future__ import annotations

import logging
import shutil
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.local_roms_transfer")

LEGACY_OWNERS = {"desktop": "desktop:desktop", "steam": "steam:steam"}


def transfer(source: Path, dest: Path, *, owner: str | None = None) -> Path:
    """Copy `source` (file or directory) into `dest`. Raises
    FileNotFoundError if source doesn't exist. If `owner` is one of the
    legacy shared-account names ("steam"/"desktop"), chown+chmod the
    destination to match -- mirrors the original script's cleanup step for
    those setups; skipped for any other/no owner, since that assumption
    doesn't hold on a normal single-user Deck/desktop install."""
    if not source.exists():
        raise FileNotFoundError(f"Source not found: {source}")

    dest.mkdir(parents=True, exist_ok=True)
    target = dest / source.name
    if source.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)
    else:
        shutil.copy2(source, target)
    logger.info("Copied %s -> %s", source, dest)

    if owner in LEGACY_OWNERS:
        run(["sudo", "chown", "-R", LEGACY_OWNERS[owner], str(dest)])
        run(["sudo", "chmod", "-R", "755", str(dest)])
        logger.info("Applied legacy ownership (%s) to %s", owner, dest)

    return target


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "local-transfer", help="copy ROMs/files from a local source to a destination"
    )
    sub = parser.add_subparsers(dest="local_transfer_command", required=True)
    copy = sub.add_parser("copy", help="copy a file or directory")
    copy.add_argument("source", type=Path)
    copy.add_argument("destination", type=Path)
    copy.add_argument(
        "--legacy-owner",
        choices=sorted(LEGACY_OWNERS),
        default=None,
        help="chown/chmod the destination for a legacy shared 'steam'/'desktop' account setup",
    )
    copy.set_defaults(func=_cmd_copy)


def _cmd_copy(args) -> int:
    transfer(args.source, args.destination, owner=args.legacy_owner)
    return 0
