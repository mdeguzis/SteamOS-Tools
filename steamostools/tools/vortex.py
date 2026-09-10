"""Install Vortex mod manager into a Proton/umu Wine prefix on SteamOS.

Port of ext-installers/install-vortex-steamos.sh. One of the most involved
scripts in the original repo (NSIS installer extraction, bundled .NET
runtime handling, Wine drive mapping) -- ported as a sequence of separately
testable steps rather than one large function. The actual 7z/umu-run/Proton
invocations remain subprocess calls: there's no Python-native way to drive
a Windows GUI installer's headless extraction or a Proton prefix, so this
wraps the same external tools the original script did.
"""

from __future__ import annotations

import logging
import shutil
from pathlib import Path

from steamostools.github_releases import GitHubReleaseClient
from steamostools.process import run

logger = logging.getLogger("steamostools.vortex")

GITHUB_REPO = "Nexus-Mods/Vortex"
DEFAULT_INSTALL_DIR = Path.home() / ".vortex-linux"
DEFAULT_DOWNLOAD_DIR = Path.home() / "Downloads"
DEFAULT_DESKTOP_FILE = Path.home() / ".local" / "share" / "applications" / "vortex.desktop"
DEFAULT_CLI_BIN = Path.home() / ".local" / "bin" / "vortex"
INTERNAL_STEAM_DIR = Path.home() / ".local" / "share" / "Steam"
SD_CARD_STEAM_LIBRARY = Path("/run/media/mmcblk0p1/steamapps/common")
DOTNET_URL = "https://aka.ms/dotnet/6.0/windowsdesktop-runtime-win-x64.zip"
DOTNET_ZIP_NAME = "windowsdesktop-runtime-6.0.36-win-x64.zip"
MIN_DOTNET_ZIP_BYTES = 100_000
GAMEID = "umu-vortex"
VORTEX_EXE_WINPATH = r"C:\Program Files\Black Tree Gaming Ltd\Vortex\Vortex.exe"


class VortexAlreadyInstalledError(RuntimeError):
    pass


class VortexExtractionError(RuntimeError):
    pass


class VortexDownloadError(RuntimeError):
    pass


def wineprefix_for(install_dir: Path) -> Path:
    return install_dir / "pfx"


def target_app_dir_for(install_dir: Path) -> Path:
    return wineprefix_for(install_dir) / "drive_c" / "Program Files" / "Black Tree Gaming Ltd" / "Vortex"


def check_reinstall_guard(install_dir: Path, *, reinstall: bool) -> None:
    """Raises VortexAlreadyInstalledError if a prefix already exists and
    reinstall wasn't requested -- guards against silently wiping an
    existing install's settings/mods."""
    wineprefix = wineprefix_for(install_dir)
    if wineprefix.exists() and not reinstall:
        raise VortexAlreadyInstalledError(
            f"Vortex Proton prefix already exists at {wineprefix}. "
            "Pass reinstall=True to force a clean reinstall."
        )


def fetch_release(*, client: GitHubReleaseClient, include_prerelease: bool = True) -> dict:
    if include_prerelease:
        releases = client.list_releases(GITHUB_REPO)
        if not releases:
            raise VortexDownloadError(f"No releases found for {GITHUB_REPO}")
        return releases[0]
    return client.latest_release(GITHUB_REPO)


def find_exe_asset(release: dict) -> dict:
    for asset in release.get("assets", []):
        if asset["name"].endswith(".exe"):
            return asset
    raise VortexDownloadError("Could not resolve the .exe download URL from the release assets")


def download_installer(
    release: dict, *, client: GitHubReleaseClient, download_dir: Path = DEFAULT_DOWNLOAD_DIR
) -> Path:
    asset = find_exe_asset(release)
    dest = download_dir / asset["name"]
    if not dest.exists():
        client.download(asset["browser_download_url"], dest)
    else:
        logger.info("%s already downloaded, reusing", dest)
    return dest


def init_proton_prefix(install_dir: Path) -> None:
    """Run a harmless headless Windows command through umu-run to force
    the Proton/umu prefix's drive_c layout to materialize."""
    run(
        ["umu-run", "c:\\windows\\system32\\cmd.exe", "/c", "echo Prefix Init"],
        env={"WINEPREFIX": str(wineprefix_for(install_dir)), "GAMEID": GAMEID},
        check=False,
    )


