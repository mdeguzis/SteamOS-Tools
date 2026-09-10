"""Create a custom .desktop launcher shortcut.

Port of utilities/create-app-launcher.sh. The template is embedded here
rather than read from cfgs/desktop-files/template.desktop, so this works
correctly for a pip-installed steamos-tools (cfgs/ lives only in the git
checkout, not the published package). The original's interactive
read-prompt UX is replaced with explicit flags -- a real CLI tool should
be scriptable and testable, not require a TTY.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

logger = logging.getLogger("steamostools.app_launcher")

APPLICATIONS_DIR = Path("/usr/share/applications")

DESKTOP_TEMPLATE = """[Desktop Entry]
Version=1.0
Name={name}
GenericName={generic_name}
Type=Application
Exec={exec_path}
Icon={icon}
Categories=application;
"""


def slugify(name: str) -> str:
    return re.sub(r"\s+", "-", name.strip())


def render_desktop_file(name: str, generic_name: str, icon: str, exec_path: str) -> str:
    return DESKTOP_TEMPLATE.format(name=name, generic_name=generic_name, icon=icon, exec_path=exec_path)


def install_launcher(
    name: str,
    generic_name: str,
    icon: str,
    exec_path: str,
    *,
    applications_dir: Path = APPLICATIONS_DIR,
) -> Path:
    """Write a .desktop launcher file. Raises OSError if applications_dir
    isn't writable (e.g. no root) -- run with sudo, or pass a
    user-writable applications_dir such as ~/.local/share/applications."""
    content = render_desktop_file(name, generic_name, icon, exec_path)
    applications_dir.mkdir(parents=True, exist_ok=True)
    dest = applications_dir / f"{slugify(name)}.desktop"
    dest.write_text(content)
    logger.info("Wrote launcher: %s", dest)
    return dest


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("app-launcher", help="create a custom .desktop shortcut")
    sub = parser.add_subparsers(dest="app_launcher_command", required=True)
    create = sub.add_parser("create", help="create a new .desktop launcher")
    create.add_argument("--name", required=True, help="shortcut name")
    create.add_argument("--generic-name", required=True, help="generic name/comment")
    create.add_argument("--icon", required=True, help="icon path")
    create.add_argument("--exec", dest="exec_path", required=True, help="executable path/command")
    create.add_argument(
        "--applications-dir",
        type=Path,
        default=APPLICATIONS_DIR,
        help="where to install the .desktop file (default: /usr/share/applications, needs root)",
    )
    create.set_defaults(func=_cmd_create)


def _cmd_create(args) -> int:
    install_launcher(
        args.name, args.generic_name, args.icon, args.exec_path, applications_dir=args.applications_dir
    )
    return 0
