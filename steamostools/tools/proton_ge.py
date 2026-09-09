"""Install the latest GE-Proton (GloriousEggroll's Proton fork) release.

Port of utilities/get-proton-ge.sh.
"""

from __future__ import annotations

import logging
import tarfile
from pathlib import Path

from steamostools.github_releases import GitHubReleaseClient

logger = logging.getLogger("steamostools.proton_ge")

GITHUB_REPO = "GloriousEggroll/proton-ge-custom"

NATIVE_COMPAT_DIR = Path.home() / ".steam" / "root" / "compatibilitytools.d"
FLATPAK_COMPAT_DIR = (
    Path.home() / ".var" / "app" / "com.valvesoftware.Steam" / "data" / "Steam" / "compatibilitytools.d"
)

VALID_STEAM_TYPES = ("native", "flatpak", "steamos")


class AlreadyInstalledError(RuntimeError):
    pass


def compat_tools_dir(steam_type: str) -> Path:
    if steam_type not in VALID_STEAM_TYPES:
        raise ValueError(f"steam_type must be one of {VALID_STEAM_TYPES}, got {steam_type!r}")
    if steam_type == "flatpak":
        return FLATPAK_COMPAT_DIR
    return NATIVE_COMPAT_DIR


def install_latest(
    steam_type: str,
    *,
    client: GitHubReleaseClient | None = None,
    download_dir: Path = Path.cwd(),
) -> Path:
    """Download and extract the latest GE-Proton release. Returns the
    extracted install path. Raises AlreadyInstalledError if that version
    is already present -- matching the original script's behavior of
    treating a re-run of an already-installed version as an error rather
    than silently doing nothing."""
    client = client or GitHubReleaseClient()
    target_dir = compat_tools_dir(steam_type)

    release = client.latest_release(GITHUB_REPO)
    version = release["tag_name"]
    asset_name = f"{version}.tar.gz"
    folder_name = f"Proton-{version}"

    install_path = target_dir / folder_name
    if install_path.exists():
        raise AlreadyInstalledError(f"{folder_name} already exists in {target_dir}")

    asset = client.pick_asset(release["assets"], [rf"^{version}\.tar\.gz$"])
    archive_path = download_dir / asset_name
    if not archive_path.exists():
        client.download(asset["browser_download_url"], archive_path)
    else:
        logger.info("%s already downloaded, reusing", archive_path)

    target_dir.mkdir(parents=True, exist_ok=True)
    logger.info("Extracting %s -> %s", archive_path, target_dir)
    with tarfile.open(archive_path) as tar:
        tar.extractall(target_dir, filter="data")

    logger.info("%s installed to %s", folder_name, target_dir)
    return install_path


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("proton", help="GE-Proton install/update tools")
    proton_sub = parser.add_subparsers(dest="proton_command", required=True)

    get_ge = proton_sub.add_parser("get-ge", help="install the latest GE-Proton release")
    get_ge.add_argument("steam_type", choices=VALID_STEAM_TYPES)
    get_ge.set_defaults(func=_cmd_get_ge)


def _cmd_get_ge(args) -> int:
    try:
        install_latest(args.steam_type)
    except AlreadyInstalledError as exc:
        logger.error(str(exc))
        return 1
    return 0