def extract_installer_payload(installer_path: Path, install_dir: Path) -> Path:
    """Unpack the NSIS installer via 7z, handling both the newer nested
    app-64.7z layout and the older flat layout. Returns the path to
    Vortex.exe. Raises VortexExtractionError if neither layout is found."""
    tmp_dir = install_dir / "tmp"
    target_app_dir = target_app_dir_for(install_dir)
    target_app_dir.mkdir(parents=True, exist_ok=True)

    run(["7z", "x", "-y", f"-o{tmp_dir}", str(installer_path)], capture=False)

    nested_archive = tmp_dir / "$PLUGINSDIR" / "app-64.7z"
    if nested_archive.exists():
        logger.info("Found nested app payload, unpacking core application files")
        run(["7z", "x", "-y", f"-o{target_app_dir}", str(nested_archive)], capture=False)
    else:
        matches = list(tmp_dir.rglob("Vortex.exe"))
        if not matches:
            raise VortexExtractionError("Could not find Vortex application payload or app-64.7z")
        found_app_dir = matches[0].parent
        for item in found_app_dir.iterdir():
            item.rename(target_app_dir / item.name)

    vortex_exe = target_app_dir / "Vortex.exe"
    if not vortex_exe.exists():
        raise VortexExtractionError("Vortex.exe missing after extraction")

    shutil.rmtree(tmp_dir, ignore_errors=True)
    return vortex_exe


def extract_bundled_dotnet(install_dir: Path) -> bool:
    """If the installer bundled its own .NET desktop runtime installer,
    extract it directly instead of downloading a separate copy. Returns
    True if a bundled copy was found and extracted."""
    bundled = install_dir / "tmp" / "$TEMP" / "windowsdesktop-runtime-win-x64.exe"
    if not bundled.exists():
        return False
    dotnet_dir = wineprefix_for(install_dir) / "drive_c" / "Program Files" / "dotnet"
    dotnet_dir.mkdir(parents=True, exist_ok=True)
    run(["7z", "x", "-y", f"-o{dotnet_dir}", str(bundled)], capture=False)
    return True


def download_and_extract_dotnet(
    install_dir: Path,
    *,
    client: GitHubReleaseClient,
    download_dir: Path = DEFAULT_DOWNLOAD_DIR,
) -> None:
    """Download and extract the .NET Desktop Runtime, used when the
    installer didn't bundle its own copy. Raises VortexDownloadError if
    the downloaded file is implausibly small (a common failure mode for
    aka.ms redirect links that didn't resolve to the real CDN)."""
    zip_path = download_dir / DOTNET_ZIP_NAME

    if zip_path.exists() and zip_path.stat().st_size < 10_000:
        zip_path.unlink()

    if not zip_path.exists():
        client.download(DOTNET_URL, zip_path)

    if zip_path.stat().st_size < MIN_DOTNET_ZIP_BYTES:
        zip_path.unlink(missing_ok=True)
        raise VortexDownloadError(".NET runtime download failed -- payload was implausibly small")

    dotnet_dir = wineprefix_for(install_dir) / "drive_c" / "Program Files" / "dotnet"
    dotnet_dir.mkdir(parents=True, exist_ok=True)
    run(["7z", "x", "-y", f"-o{dotnet_dir}", str(zip_path)], capture=False)


def map_steam_library_drives(
    install_dir: Path,
    *,
    sd_card_library: Path = SD_CARD_STEAM_LIBRARY,
    internal_steam_dir: Path = INTERNAL_STEAM_DIR,
) -> dict[str, Path]:
    """Symlink Wine drive letters to Steam library folders (SD card gets
    M:; internal storage is handled natively by Proton via X:). Returns
    the drives actually mapped -- an empty dict when no SD card is
    present is a legitimate outcome, not an error."""
    dosdevices = wineprefix_for(install_dir) / "dosdevices"
    dosdevices.mkdir(parents=True, exist_ok=True)

    mapped: dict[str, Path] = {}
    if sd_card_library.is_dir():
        for name in ("m", "m:"):
            (dosdevices / name).unlink(missing_ok=True)
        (dosdevices / "m:").symlink_to(sd_card_library)
        run(
            [
                "umu-run", "reg", "add", r"HKCU\Software\Wine\Drives",
                "/v", "m", "/t", "REG_SZ", "/d", "hd", "/f",
            ],
            env={"WINEPREFIX": str(wineprefix_for(install_dir)), "GAMEID": GAMEID},
            check=False,
        )
        mapped["m:"] = sd_card_library
        logger.info("Mapped M: -> SD card Steam library at %s", sd_card_library)
    else:
        logger.info("No SD card detected at %s, skipping M: mapping", sd_card_library)

    if internal_steam_dir.is_dir():
        steam_home_link = Path.home() / "Steam"
        steam_home_link.unlink(missing_ok=True)
        steam_home_link.symlink_to(internal_steam_dir)

    return mapped


