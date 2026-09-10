"""Install, configure, and manage the Supermodel (Sega Model 3) emulator.

Port of ext-installers/supermodel-manager.sh. The Debian branch of the
original's OS detection was dropped -- this repo only targets Arch-based
SteamOS/ChimeraOS/Bazzite now (see the repo's own README on the
Brewmaster/Alchemist-era retirement).
"""

from __future__ import annotations

import importlib.resources
import logging
import shutil
from pathlib import Path

from steamostools.platform_detect import Platform, detect_platform
from steamostools.process import run

logger = logging.getLogger("steamostools.supermodel")

SUPERMODEL_SRC_DIR = Path.home() / "src" / "supermodel"
DATA_ROOT = importlib.resources.files("steamostools") / "data" / "supermodel3"
DEFAULT_APPLICATIONS_DIR = Path.home() / ".local" / "share" / "applications"

INPUT_PROFILES = ("xinput", "dinput", "sdl")


class SupermodelInstallError(RuntimeError):
    pass


def install_supermodel(platform: Platform | None = None) -> None:
    """Install Supermodel: built from source on ChimeraOS (the Flathub
    build fails there with "OpenGL initialization failed"), or the
    Flatpak everywhere else."""
    platform = platform or detect_platform()

    if platform == Platform.CHIMERAOS:
        run(["sudo", "frzr-unlock"])
        run(["sudo", "pacman", "-Syy"])
        run(["sudo", "pacman", "-S", "archlinux-keyring", "--noconfirm"])
        run(["sudo", "pacman-key", "--init"])
        run(["sudo", "pacman-key", "--populate", "archlinux"])
        run(["sudo", "pacman", "-Sy", "sdl2", "sdl2_net", "devtools", "base-devel", "--noconfirm"])

        SUPERMODEL_SRC_DIR.parent.mkdir(parents=True, exist_ok=True)
        if not SUPERMODEL_SRC_DIR.is_dir():
            run(["git", "clone", "https://github.com/trzy/Supermodel", str(SUPERMODEL_SRC_DIR)])
        else:
            run(["git", "-C", str(SUPERMODEL_SRC_DIR), "pull"])

        run(["make", "-f", "Makefiles/Makefile.UNIX", "NET_BOARD=1"], cwd=str(SUPERMODEL_SRC_DIR))

        built_binary = SUPERMODEL_SRC_DIR / "bin" / "supermodel"
        if not built_binary.exists():
            raise SupermodelInstallError(f"Build did not produce {built_binary}")
        run(["sudo", "ln", "-sfv", str(built_binary.resolve()), "/usr/bin/supermodel"])
    else:
        run(["flatpak", "install", "--user", "com.supermodel3.Supermodel", "-y"])

    logger.info("Supermodel installed. Basic usage: https://www.supermodel3.com/Usage.html")


def supermodel_binary_for(platform: Platform) -> str:
    if platform == Platform.CHIMERAOS:
        return "/usr/bin/supermodel"
    return "/usr/bin/flatpak run com.supermodel3.Supermodel"


DEFAULT_DRM_ROOT = Path("/sys/class/drm")


def get_device_resolution(drm_root: Path = DEFAULT_DRM_ROOT) -> str:
    """Read the first available display mode from drm_root, matching the
    original script's approach. Raises RuntimeError if no modes file is
    readable (e.g. headless)."""
    for modes_file in sorted(drm_root.glob("*/modes")):
        text = modes_file.read_text().strip()
        if text:
            width, _, height = text.splitlines()[0].partition("x")
            return f"{width},{height}"
    raise RuntimeError(f"Could not determine device resolution from {drm_root}/*/modes")


