"""Install Plex Media Server as a rootless Podman Quadlet user service.

Port of utilities/install-plex.sh. Bazzite/Fedora (Podman Quadlet) specific.
"""

from __future__ import annotations

import logging
import os
import time
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.plex")

PLEX_CONFIG_DIR = Path.home() / ".config" / "plex"
PLEX_MEDIA_DIR = Path.home() / "plex" / "plexmedia"
QUADLET_DIR = Path.home() / ".config" / "containers" / "systemd"
QUADLET_FILE_NAME = "plex.container"

QUADLET_TEMPLATE = """[Unit]
Description=Plex Media Server (User Container)
After=network-online.target

[Container]
Image=lscr.io/linuxserver/plex:latest
ContainerName=plex
Environment=PUID={uid} PGID={gid} TZ=Etc/UTC VERSION=docker
Volume=%h/.config/plex:/config:Z
Volume=%h/plex/plexmedia:/data/media:Z
Network=host

[Service]
Restart=always

[Install]
WantedBy=default.target
"""


class PlexStartError(RuntimeError):
    pass


def render_quadlet(uid: int | None = None, gid: int | None = None) -> str:
    return QUADLET_TEMPLATE.format(
        uid=uid if uid is not None else os.getuid(),
        gid=gid if gid is not None else os.getgid(),
    )


def install_plex(
    *,
    config_dir: Path = PLEX_CONFIG_DIR,
    media_dir: Path = PLEX_MEDIA_DIR,
    quadlet_dir: Path = QUADLET_DIR,
) -> None:
    """Write the Quadlet unit and start Plex. Raises PlexStartError if the
    service doesn't come up active."""
    config_dir.mkdir(parents=True, exist_ok=True)
    media_dir.mkdir(parents=True, exist_ok=True)
    quadlet_dir.mkdir(parents=True, exist_ok=True)

    quadlet_file = quadlet_dir / QUADLET_FILE_NAME
    quadlet_file.write_text(render_quadlet())
    logger.info("Wrote Quadlet unit: %s", quadlet_file)

    run(["systemctl", "--user", "daemon-reload"])
    run(["systemctl", "--user", "start", "plex"])

    time.sleep(2)
    result = run(["systemctl", "--user", "is-active", "--quiet", "plex"], check=False)
    if result.returncode != 0:
        raise PlexStartError("Plex failed to start -- check `journalctl --user -u plex`")
    logger.info("Plex is running: http://localhost:32400/web")


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("plex", help="install Plex as a rootless Podman Quadlet service")
    sub = parser.add_subparsers(dest="plex_command", required=True)
    sub.add_parser("install", help="write the Quadlet unit and start Plex").set_defaults(func=_cmd_install)


def _cmd_install(args) -> int:
    install_plex()
    return 0