CLI_WRAPPER_TEMPLATE = """#!/usr/bin/env bash
export WINEPREFIX="{wineprefix}"
export GAMEID="{gameid}"
export DISPLAY="${{DISPLAY:-:0}}"
export XAUTHORITY="${{XAUTHORITY:-${{HOME}}/.Xauthority}}"

# Strip out Proton's global node environment hooks to prevent the Electron security panic
unset NODE_OPTIONS

umu-run reg add "HKCU\\\\Software\\\\Wine\\\\Explorer" /v "Desktop" /t REG_SZ /d "Default" /f > /dev/null 2>&1
umu-run reg add "HKCU\\\\Software\\\\Wine\\\\Explorer\\\\Desktops" /v "Default" /t REG_SZ /d "1920x1080" /f > /dev/null 2>&1

exec umu-run "{vortex_exe_winpath}" "$@" --no-sandbox --disable-gpu 2>&1 | tee /tmp/vortex-log.txt
"""

DESKTOP_FILE_TEMPLATE = """[Desktop Entry]
Name=Vortex Mod Manager
Comment=Manage mods for games via Proton
Exec="{cli_bin}" %u
Icon=vortex
Terminal=false
Type=Application
Categories=Game;Utility;
MimeType=x-scheme-handler/nxm;x-scheme-handler/nxm-protocol;
StartupNotify=true
"""


def write_cli_wrapper(install_dir: Path, *, cli_bin: Path = DEFAULT_CLI_BIN) -> Path:
    content = CLI_WRAPPER_TEMPLATE.format(
        wineprefix=wineprefix_for(install_dir), gameid=GAMEID, vortex_exe_winpath=VORTEX_EXE_WINPATH
    )
    cli_bin.parent.mkdir(parents=True, exist_ok=True)
    cli_bin.write_text(content)
    cli_bin.chmod(cli_bin.stat().st_mode | 0o111)
    return cli_bin


def write_desktop_file(*, cli_bin: Path = DEFAULT_CLI_BIN, desktop_file: Path = DEFAULT_DESKTOP_FILE) -> Path:
    content = DESKTOP_FILE_TEMPLATE.format(cli_bin=cli_bin)
    desktop_file.parent.mkdir(parents=True, exist_ok=True)
    desktop_file.write_text(content)
    desktop_file.chmod(desktop_file.stat().st_mode | 0o111)
    return desktop_file


def register_mime_handlers(desktop_file_name: str = "vortex.desktop") -> None:
    if shutil.which("xdg-mime"):
        run(["xdg-mime", "default", desktop_file_name, "x-scheme-handler/nxm"], check=False)
        run(["xdg-mime", "default", desktop_file_name, "x-scheme-handler/nxm-protocol"], check=False)
    if shutil.which("update-mime-database"):
        run(["update-mime-database", str(Path.home() / ".local" / "share" / "mime")], check=False)


def install_vortex(
    *,
    reinstall: bool = False,
    install_dir: Path = DEFAULT_INSTALL_DIR,
    download_dir: Path = DEFAULT_DOWNLOAD_DIR,
    cli_bin: Path = DEFAULT_CLI_BIN,
    desktop_file: Path = DEFAULT_DESKTOP_FILE,
    client: GitHubReleaseClient | None = None,
) -> Path:
    """Full install orchestration. Returns the path to the generated CLI
    wrapper."""
    check_reinstall_guard(install_dir, reinstall=reinstall)
    if reinstall and wineprefix_for(install_dir).exists():
        shutil.rmtree(wineprefix_for(install_dir))
        shutil.rmtree(install_dir / "tmp", ignore_errors=True)

    client = client or GitHubReleaseClient()
    release = fetch_release(client=client)
    installer_path = download_installer(release, client=client, download_dir=download_dir)

    init_proton_prefix(install_dir)
    extract_installer_payload(installer_path, install_dir)

    if not extract_bundled_dotnet(install_dir):
        download_and_extract_dotnet(install_dir, client=client, download_dir=download_dir)

    map_steam_library_drives(install_dir)
    write_cli_wrapper(install_dir, cli_bin=cli_bin)
    write_desktop_file(cli_bin=cli_bin, desktop_file=desktop_file)
    register_mime_handlers(desktop_file.name)

    logger.info("Vortex installed. CLI: %s, Desktop: %s", cli_bin, desktop_file)
    return cli_bin


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("vortex", help="install Vortex mod manager via Proton/umu")
    sub = parser.add_subparsers(dest="vortex_command", required=True)
    install = sub.add_parser("install", help="download and install the latest Vortex release")
    install.add_argument("--reinstall", action="store_true", help="wipe and recreate an existing prefix")
    install.set_defaults(func=_cmd_install)


def _cmd_install(args) -> int:
    try:
        install_vortex(reinstall=args.reinstall)
    except VortexAlreadyInstalledError as exc:
        # Matches the original script: an existing prefix without --reinstall
        # is informational, not a failure -- it exits 0.
        logger.warning(str(exc))
    return 0