def add_game_shortcut(
    game_name: str,
    game_zip: Path,
    *,
    platform: Platform | None = None,
    device_res: str | None = None,
    applications_dir: Path = DEFAULT_APPLICATIONS_DIR,
    start_path: Path = SUPERMODEL_SRC_DIR,
) -> Path:
    """Create a Steam-visible .desktop launcher for one Supermodel game.
    Raises FileNotFoundError if game_zip doesn't exist."""
    if not game_zip.is_file():
        raise FileNotFoundError(f"Could not locate game zip at path: {game_zip}")

    platform = platform or detect_platform()
    device_res = device_res or get_device_resolution()
    game_basename = game_zip.stem

    template = (DATA_ROOT / "supermodel-template.desktop").read_text()
    content = (
        template.replace("GAME_NAME", game_name)
        .replace("GAME_ZIP", str(game_zip))
        .replace("DEVICE_RES", device_res)
        .replace("START_PATH", str(start_path))
        .replace("SUPERMODEL_BIN", supermodel_binary_for(platform))
    )

    applications_dir.mkdir(parents=True, exist_ok=True)
    dest = applications_dir / f"supermodel-{game_basename}.desktop"
    dest.write_text(content)
    logger.info("Wrote Supermodel launcher: %s", dest)
    return dest


def remove_game_shortcut(game_zip: Path, *, applications_dir: Path = DEFAULT_APPLICATIONS_DIR) -> None:
    dest = applications_dir / f"supermodel-{game_zip.stem}.desktop"
    dest.unlink(missing_ok=True)
    logger.info("Removed Supermodel launcher: %s", dest)


def configure_input(
    profile: str,
    *,
    target_dir: Path = SUPERMODEL_SRC_DIR / "Config",
    nvram_source: Path | None = None,
) -> None:
    """Copy a bundled input profile (xinput/dinput/sdl) into Supermodel's
    Config dir. If `nvram_source` is given (e.g. a repo checkout's
    cfgs/supermodel3/nvram), also seed pre-configured NVRAM saves -- that
    ~1.4MB of per-game battery-backup data isn't bundled in the installed
    package, since it's a bonus convenience, not required for the tool to
    function."""
    if profile not in INPUT_PROFILES:
        raise ValueError(f"profile must be one of {INPUT_PROFILES}, got {profile!r}")

    target_dir.mkdir(parents=True, exist_ok=True)
    source_ini = DATA_ROOT / profile / "Supermodel.ini"
    (target_dir / "Supermodel.ini").write_text(source_ini.read_text())
    logger.info("Configured %s input profile in %s", profile, target_dir)

    if nvram_source is not None and nvram_source.is_dir():
        nvram_dest = target_dir.parent / "NVRAM"
        shutil.copytree(nvram_source, nvram_dest, dirs_exist_ok=True)
        logger.info("Seeded NVRAM saves from %s -> %s", nvram_source, nvram_dest)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "supermodel", help="install/configure the Supermodel (Sega Model 3) emulator"
    )
    sub = parser.add_subparsers(dest="supermodel_command", required=True)

    sub.add_parser(
        "install", help="install Supermodel (from source on ChimeraOS, Flatpak elsewhere)"
    ).set_defaults(func=_cmd_install)

    add_game = sub.add_parser("add-game", help="add a Steam-visible launcher for a game")
    add_game.add_argument("--name", required=True)
    add_game.add_argument("--zip", dest="game_zip", type=Path, required=True)
    add_game.set_defaults(func=_cmd_add_game)

    remove_game = sub.add_parser("remove-game", help="remove a game's launcher")
    remove_game.add_argument("--zip", dest="game_zip", type=Path, required=True)
    remove_game.set_defaults(func=_cmd_remove_game)

    configure = sub.add_parser("configure-input", help="install an input profile (xinput/dinput/sdl)")
    configure.add_argument("profile", choices=INPUT_PROFILES)
    configure.add_argument(
        "--nvram-source",
        type=Path,
        default=None,
        help="optional repo-checkout cfgs/supermodel3/nvram to seed pre-configured saves from",
    )
    configure.set_defaults(func=_cmd_configure_input)


def _cmd_install(args) -> int:
    install_supermodel()
    return 0


def _cmd_add_game(args) -> int:
    add_game_shortcut(args.name, args.game_zip)
    return 0


def _cmd_remove_game(args) -> int:
    remove_game_shortcut(args.game_zip)
    return 0


def _cmd_configure_input(args) -> int:
    configure_input(args.profile, nvram_source=args.nvram_source)
    return 0
