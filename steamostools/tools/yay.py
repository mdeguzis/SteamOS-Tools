"""Bootstrap the yay AUR helper.

Port of utilities/install-yay.sh.
"""

from __future__ import annotations

import logging
import shutil
import tempfile
from pathlib import Path

from steamostools.platform_detect import Platform, require_platform
from steamostools.process import run

logger = logging.getLogger("steamostools.yay")

BASE_PACKAGES = ["binutils", "make", "gcc", "fakeroot", "pkg-config"]
AUR_PACKAGES = ["auracle-git", "yay"]


class YayInstallError(RuntimeError):
    pass


def is_yay_installed() -> bool:
    return shutil.which("yay") is not None


def install_yay() -> None:
    """Install base-devel prerequisites and build yay (and auracle-git)
    from the AUR. Raises YayInstallError if yay is still missing
    afterwards -- matching the original script's failure behavior rather
    than silently reporting success."""
    require_platform(Platform.STEAMOS_ARCH)

    if is_yay_installed():
        logger.info("yay is already installed")
        return

    run(["sudo", "pacman", "-S", *BASE_PACKAGES, "--noconfirm", "--needed"])

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        for pkg in AUR_PACKAGES:
            logger.info("Building %s from AUR", pkg)
            run(["git", "clone", f"https://aur.archlinux.org/{pkg}.git"], cwd=str(tmp_path))
            run(
                ["makepkg", "--needed", "--noconfirm", "--skippgpcheck", "-sri"],
                cwd=str(tmp_path / pkg),
            )

    if not is_yay_installed():
        raise YayInstallError("yay was not successfully installed")
    logger.info("yay installed successfully")


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("yay", help="bootstrap the yay AUR helper")
    parser.set_defaults(func=_cmd_install)


def _cmd_install(args) -> int:
    install_yay()
    return 0
