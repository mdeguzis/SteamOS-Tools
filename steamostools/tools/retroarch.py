"""Launch RetroArch's menu.

Port of launchers/retroarch-debug and launchers/retroarch-src -- two
near-trivial launch wrappers, collapsed into one module with a --debug
flag instead of being separate scripts.
"""

from __future__ import annotations

import logging
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.retroarch")

DEFAULT_CONFIG = Path.home() / ".config" / "retroarch" / "retroarch.cfg"
DEFAULT_LOG_FILE = Path.home() / "retroarch" / "log.txt"


def launch(*, debug: bool = False, config: Path = DEFAULT_CONFIG, log_file: Path = DEFAULT_LOG_FILE) -> None:
    """Launch RetroArch's menu. In debug mode, run with --verbose and
    append output to log_file (matching retroarch-debug.sh); otherwise
    run against the current user's own config (matching retroarch-src.sh)."""
    if debug:
        log_file.parent.mkdir(parents=True, exist_ok=True)
        result = run(["retroarch", "--menu", "--verbose"], check=False)
        with log_file.open("a") as f:
            f.write(result.stdout or "")
            f.write(result.stderr or "")
    else:
        run(["retroarch", "--config", str(config), "--menu"], capture=False)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("retroarch", help="launch RetroArch's menu")
    sub = parser.add_subparsers(dest="retroarch_command", required=True)

    launch_p = sub.add_parser("launch", help="launch the RetroArch menu")
    launch_p.add_argument("--debug", action="store_true", help="verbose mode, logged to ~/retroarch/log.txt")
    launch_p.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    launch_p.set_defaults(func=_cmd_launch)


def _cmd_launch(args) -> int:
    launch(debug=args.debug, config=args.config)
    return 0
