"""Top-level CLI: `steamos-tools <group> <command> [...]`."""

from __future__ import annotations

import argparse
import logging
import sys
from pathlib import Path

from steamostools.logging_utils import initialize_logger
from steamostools.tools import proton_ge, rom_tools, screenshots, shader_util, unlock

_TOOL_MODULES = (proton_ge, screenshots, rom_tools, unlock, shader_util)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="steamos-tools",
        description="A unified tools platform for Arch-based SteamOS (Steam Deck) and Bazzite.",
    )
    parser.add_argument("-v", "--verbose", action="store_true", help="enable debug logging")
    parser.add_argument("-D", "--debug", action="store_true", help="enable debug logging (alias of -v)")
    parser.add_argument(
        "--log-file",
        type=Path,
        default=None,
        help="also write full debug output to this file (default: none)",
    )

    subparsers = parser.add_subparsers(dest="command", required=True)
    for module in _TOOL_MODULES:
        module.register_subparser(subparsers)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)

    log_level = logging.DEBUG if (args.verbose or args.debug) else logging.INFO
    log_filename = str(args.log_file) if args.log_file else None
    initialize_logger(log_level=log_level, log_filename=log_filename, scope="steamostools")

    logger = logging.getLogger("steamostools.cli")
    try:
        return args.func(args)
    except Exception as exc:  # top-level CLI boundary: report and exit non-zero, never swallow silently
        logger.error("%s: %s", type(exc).__name__, exc)
        if args.verbose or args.debug:
            raise
        return 1


if __name__ == "__main__":
    sys.exit(main())
