"""Install/run the SteamGridDB `steamgrid` CLI artwork updater.

Port of utilities/steam-deck/update-steamgrid-artwork -- found during a
full-repo audit for the conversion effort (it had no .sh extension, so it
was missed by earlier extension-based script surveys). See
https://www.reddit.com/r/steamgrid/comments/ym0ade/ for the underlying
tool; it needs a SteamGridDB API key configured in the tool itself,
unrelated to this wrapper.
"""

from __future__ import annotations

import logging
import shutil
import tempfile
import zipfile
from pathlib import Path

from steamostools.github_releases import GitHubReleaseClient
from steamostools.process import run

logger = logging.getLogger("steamostools.steamgrid")

GITHUB_REPO = "dozeworthy/steamgrid"
DEFAULT_SOFTWARE_ROOT = Path.home() / "software" / "steamgrid"
DEFAULT_BIN_LINK = Path.home() / ".local" / "bin" / "steamgrid"
RELEASE_ASSET_PATTERN = r"steamgrid_linux\.zip$"


def install_steamgrid(
    *,
    client: GitHubReleaseClient | None = None,
    software_root: Path = DEFAULT_SOFTWARE_ROOT,
    bin_link: Path = DEFAULT_BIN_LINK,
    download_dir: Path | None = None,
) -> Path:
    """Download and install the latest steamgrid release, symlinked into
    bin_link. Raises if no matching release asset is found (via
    GitHubReleaseClient.pick_asset) rather than silently no-op'ing."""
    client = client or GitHubReleaseClient()
    download_dir = download_dir or Path(tempfile.mkdtemp())

    if software_root.exists():
        shutil.rmtree(software_root)
    software_root.mkdir(parents=True)

    release = client.latest_release(GITHUB_REPO)
    asset = client.pick_asset(release["assets"], [RELEASE_ASSET_PATTERN])
    archive_path = download_dir / "steamgrid_linux.zip"
    client.download(asset["browser_download_url"], archive_path)

    with zipfile.ZipFile(archive_path) as zf:
        zf.extractall(software_root)

    binary = software_root / "steamgrid"
    binary.chmod(binary.stat().st_mode | 0o111)

    bin_link.parent.mkdir(parents=True, exist_ok=True)
    if bin_link.exists() or bin_link.is_symlink():
        bin_link.unlink()
    bin_link.symlink_to(binary)

    logger.info("Installed steamgrid to %s (linked from %s)", binary, bin_link)
    return binary


def run_steamgrid(software_root: Path = DEFAULT_SOFTWARE_ROOT) -> None:
    binary = software_root / "steamgrid"
    if not binary.exists():
        raise FileNotFoundError(f"{binary} not found -- run `install` first")
    run([str(binary)], capture=False)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "steamgrid", help="update Steam artwork via SteamGridDB's steamgrid CLI"
    )
    sub = parser.add_subparsers(dest="steamgrid_command", required=True)

    install = sub.add_parser("install", help="download and install the latest steamgrid release")
    install.set_defaults(func=_cmd_install)

    run_cmd = sub.add_parser("run", help="run steamgrid to update artwork")
    run_cmd.set_defaults(func=_cmd_run)


def _cmd_install(args) -> int:
    install_steamgrid()
    return 0


def _cmd_run(args) -> int:
    run_steamgrid()
    return 0
