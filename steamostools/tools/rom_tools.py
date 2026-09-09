"""ROM organization helpers.

Ports utilities/rom-migrator.sh (archive/unarchive ROMs against a match
list) and utilities/remove-leading-numbers-roms.sh (strip numeric prefixes
scrapers sometimes add to ROM filenames).
"""

from __future__ import annotations

import logging
import re
import shutil
from dataclasses import dataclass, field
from pathlib import Path

logger = logging.getLogger("steamostools.rom_tools")

DEFAULT_ARCHIVE_ROOT = Path.home() / "Emulation" / "roms" / "archive"
VALID_OPERATIONS = ("archive", "unarchive")

_LEADING_NUMBER_DISCOVERY_RE = re.compile(r"^\d{3} ")
_LEADING_NUMBER_STRIP_RE = re.compile(r"^\d{1,3} ")


# ---------------------------------------------------------------------------
# ROM migrator (archive / unarchive against a match list)
# ---------------------------------------------------------------------------


@dataclass
class RomMoveResult:
    moved: list[str] = field(default_factory=list)
    skipped: list[str] = field(default_factory=list)


def resolve_src_dest(operation: str, working_dir: Path, archive_dir: Path) -> tuple[Path, Path]:
    if operation == "unarchive":
        return archive_dir, working_dir
    if operation == "archive":
        return working_dir, archive_dir
    raise ValueError(f"operation must be one of {VALID_OPERATIONS}, got {operation!r}")


def load_rom_list(romlist_path: Path) -> list[str]:
    return [line.strip() for line in romlist_path.read_text().splitlines() if line.strip()]


def migrate_roms(system: str, roms: list[str], src: Path, dest: Path) -> RomMoveResult:
    """Move each named ROM (and, for MAME, its matching CHD folder) from
    `src` to `dest`. ROMs not found under `src` are logged and skipped --
    that is an expected, non-fatal outcome the caller can inspect via
    `RomMoveResult.skipped`, not a raised error."""
    result = RomMoveResult()
    dest.mkdir(parents=True, exist_ok=True)

    for rom in roms:
        matches = sorted(src.rglob(rom))
        if not matches:
            logger.warning("Could not find ROM %s under %s, skipping", rom, src)
            result.skipped.append(rom)
            continue

        rom_file = matches[0]
        logger.info("Moving ROM %s -> %s", rom, dest)
        shutil.move(str(rom_file), str(dest))
        result.moved.append(rom)

        if system == "mame":
            rom_stem = rom_file.stem  # strip .zip
            for chd_dir in sorted(p for p in src.rglob(rom_stem) if p.is_dir()):
                logger.info("Moving MAME CHD folder %s -> %s", chd_dir, dest)
                shutil.move(str(chd_dir), str(dest / chd_dir.name))

    return result


# ---------------------------------------------------------------------------
# Leading-number filename cleanup
# ---------------------------------------------------------------------------


def find_prefixed_files(target_dir: Path) -> list[Path]:
    return sorted(
        p for p in target_dir.rglob("*") if p.is_file() and _LEADING_NUMBER_DISCOVERY_RE.match(p.name)
    )


def strip_leading_numbers(target_dir: Path, *, dry_run: bool = False) -> list[tuple[Path, Path]]:
    """Rename every file under `target_dir` whose name starts with a
    3-digit scraper prefix (e.g. "042 Some Game.zip"). Returns the list of
    (old_path, new_path) pairs actually renamed (or that would be, if
    dry_run)."""
    renamed = []
    for path in find_prefixed_files(target_dir):
        new_name = _LEADING_NUMBER_STRIP_RE.sub("", path.name, count=1)
        new_path = path.with_name(new_name)
        logger.info("Renaming %s -> %s", path.name, new_name)
        if not dry_run:
            path.rename(new_path)
        renamed.append((path, new_path))
    return renamed


# ---------------------------------------------------------------------------
# CLI wiring
# ---------------------------------------------------------------------------


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("rom", help="ROM organization tools")
    rom_sub = parser.add_subparsers(dest="rom_command", required=True)

    migrate = rom_sub.add_parser("migrate", help="archive/unarchive ROMs against a match list")
    migrate.add_argument("operation", choices=VALID_OPERATIONS)
    migrate.add_argument("system", help="e.g. 'mame', 'psp'")
    migrate.add_argument("romlist", type=Path, help="text file with one ROM filename per line")
    migrate.add_argument("--archive-root", type=Path, default=DEFAULT_ARCHIVE_ROOT)
    migrate.add_argument("--yes", "-y", action="store_true", help="skip the confirmation prompt")
    migrate.set_defaults(func=_cmd_migrate)

    strip = rom_sub.add_parser(
        "strip-numbers", help="strip leading numeric scraper prefixes from ROM filenames"
    )
    strip.add_argument("target_dir", type=Path)
    strip.add_argument("--dry-run", action="store_true")
    strip.set_defaults(func=_cmd_strip_numbers)


def _cmd_migrate(args) -> int:
    archive_dir = args.archive_root / args.system
    if not archive_dir.is_dir():
        logger.error("Archive dir %s does not exist", archive_dir)
        return 1

    src, dest = resolve_src_dest(args.operation, Path.cwd(), archive_dir)
    roms = load_rom_list(args.romlist)

    logger.info("This operation will move %d ROM(s) from %s to %s", len(roms), src, dest)
    if not args.yes:
        response = input("Proceed? (y/N): ").strip().lower()
        if response != "y":
            logger.info("Aborting...")
            return 0

    result = migrate_roms(args.system, roms, src, dest)
    logger.info("Moved %d ROM(s), skipped %d", len(result.moved), len(result.skipped))
    return 0


def _cmd_strip_numbers(args) -> int:
    renamed = strip_leading_numbers(args.target_dir, dry_run=args.dry_run)
    logger.info("%s %d file(s)", "Would rename" if args.dry_run else "Renamed", len(renamed))
    return 0
