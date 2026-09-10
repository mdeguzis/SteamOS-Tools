"""Wrap the Skyscraper ROM-scraper CLI.

Port of utilities/run-skyscraper.sh. Unlike the original, credentials are
read from environment variables by default rather than required as
positional CLI arguments -- passing a password as a plain argv entry makes
it visible to any other process on the system via `ps`/`/proc`.
"""

from __future__ import annotations

import logging
import os
import shutil
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.skyscraper")

DEFAULT_ROMS_ROOT = Path.home() / "Emulation" / "roms"


class SkyscraperNotAvailableError(RuntimeError):
    pass


class MissingCredentialsError(RuntimeError):
    pass


def build_command(
    system: str,
    user: str,
    password: str,
    *,
    roms_root: Path = DEFAULT_ROMS_ROOT,
    frontend: str = "emulationstation",
    scraper: str = "screenscraper",
) -> list[str]:
    system_dir = str(roms_root / system)
    return [
        "Skyscraper",
        "-f", frontend,
        "-s", scraper,
        "-u", f"{user}:{password}",
        "-i", system_dir,
        "-g", system_dir,
        "-o", system_dir,
        "-p", system,
    ]


def run_skyscraper(
    system: str,
    *,
    user: str | None = None,
    password: str | None = None,
    roms_root: Path = DEFAULT_ROMS_ROOT,
) -> None:
    if shutil.which("Skyscraper") is None:
        raise SkyscraperNotAvailableError("Skyscraper is not on PATH -- install it first")

    user = user or os.environ.get("SKYSCRAPER_USER")
    password = password or os.environ.get("SKYSCRAPER_PASSWORD")
    if not user or not password:
        raise MissingCredentialsError(
            "Scraper credentials required: pass --user/--password or set "
            "SKYSCRAPER_USER/SKYSCRAPER_PASSWORD (preferred -- avoids the "
            "password showing up in `ps`)"
        )

    run(build_command(system, user, password, roms_root=roms_root), capture=False)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("skyscraper", help="scrape ROM metadata/art via Skyscraper")
    sub = parser.add_subparsers(dest="skyscraper_command", required=True)

    scrape = sub.add_parser("scrape", help="run Skyscraper for one system")
    scrape.add_argument("system")
    scrape.add_argument("--user", default=None, help="prefer SKYSCRAPER_USER env var instead")
    scrape.add_argument("--password", default=None, help="prefer SKYSCRAPER_PASSWORD env var instead")
    scrape.add_argument("--roms-root", type=Path, default=DEFAULT_ROMS_ROOT)
    scrape.set_defaults(func=_cmd_scrape)


def _cmd_scrape(args) -> int:
    run_skyscraper(args.system, user=args.user, password=args.password, roms_root=args.roms_root)
    return 0
