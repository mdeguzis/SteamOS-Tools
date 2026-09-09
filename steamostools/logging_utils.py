"""Canonical logger setup shared by every steamostools CLI subcommand.

This mirrors (and merges) the ``initialize_logger()`` pattern already used
in the author's other Python repos (``media-sorter.py``, ``recipesage.py``),
which had drifted from each other. This is the version going forward.
"""

from __future__ import annotations

import logging
import time
from pathlib import Path

DEFAULT_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
DEBUG_FORMAT = "[%(name)s] %(asctime)s - %(levelname)s - %(message)s"

# Third-party loggers that are noisy at DEBUG and not useful unless the
# caller explicitly asks for `debug_more`.
_NOISY_THIRD_PARTY_LOGGERS = ("urllib3", "requests")


class _TqdmLoggingHandler(logging.StreamHandler):
    """Routes log output through tqdm.write() so progress bars (downloads,
    batch ROM operations) and log lines don't collide on the terminal."""

    def emit(self, record: logging.LogRecord) -> None:
        try:
            from tqdm import tqdm

            tqdm.write(self.format(record))
        except Exception:
            self.handleError(record)


def initialize_logger(
    log_level: int = logging.INFO,
    log_filename: str | None = None,
    propagate: bool = False,
    scope: str | None = None,
    debug_more: bool = False,
    formatter: str = DEFAULT_FORMAT,
) -> logging.Logger:
    """Initialize a logger for stdout (and optional file) output.

    Args:
        log_level: Logging level (default: logging.INFO).
        log_filename: Optional path to also write a full log file to.
        propagate: Whether to propagate to the root logger (default: False).
        scope: Logger name -- namespace per tool (e.g. "screenshots", "rom_tools")
            so multi-tool CLI output stays attributable.
        debug_more: If False (default), suppress noisy third-party loggers
            (urllib3, requests) at WARNING regardless of log_level.
        formatter: Base log message format.

    Returns:
        The configured logger instance.
    """
    if formatter == DEFAULT_FORMAT and log_level == logging.DEBUG:
        formatter = DEBUG_FORMAT

    if not debug_more:
        for module in _NOISY_THIRD_PARTY_LOGGERS:
            logging.getLogger(module).setLevel(logging.WARNING)

    logger = logging.getLogger(scope)
    logger.setLevel(log_level)
    logger.propagate = propagate
    logger.handlers.clear()

    fmt = logging.Formatter(formatter, datefmt="%Y-%m-%dT%H:%M:%SZ")
    fmt.converter = time.gmtime  # UTC

    console_handler = _TqdmLoggingHandler()
    console_handler.setLevel(log_level)
    console_handler.setFormatter(fmt)
    logger.addHandler(console_handler)

    if log_filename:
        log_path = Path(log_filename).parent
        log_path.mkdir(parents=True, exist_ok=True)
        file_handler = logging.FileHandler(log_filename, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(fmt)
        logger.addHandler(file_handler)

    return logger
