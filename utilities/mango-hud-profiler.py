#!/usr/bin/env python3
"""
mango-hud-profiler.py -- MangoHud Performance Profiler for Bazzite / SteamOS

A fully-featured utility to configure, launch, profile, graph, and summarise MangoHud performance-logging sessions.  Designed for Bazzite (SteamOS
derivative) but works on any Linux distribution with MangoHud installed.

Subcommands
-----------
  configure   Generate or update a MangoHud configuration file.
  profile     Run a timed profiling session (launch -> log -> stop).
  graph       Produce PNG/SVG graphs from MangoHud CSV logs.
  summary     Print a human-readable summary of one or more log files,
              including paths suitable for web-based MangoHud viewers.

Author : SteamOS-Tools contributors
License: See LICENCE.md in repo root
"""
from __future__ import annotations

import argparse
import datetime
import json
import logging
import os
import pathlib
import re
import shutil
import subprocess
import sys
import textwrap
import time
from typing import Any, Dict, List, Optional, Tuple

PROG_NAME = "mango-hud-profiler"
VERSION = "1.0.0"
XDG_CONFIG = pathlib.Path(
    os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config")
)
XDG_DATA = pathlib.Path(
    os.environ.get("XDG_DATA_HOME", pathlib.Path.home() / ".local/share")
)
MANGOHUD_CONF_DIR = XDG_CONFIG / "MangoHud"
MANGOHUD_CONF_FILE = MANGOHUD_CONF_DIR / "MangoHud.conf"
# Standard MangoHud log/output paths for Bazzite/SteamOS
MANGOHUD_LOG_DIR = pathlib.Path.home() / "mangologs"
MANGOHUD_TMP_LOG = pathlib.Path("/tmp/MangoHud")
MANGOHUD_ALT_LOG = XDG_DATA / "MangoHud"
BENCH_LOG_DIR = MANGOHUD_LOG_DIR  # organized logs live alongside raw logs
CHART_BASE_DIR = pathlib.Path.home() / "mangohud-perf"
MAX_LOGS_PER_GAME = 15

# On Bazzite/SteamOS the gamescope session sets MANGOHUD_CONFIGFILE to a temp
# file managed by mangoapp.  This completely overrides MangoHud.conf and
# presets.conf (MANGOHUD_CONFIGFILE is highest priority).  mangoapp only writes
# display keys to that temp file -- logging keys are never applied.
# Fix: write MANGOHUD_CONFIG (applied on top of MANGOHUD_CONFIGFILE) with the
# logging keys to ~/.config/environment.d/ which gamescope-session-plus sources
# at startup before Steam launches.
MANGOHUD_ENV_CONF = XDG_CONFIG / "environment.d" / "mangohud-logging.conf"

# MangoHud config search order (highest priority first)
# Per-game wine configs: ~/.config/MangoHud/wine-<GameName>.conf
MANGOHUD_CONF_PATHS = [
    MANGOHUD_CONF_DIR / "MangoHud.conf",  # Standard user config
    pathlib.Path.home()
    / ".var/app/com.valvesoftware.Steam/config/MangoHud/MangoHud.conf",  # Steam Flatpak
]

# Keys that MUST be in config for useful bottleneck analysis with mangoplot
BOTTLENECK_KEYS = {
    "cpu_stats": 1,
    "gpu_stats": 1,
    "core_load": 1,  # Crucial for single-core CPU bottlenecks
    "gpu_core_clock": 1,  # Detects GPU downclocking (thermal bottleneck)
    "frametime": 1,  # Data for pacing graphs
    "frame_timing": 1,
}

# Logging keys that must be present for CSV output
LOGGING_REQUIRED_KEYS = {
    "output_folder": str(MANGOHUD_LOG_DIR),
    "toggle_logging": "Shift_L+F2",  # L-Shift + F2 to start/stop
    "log_duration": 0,  # 0 = manual start/stop
    "log_interval": 100,
    "log_versioning": 1,
}

# FlightlessSomething is the primary MangoHud-compatible web viewer.
# Upload multiple CSVs to the same Benchmark ID for side-by-side comparison.
FLIGHTLESS_URL = "https://flightlesssomething.com/benchmarks/new"
FLIGHTLESS_BASE = "https://flightlesssomething.ambrosia.one"
FLIGHTLESS_UPLOAD_ENDPOINT = f"{FLIGHTLESS_BASE}/api/benchmarks"
FLIGHTLESS_TOKEN_FILE = pathlib.Path.home() / ".flightless-token"

WEB_VIEWERS = [
    {
        "name": "FlightlessMango Log Viewer",
        "url": "https://flightlessmango.com/games/new",
        "note": "Upload the CSV directly. Supports all MangoHud log columns.",
    },
    {
        "name": "CapFrameX Web Analysis",
        "url": "https://www.capframex.com/analysis",
        "note": "Accepts MangoHud CSVs since v1.7.",
    },
]

_LOGGING_VALS = {
    **LOGGING_REQUIRED_KEYS,
    "autostart_log": 0,
    "fps": 1,
    "frametime": 1,
    "frame_timing": 1,
    **BOTTLENECK_KEYS,
    "cpu_temp": 1,
    "cpu_power": 1,
    "cpu_mhz": 1,
    "gpu_stats": 1,
    "gpu_temp": 1,
    "gpu_power": 1,
    "gpu_mem_clock": 1,
    "gpu_mem_temp": 1,
    "vram": 1,
    "ram": 1,
    "swap": 1,
    "battery": 1,
    "battery_power": 1,
    "gamepad_battery": 1,
    "throttling_status": 1,
    "io_read": 0,
    "io_write": 0,
    "wine": 1,
    "winesync": 1,
    "procmem": 1,
    "engine_version": 1,
    "vulkan_driver": 1,
    "gpu_name": 1,
    "no_display": 0,
    "position": "top-left",
    "background_alpha": "0.4",
    "font_size": 20,
}

CONFIG_PRESETS: Dict[str, Dict[str, Any]] = {
    "logging": {
        "description": "Full CSV logging, minimal OSD -- best for data collection.",
        "values": dict(_LOGGING_VALS),
    },
    "minimal": {
        "description": "Lightweight HUD -- FPS + frametime only, no logging.",
        "values": {
            "fps": 1,
            "frametime": 1,
            "frame_timing": 1,
            "cpu_stats": 0,
            "gpu_stats": 0,
            "no_display": 0,
            "position": "top-left",
            "background_alpha": "0.3",
            "font_size": 18,
        },
    },
    "full": {
        "description": "Everything on OSD and all logging enabled.",
        "values": {
            **_LOGGING_VALS,
            "autostart_log": 1,
            "io_read": 1,
            "io_write": 1,
            "background_alpha": "0.5",
            "font_size": 22,
        },
    },
    "battery": {
        "description": "Power / battery metrics -- ideal for Steam Deck / handheld.",
        "values": {
            "output_folder": str(MANGOHUD_LOG_DIR),
            "log_duration": 0,
            "log_interval": 500,
            "log_versioning": 1,
            "autostart_log": 0,
            "fps": 1,
            "frametime": 1,
            "battery": 1,
            "battery_power": 1,
            "gamepad_battery": 1,
            "cpu_temp": 1,
            "cpu_power": 1,
            "gpu_temp": 1,
            "gpu_power": 1,
            "throttling_status": 1,
            "no_display": 0,
            "position": "top-right",
            "background_alpha": "0.35",
            "font_size": 18,
        },
    },
}

# ── Valve / SteamOS preset definitions ─────────────────────────────────
# These mirror what MangoHud ships in data/presets.conf (presets 1-2)
# plus the built-in defaults that gamescope uses for presets 3-4.
# The Steam Deck Performance Overlay slider selects among these.
# We inject logging keys into every preset so that CSV recording works
# regardless of which slider position the user picks.
#
# Valve originals (for reference):
#   preset 1 = no_display  (overlay hidden)
#   preset 2 = FPS only    (horizontal, fps_only)
#   preset 3 = extended    (horizontal compact, CPU/GPU/frametime/battery)
#   preset 4 = full detail (vertical, all stats)

_PRESET_LOGGING_KEYS: Dict[str, Any] = {
    "output_folder": str(MANGOHUD_LOG_DIR),
    "toggle_logging": "Shift_L+F2",
    "log_duration": 0,
    "log_interval": 100,
    "log_versioning": 1,
    "autostart_log": 0,
}

VALVE_PRESETS: Dict[int, Dict[str, Any]] = {
    # ── Preset 1: No display (overlay hidden, logging active in background) ─
    1: {
        "description": "Valve preset 1 (no display) + logging",
        "values": {
            "no_display": 1,
            **_PRESET_LOGGING_KEYS,
        },
    },
    # ── Preset 2: FPS only (horizontal bar, minimal) ───────────────────────
    2: {
        "description": "Valve preset 2 (FPS only) + logging",
        "values": {
            "legacy_layout": 0,
            "cpu_stats": 0,
            "gpu_stats": 0,
            "fps": 1,
            "fps_only": 1,
            "frametime": 0,
            **_PRESET_LOGGING_KEYS,
        },
    },
    # ── Preset 3: Extended (horizontal compact with core stats) ────────────
    3: {
        "description": "Valve preset 3 (extended) + logging",
        "values": {
            "legacy_layout": 0,
            "horizontal": 1,
            "hud_compact": 1,
            "gpu_stats": 1,
            "cpu_stats": 1,
            "fps": 1,
            "frametime": 1,
            "frame_timing": 1,
            "battery": 1,
            **_PRESET_LOGGING_KEYS,
        },
    },
    # ── Preset 4: Full detail (vertical, everything visible) ───────────────
    4: {
        "description": "Valve preset 4 (full detail) + logging",
        "values": {
            "legacy_layout": 0,
            "gpu_stats": 1,
            "cpu_stats": 1,
            "cpu_temp": 1,
            "gpu_temp": 1,
            "cpu_power": 1,
            "gpu_power": 1,
            "cpu_mhz": 1,
            "gpu_core_clock": 1,
            "gpu_mem_clock": 1,
            "vram": 1,
            "ram": 1,
            "fps": 1,
            "frametime": 1,
            "frame_timing": 1,
            "battery": 1,
            "battery_power": 1,
            "gamepad_battery": 1,
            "fan": 1,
            "throttling_status": 1,
            "wine": 1,
            "engine_version": 1,
            "vulkan_driver": 1,
            "gpu_name": 1,
            "core_load": 1,
            **_PRESET_LOGGING_KEYS,
        },
    },
}

LOG_FMT = "%(asctime)s [%(levelname)-7s] %(name)s: %(message)s"
LOG_DATEFMT = "%Y-%m-%d %H:%M:%S"
log = logging.getLogger(PROG_NAME)


def setup_logging(verbosity: int = 0, logfile: Optional[str] = None) -> None:
    """
    Setup logging
    """

    level = [logging.WARNING, logging.INFO, logging.DEBUG][min(verbosity, 2)]
    handlers: List[logging.Handler] = [logging.StreamHandler(sys.stderr)]
    if logfile:
        fh = logging.FileHandler(logfile, mode="a", encoding="utf-8")
        fh.setFormatter(logging.Formatter(LOG_FMT, datefmt=LOG_DATEFMT))
        handlers.append(fh)
    logging.basicConfig(
        level=level, format=LOG_FMT, datefmt=LOG_DATEFMT, handlers=handlers
    )
    log.setLevel(level)


# -- helpers ----------------------------------------------------------------


def detect_os() -> Dict[str, str]:
    info: Dict[str, str] = {}
    p = pathlib.Path("/etc/os-release")
    if p.exists():
        for ln in p.read_text().splitlines():
            if "=" in ln:
                k, _, v = ln.partition("=")
                info[k.strip()] = v.strip().strip('"')
    return info


def is_bazzite() -> bool:
    i = detect_os()
    return "bazzite" in (i.get("NAME", "") + " " + i.get("ID", "")).lower()


def is_steamos() -> bool:
    i = detect_os()
    return (
        "steamos" in (i.get("ID", "") + " " + i.get("ID_LIKE", "")).lower()
        or is_bazzite()
    )


def mangohud_installed() -> bool:
    return shutil.which("mangohud") is not None


def find_logs(
    d: Optional[pathlib.Path] = None, pat: str = "*.csv", game: Optional[str] = None
) -> List[pathlib.Path]:
    """Find MangoHud CSV logs, optionally filtered by game name.

    Searches ~/Documents/MangoLogs, /tmp/MangoHud, and XDG data dir.
    When *game* is given, only files whose stem starts with that string
    (case-insensitive) are returned.
    """
    dirs = [d] if d else [MANGOHUD_LOG_DIR, MANGOHUD_TMP_LOG, MANGOHUD_ALT_LOG]
    r: List[pathlib.Path] = []
    for x in dirs:
        if x and x.is_dir():
            r.extend(sorted(x.glob(pat)))
    if game:
        gl = game.lower()
        r = [p for p in r if p.stem.lower().startswith(gl)]
    return r


def newest_log(
    d: Optional[pathlib.Path] = None, game: Optional[str] = None
) -> Optional[pathlib.Path]:
    ls = find_logs(d, game=game)
    return max(ls, key=lambda p: p.stat().st_mtime) if ls else None


def discover_games(d: Optional[pathlib.Path] = None) -> List[str]:
    """Return sorted unique game names found in MangoHud log filenames.

    MangoHud logs are typically ``GameName_YYYY-MM-DD_HH-MM-SS.csv``.
    We extract the portion before the first ``_YYYY`` or ``_20`` pattern.
    """
    logs = find_logs(d)
    names: set[str] = set()
    for p in logs:
        stem = p.stem
        # Try to split at _YYYY or _20 (year prefix)
        m = re.match(r"^(.+?)_\d{4}[-_]", stem)
        if m:
            names.add(m.group(1))
        else:
            # Fallback: entire stem (no timestamp found)
            names.add(stem)
    return sorted(names, key=str.lower)


# ── MangoHud CSV spec header fields ────────────────────────────────────
# FlightlessSomething expects this 3-line header in MangoHud CSVs:
#   Line 1: os,cpu,gpu,ram,kernel,driver,cpuscheduler  (spec field names)
#   Line 2: <actual spec values>
#   Line 3: fps,frametime,cpu_load,...,elapsed          (data column headers)
#   Line 4+: numeric data rows
_MANGOHUD_SPEC_FIELDS = {"os", "cpu", "gpu", "ram", "kernel", "driver", "cpuscheduler"}


def _strip_v1_preamble(lines: List[str]) -> List[str]:
    """Remove MangoHud ≥0.8 preamble lines, leaving the 3-line spec format.

    MangoHud 0.8.x prepends several lines before the standard spec header:
      v1                                      <- format version tag
      v0.8.1                                  <- MangoHud version
      -----SYSTEM INFO-----                   <- separator
      os,cpu,gpu,ram,kernel,driver,cpuscheduler
      <spec values>
      -----FRAME METRICS-----                 <- separator
      fps,frametime,...
      <data rows>

    After stripping, the remaining lines match the 3-line spec format that
    FlightlessSomething and the rest of this script expect.
    """
    return [
        ln for ln in lines
        if not re.match(r"^v\d", ln.strip())   # v1, v0.8.1, etc.
        and not re.match(r"^-{3}", ln.strip())  # -----SYSTEM INFO-----, etc.
    ]


def _normalize_csv_for_flightless(path: pathlib.Path) -> str:
    """Return CSV content normalized to the FlightlessSomething 3-line spec format.

    Strips MangoHud 0.8+ preamble (v1 tag, version line, separator rows) so
    that the upload contains only:
      Line 1: os,cpu,gpu,ram,kernel,driver,cpuscheduler
      Line 2: <spec values>
      Line 3: fps,frametime,...
      Line 4+: data rows
    """
    raw = path.read_text(encoding="utf-8", errors="replace").splitlines()
    cleaned = _strip_v1_preamble([ln for ln in raw if ln.strip()])
    return "\n".join(cleaned) + "\n"


def parse_csv(
    path: pathlib.Path,
) -> Tuple[List[str], List[Dict[str, str]]]:
    """Parse a MangoHud CSV log, returning (column_names, rows).

    Handles the modern 3-line spec-header format, MangoHud 0.8+ v1 format
    (with preamble lines stripped automatically), and the legacy #-comment
    format.
    """
    lines = [
        s
        for s in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if s.strip()
    ]
    if not lines:
        return [], []

    # Strip MangoHud 0.8+ preamble (v1, version string, --- separators)
    # before format detection so the rest of the logic sees the clean header.
    lines = _strip_v1_preamble(lines)
    if not lines:
        return [], []

    # ── Detect the modern spec-header format ───────────────────────────
    # Line 1 fields are a subset of _MANGOHUD_SPEC_FIELDS
    first_fields = {f.strip().lower() for f in lines[0].split(",")}
    if first_fields & _MANGOHUD_SPEC_FIELDS and len(first_fields & _MANGOHUD_SPEC_FIELDS) >= 3:
        # Modern format: skip spec header (line 0) and spec values (line 1)
        # Data column headers are on line 2
        if len(lines) < 3:
            return [], []
        cols = [c.strip() for c in lines[2].split(",")]
        rows: List[Dict[str, str]] = []
        for ln in lines[3:]:
            vs = ln.split(",")
            if len(vs) == len(cols):
                rows.append(dict(zip(cols, [v.strip() for v in vs])))
        return cols, rows

    # ── Legacy format: skip # comments, find header by heuristic ──────
    hi = 0
    for i, ln in enumerate(lines):
        if ln.startswith("#"):
            hi = i + 1
            continue
        parts = ln.split(",")
        if (
            sum(1 for p in parts if re.match(r"^[A-Za-z_]+", p.strip()))
            > len(parts) * 0.5
        ):
            hi = i
            break
    cols = [c.strip() for c in lines[hi].split(",")]
    rows = []
    for ln in lines[hi + 1 :]:
        vs = ln.split(",")
        if len(vs) == len(cols):
            rows.append(dict(zip(cols, [v.strip() for v in vs])))
    return cols, rows


def sf(v: str, d: float = 0.0) -> float:
    try:
        return float(v)
    except (ValueError, TypeError):
        return d


def hdur(s: float) -> str:
    if s < 60:
        return f"{s:.1f}s"
    m, s2 = divmod(s, 60)
    if m < 60:
        return f"{int(m)}m {s2:.0f}s"
    h, m = divmod(m, 60)
    return f"{int(h)}h {int(m)}m {s2:.0f}s"


def pctl(sv: List[float], p: float) -> float:
    if not sv:
        return 0.0
    k = (len(sv) - 1) * (p / 100.0)
    f = int(k)
    c = min(f + 1, len(sv) - 1)
    return sv[f] + (k - f) * (sv[c] - sv[f])


def _fcol(cols: List[str], cands: List[str]) -> Optional[str]:
    m = {c.lower(): c for c in cols}
    for c in cands:
        if c.lower() in m:
            return m[c.lower()]
    return None


# -- configure --------------------------------------------------------------


def _find_active_mangohud_conf() -> Optional[pathlib.Path]:
    """Find the first existing MangoHud config in precedence order."""
    env_path = os.environ.get("MANGOHUD_CONFIGFILE")
    if env_path:
        p = pathlib.Path(env_path)
        if p.exists():
            return p
    for p in MANGOHUD_CONF_PATHS:
        if p.exists():
            return p
    return None


def _read_conf_keys(path: pathlib.Path) -> Dict[str, str]:
    """Parse an existing MangoHud.conf into key=value dict."""
    result: Dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if "=" in line:
            k, _, v = line.partition("=")
            result[k.strip()] = v.strip()
        else:
            # Bare key (boolean toggle) e.g. "fps" means fps=1
            result[line] = "1"
    return result


def _ensure_bottleneck_keys(conf_path: pathlib.Path) -> List[str]:
    """Check config has bottleneck + logging keys; return list of missing keys added."""
    existing = _read_conf_keys(conf_path)
    needed = {**BOTTLENECK_KEYS, **LOGGING_REQUIRED_KEYS}
    missing = {k: v for k, v in needed.items() if k not in existing}
    if not missing:
        return []
    # Append missing keys
    addition = "\n# Added by mango-hud-profiler for bottleneck analysis + logging\n"
    addition += "\n".join(f"{k}={v}" for k, v in missing.items()) + "\n"
    with open(conf_path, "a", encoding="utf-8") as f:
        f.write(addition)
    return list(missing.keys())


def sync_gamescope_logging_env(log_dir: Optional[pathlib.Path] = None) -> bool:
    """Write MANGOHUD_CONFIG logging keys to ~/.config/environment.d/.

    On Bazzite/SteamOS, gamescope-session-plus exports MANGOHUD_CONFIGFILE
    pointing to a temp file managed by mangoapp.  Because MANGOHUD_CONFIGFILE
    takes precedence over MangoHud.conf and presets.conf, logging keys set
    there are never seen by game processes.

    The MANGOHUD_CONFIG env var is applied *on top* of MANGOHUD_CONFIGFILE, so
    writing it to ~/.config/environment.d/ (sourced by gamescope-session-plus
    at startup) injects logging keys into every game without disturbing the
    display behaviour that mangoapp controls.

    Returns True on success, False on error.
    """
    effective_log_dir = log_dir or MANGOHUD_LOG_DIR
    effective_log_dir.mkdir(parents=True, exist_ok=True)

    # Build comma-separated MANGOHUD_CONFIG value (logging keys only -- display
    # settings are still owned by mangoapp via MANGOHUD_CONFIGFILE).
    logging_keys = {
        "output_folder": str(effective_log_dir),
        "toggle_logging": "Shift_L+F2",
        "log_duration": "0",
        "log_interval": "100",
        "log_versioning": "1",
    }
    config_value = ",".join(f"{k}={v}" for k, v in logging_keys.items())

    MANGOHUD_ENV_CONF.parent.mkdir(parents=True, exist_ok=True)
    content = (
        f"# MangoHud logging env -- written by {PROG_NAME} v{VERSION}\n"
        f"# Injects logging keys via MANGOHUD_CONFIG so they survive the\n"
        f"# gamescope-session MANGOHUD_CONFIGFILE temp-file override.\n"
        f"# Sourced by gamescope-session-plus from ~/.config/environment.d/\n"
        f"# Changes take effect on next gamescope session (re-login).\n"
        f'MANGOHUD_CONFIG="{config_value}"\n'
    )
    try:
        MANGOHUD_ENV_CONF.write_text(content, encoding="utf-8")
    except OSError as exc:
        log.error("Failed to write %s: %s", MANGOHUD_ENV_CONF, exc)
        return False

    print(f"  Gamescope logging env: {MANGOHUD_ENV_CONF}")
    print(f"    MANGOHUD_CONFIG set with logging keys -> {effective_log_dir}")
    print("    Re-login to gamescope session for changes to take effect.")
    return True


def sync_config_to_preset(log_dir: Optional[pathlib.Path] = None) -> bool:
    """Write all 4 Valve presets (with logging) to ~/.config/MangoHud/presets.conf.

    Each preset mirrors Valve's original OSD behaviour for that slider
    position but adds CSV logging keys so performance data is always
    captured regardless of which overlay level the user selects.

    Returns True on success, False on error.
    """
    target_path = MANGOHUD_CONF_DIR / "presets.conf"
    target_path.parent.mkdir(parents=True, exist_ok=True)

    # Ensure the log directory exists
    effective_log_dir = log_dir or MANGOHUD_LOG_DIR
    effective_log_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.datetime.now().isoformat()
    lines: List[str] = [
        f"# MangoHud presets.conf -- generated by {PROG_NAME} v{VERSION}",
        f"# Generated: {ts}",
        "#",
        "# Overrides Valve's default presets 1-4 to inject CSV logging.",
        "# The Steam Performance Overlay slider picks [preset N].",
        "# OSD appearance matches Valve's originals; logging runs silently.",
        "#   Toggle logging: Shift_L+F2  |  Logs: " + str(effective_log_dir),
        "",
    ]

    for num in sorted(VALVE_PRESETS):
        preset = VALVE_PRESETS[num]
        vals = dict(preset["values"])
        # Allow caller to override log directory
        if log_dir:
            vals["output_folder"] = str(log_dir)
        lines.append(f"[preset {num}]")
        lines.append(f"# {preset['description']}")
        for k, v in vals.items():
            lines.append(f"{k}={v}")
        lines.append("")

    content = "\n".join(lines) + "\n"

    try:
        target_path.write_text(content, encoding="utf-8")
    except OSError as exc:
        log.error("Failed to write presets.conf: %s", exc)
        return False

    print(f"  Presets written: {target_path}")
    print(f"    Presets 1-4 now include CSV logging to {effective_log_dir}")
    print("    Toggle logging: Shift_L+F2 at any slider position.")
    for num in sorted(VALVE_PRESETS):
        desc = VALVE_PRESETS[num]["description"]
        print(f"      Preset {num}: {desc}")

    # On Bazzite/SteamOS, gamescope-session-plus sets MANGOHUD_CONFIGFILE to a
    # temp file managed by mangoapp, which overrides presets.conf.  Inject
    # logging keys via MANGOHUD_CONFIG in environment.d to work around this.
    if is_steamos():
        sync_gamescope_logging_env(log_dir=log_dir)

    return True


def cmd_configure(args: argparse.Namespace) -> int:
    pn = args.preset

    # Detect target config path
    if args.game:
        # Per-game: MangoHud reads ~/.config/MangoHud/wine-<GameName>.conf for Proton games
        # or ~/.config/MangoHud/<GameName>.conf for native games
        game_conf = MANGOHUD_CONF_DIR / f"wine-{args.game}.conf"
        out = (
            pathlib.Path(args.output)
            if args.output != str(MANGOHUD_CONF_FILE)
            else game_conf
        )
    elif args.check:
        # --check mode: find and update existing config
        found = _find_active_mangohud_conf()
        if found:
            added = _ensure_bottleneck_keys(found)
            if added:
                print(f"  Updated: {found}")
                print(
                    f"    Added missing keys for bottleneck analysis: {', '.join(added)}"
                )
            else:
                print(f"  Config OK: {found}")
                print("    All bottleneck + logging keys already present.")
            return 0
        else:
            print("  No existing MangoHud config found. Creating new one...")
            out = MANGOHUD_CONF_FILE
    else:
        out = pathlib.Path(args.output)

    if pn not in CONFIG_PRESETS:
        log.error("Unknown preset '%s'. Available: %s", pn, ", ".join(CONFIG_PRESETS))
        return 1
    pr = CONFIG_PRESETS[pn]
    vals: Dict[str, Any] = dict(pr["values"])
    for pair in args.set or []:
        if "=" in pair:
            k, _, v = pair.partition("=")
            vals[k.strip()] = v.strip()
    if args.log_dir:
        vals["output_folder"] = str(args.log_dir)

    # Ensure log dir exists
    log_dir = pathlib.Path(vals.get("output_folder", str(MANGOHUD_LOG_DIR)))
    log_dir.mkdir(parents=True, exist_ok=True)

    hdr = textwrap.dedent(
        f"""\
        # MangoHud config -- {PROG_NAME} v{VERSION}
        # Preset: {pn} -- {pr['description']}
        # Generated: {datetime.datetime.now().isoformat()}
        # Docs: https://github.com/flightlessmango/MangoHud#mangohud_config
        # Toggle logging: Shift_L+F2 (start/stop CSV recording)
    """
    )
    txt = hdr + "\n" + "\n".join(f"{k}={v}" for k, v in vals.items()) + "\n"
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and not args.force:
        log.warning("File exists: %s (use --force)", out)
        return 1

    # Write Valve presets 1-4 with logging to presets.conf so the Steam
    # Performance Overlay slider works with CSV recording at every level.
    sync_config_to_preset(log_dir=log_dir)

    out.write_text(txt, encoding="utf-8")
    scope = f"game '{args.game}' (wine-{args.game}.conf)" if args.game else "global"
    print(f"  Config written: {out}")
    print(f"    Preset: {pn} -- {pr['description']}")
    print(f"    Scope : {scope}")
    print(f"    Logs  : {log_dir}")
    print("    Toggle: Shift_L+F2 to start/stop logging")
    if args.game:
        print(f"    MangoHud auto-applies when running '{args.game}' via Proton/Wine.")
    # Show all config paths for reference
    print("\n    Config precedence (MangoHud checks in order):")
    print("      1. MANGOHUD_CONFIGFILE env var")
    if args.game:
        print(f"      2. ~/.config/MangoHud/wine-{args.game}.conf  <-- this file")
    print(f"      3. {MANGOHUD_CONF_FILE}")
    print("      4. ~/.var/app/com.valvesoftware.Steam/config/MangoHud/MangoHud.conf")
    if is_steamos():
        print("\n    Bazzite/SteamOS note:")
        print("      gamescope-session sets MANGOHUD_CONFIGFILE to a temp file managed")
        print("      by mangoapp, which overrides MangoHud.conf and presets.conf.")
        print(f"      Logging keys written to: {MANGOHUD_ENV_CONF}")
        print("      Re-login to your gamescope session for logging to take effect.")
    return 0


# -- profile ----------------------------------------------------------------


def cmd_profile(args: argparse.Namespace) -> int:
    if not mangohud_installed():
        log.error("MangoHud not found.")
        return 1
    cmd = args.command
    dur = args.duration
    ld = pathlib.Path(args.log_dir) if args.log_dir else MANGOHUD_LOG_DIR
    ld.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env["MANGOHUD"] = "1"
    env["MANGOHUD_LOG"] = "1"
    env["MANGOHUD_OUTPUT"] = str(ld)
    if args.config:
        env["MANGOHUD_CONFIGFILE"] = str(args.config)
    full = ["mangohud"] + cmd.split()
    print(
        f"  Profiling for {hdur(dur)}:\n    Command: mangohud {cmd}\n    Log dir: {ld}\n"
    )
    before = set(find_logs(ld))
    try:
        proc = subprocess.Popen(full, env=env)
    except FileNotFoundError:
        log.error("Launch failed.")
        return 1
    t0 = time.monotonic()
    try:
        proc.wait(timeout=dur)
        el = time.monotonic() - t0
        print(f"\n  Exited after {hdur(el)}")
    except subprocess.TimeoutExpired:
        el = time.monotonic() - t0
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        print(f"\n  Session ended after {hdur(el)}")
    except KeyboardInterrupt:
        el = time.monotonic() - t0
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        print(f"\n  Interrupted after {hdur(el)}")
    time.sleep(0.5)
    new = sorted(set(find_logs(ld)) - before)
    if new:
        print("\n  New log file(s):")
        for f in new:
            print(f"    {f}  ({f.stat().st_size/1024:.1f} KB)")
        if args.auto_summary:
            print()
            for logf in new:
                _print_summary(logf)
        if args.auto_graph:
            print()
            od = pathlib.Path(args.graph_output) if args.graph_output else new[0].parent
            for logf in new:
                _gen_graphs(logf, od, fmt=args.graph_format)
    else:
        print(f"\n  No new logs found. Check config. Expected dir: {ld}")
    return 0


# -- graph ------------------------------------------------------------------

_MPL = False
try:
    import matplotlib  # type: ignore[import-not-found]

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt  # type: ignore[import-not-found]

    _MPL = True
except ImportError:
    pass


# ── FlightlessSomething-style dark theme ───────────────────────────────
# Mirrors the Highcharts theme from https://github.com/erkexzcx/flightlesssomething
# Dark background (#212529), white text, subtle grid, area-fill line charts.
_FS_THEME = {
    "bg": "#212529",
    "text": "#FFFFFF",
    "grid": "rgba(255, 255, 255, 0.1)",
    "line": "#FFFFFF",
    "tooltip_bg": "#1E1E1E",
    # Default series palette (matches Highcharts defaults)
    "palette": [
        "#7cb5ec",
        "#434348",
        "#90ed7d",
        "#f7a35c",
        "#8085e9",
        "#f15c80",
        "#e4d354",
        "#2b908f",
        "#f45b5b",
        "#91e8e1",
    ],
}


def _apply_fs_theme(fig: Any, ax: Any, title: str, ylabel: str) -> None:
    """Apply FlightlessSomething dark theme to a matplotlib axes."""
    fig.patch.set_facecolor(_FS_THEME["bg"])
    ax.set_facecolor(_FS_THEME["bg"])
    ax.set_title(title, fontsize=16, fontweight="bold", color=_FS_THEME["text"])
    ax.set_ylabel(ylabel, color=_FS_THEME["text"], fontsize=12)
    ax.set_xlabel("Sample", color=_FS_THEME["text"], fontsize=12)
    ax.tick_params(colors=_FS_THEME["text"], which="both")
    ax.grid(True, color=_FS_THEME["text"], alpha=0.1, linewidth=0.5)
    for spine in ax.spines.values():
        spine.set_color(_FS_THEME["line"])
        spine.set_alpha(0.3)


def _plot(
    vals: List[float],
    title: str,
    ylabel: str,
    color: str,
    fa: float,
    out: pathlib.Path,
    dpi: int = 150,
    sz: Tuple[float, float] = (14, 6),
) -> None:
    fig, ax = plt.subplots(figsize=sz, dpi=dpi)
    x = list(range(len(vals)))
    ax.plot(x, vals, color=color, lw=1.2)
    ax.fill_between(x, vals, alpha=fa, color=color)
    _apply_fs_theme(fig, ax, title, ylabel)
    fig.tight_layout()
    fig.savefig(str(out), facecolor=fig.get_facecolor(), edgecolor="none")
    plt.close(fig)
    print(f"    Graph: {out}")


def _gen_graphs(
    csv_path: pathlib.Path,
    out_dir: pathlib.Path,
    fmt: str = "png",
    dpi: int = 150,
    w: float = 14,
    h: float = 6,
) -> int:
    if not _MPL:
        log.warning("matplotlib unavailable.")
        return 1
    cols, rows = parse_csv(csv_path)
    if not rows:
        log.warning("No data in %s", csv_path)
        return 1
    s = csv_path.stem
    gen = []
    for cands, label, unit, clr, fa in [
        (["fps", "FPS"], "FPS", "Frames/s", "#2ecc71", 0.25),
        (
            ["frametime", "frametime_ms", "Frametime"],
            "Frame Time",
            "ms",
            "#e74c3c",
            0.20,
        ),
        (["cpu_temp", "CPU_Temp"], "CPU Temp", "C", "#e67e22", 0.15),
        (["gpu_temp", "GPU_Temp"], "GPU Temp", "C", "#9b59b6", 0.15),
        (["cpu_power", "CPU_Power"], "CPU Power", "W", "#f39c12", 0.15),
        (["gpu_power", "GPU_Power"], "GPU Power", "W", "#8e44ad", 0.15),
        (["battery", "Battery"], "Battery", "%", "#1abc9c", 0.20),
        (["ram", "RAM"], "RAM", "MB", "#3498db", 0.15),
        (["vram", "VRAM"], "VRAM", "MB", "#2980b9", 0.15),
    ]:
        k = _fcol(cols, cands)
        if k:
            vs = [sf(r.get(k, "0")) for r in rows]
            if any(v > 0 for v in vs):
                tag = cands[0].lower().replace(" ", "_")
                o = out_dir / f"{s}_{tag}.{fmt}"
                _plot(vs, f"{label} -- {s}", unit, clr, fa, o, dpi, (w, h))
                gen.append(o)
    # Combined FPS+Frametime (FlightlessSomething style)
    fk = _fcol(cols, ["fps", "FPS"])
    ftk = _fcol(cols, ["frametime", "frametime_ms", "Frametime"])
    if fk and ftk and _MPL:
        fig, (a1, a2) = plt.subplots(2, 1, figsize=(w, h * 1.2), dpi=dpi, sharex=True)
        x = list(range(len(rows)))
        fv = [sf(r.get(fk, "0")) for r in rows]
        tv = [sf(r.get(ftk, "0")) for r in rows]
        a1.plot(x, fv, color="#7cb5ec", lw=1.2)
        a1.fill_between(x, fv, alpha=0.2, color="#7cb5ec")
        _apply_fs_theme(fig, a1, f"FPS -- {s}", "FPS")
        a1.set_xlabel("")  # shared x, only bottom gets label
        a2.plot(x, tv, color="#f7a35c", lw=1.2)
        a2.fill_between(x, tv, alpha=0.15, color="#f7a35c")
        _apply_fs_theme(fig, a2, f"Frametime -- {s}", "ms")
        fig.tight_layout()
        o = out_dir / f"{s}_overview.{fmt}"
        fig.savefig(str(o), facecolor=fig.get_facecolor(), edgecolor="none")
        plt.close(fig)
        gen.append(o)
        print(f"    Graph: {o}")

    # ── Summary bar chart (FlightlessSomething "Summary" tab style) ────
    # Horizontal bars: Average, 1% Low, 0.1% Low for FPS
    if fk and _MPL:
        fv_sorted = sorted([sf(r.get(fk, "0")) for r in rows])
        if fv_sorted and max(fv_sorted) > 0:
            avg_fps = sum(fv_sorted) / len(fv_sorted)
            p1_fps = pctl(fv_sorted, 1)
            p01_fps = pctl(fv_sorted, 0.1)
            labels = ["Average", "1% Low", "0.1% Low"]
            values = [avg_fps, p1_fps, p01_fps]
            bar_colors = ["#7cb5ec", "#90ed7d", "#f7a35c"]

            fig, ax = plt.subplots(figsize=(w, 3.5), dpi=dpi)
            fig.patch.set_facecolor(_FS_THEME["bg"])
            ax.set_facecolor(_FS_THEME["bg"])
            bars = ax.barh(
                labels,
                values,
                color=bar_colors,
                edgecolor=_FS_THEME["line"],
                linewidth=0.5,
                height=0.5,
            )
            # Value labels on bars
            for bar, val in zip(bars, values):
                ax.text(
                    bar.get_width() + max(values) * 0.02,
                    bar.get_y() + bar.get_height() / 2,
                    f"{val:.1f} fps",
                    va="center",
                    color=_FS_THEME["text"],
                    fontsize=12,
                    fontweight="bold",
                )
            ax.set_title(
                f"FPS Summary -- {s}",
                fontsize=16,
                fontweight="bold",
                color=_FS_THEME["text"],
            )
            ax.set_xlabel("FPS", color=_FS_THEME["text"], fontsize=12)
            ax.tick_params(colors=_FS_THEME["text"], which="both")
            ax.grid(True, axis="x", color=_FS_THEME["text"], alpha=0.1, linewidth=0.5)
            ax.set_xlim(0, max(values) * 1.15)
            for spine in ax.spines.values():
                spine.set_color(_FS_THEME["line"])
                spine.set_alpha(0.3)
            ax.invert_yaxis()  # Average on top
            fig.tight_layout()
            o = out_dir / f"{s}_summary.{fmt}"
            fig.savefig(str(o), facecolor=fig.get_facecolor(), edgecolor="none")
            plt.close(fig)
            gen.append(o)
            print(f"    Graph: {o}")

    if gen:
        print(f"  {len(gen)} graph(s) generated in {out_dir}")
    return 0


def _mangoplot_available() -> bool:
    return shutil.which("mangoplot") is not None


def _run_mangoplot(csv_path: pathlib.Path, out_dir: pathlib.Path) -> int:
    """Run mangoplot on a CSV, saving output to out_dir."""
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = ["mangoplot", str(csv_path)]
    log.info("Running: %s (output -> %s)", " ".join(cmd), out_dir)
    try:
        result = subprocess.run(
            cmd,
            cwd=str(out_dir),
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
        if result.returncode == 0:
            # mangoplot creates PNG files in the cwd
            pngs = list(out_dir.glob("*.png"))
            if pngs:
                print(f"    mangoplot generated {len(pngs)} chart(s) in {out_dir}")
                for p in sorted(pngs):
                    print(f"      {p.name}")
            else:
                print(f"    mangoplot completed but no PNGs found in {out_dir}")
            if result.stdout.strip():
                print(result.stdout.strip())
        else:
            log.warning("mangoplot exited with code %d", result.returncode)
            if result.stderr.strip():
                log.warning("mangoplot stderr: %s", result.stderr.strip())
        return result.returncode
    except FileNotFoundError:
        log.error("mangoplot not found in PATH.")
        return 1
    except subprocess.TimeoutExpired:
        log.error("mangoplot timed out after 60s.")
        return 1


def cmd_graph(args: argparse.Namespace) -> int:
    game = getattr(args, "game", None)
    ip = pathlib.Path(args.input) if args.input else newest_log(game=game)
    if ip is None or not ip.exists():
        log.error("No input file.%s", f" (filtered by game '{game}')" if game else "")
        return 1

    # Determine output dir: ~/mangohud-perf/<GAME>/charts/
    if args.output:
        od = pathlib.Path(args.output)
    elif game:
        od = CHART_BASE_DIR / game / "charts"
    else:
        gn = _extract_game_name(ip.stem)
        od = CHART_BASE_DIR / gn / "charts"

    od.mkdir(parents=True, exist_ok=True)

    # Prefer mangoplot if available (native MangoHud tool, best bottleneck info)
    if _mangoplot_available() and not args.matplotlib:
        print(f"  Using mangoplot (system) for {ip.name}")
        ret = _run_mangoplot(ip, od)
        if ret == 0:
            return 0
        print("  mangoplot failed, falling back to matplotlib...")

    # Fallback to matplotlib
    if not _MPL:
        log.error(
            "Neither mangoplot nor matplotlib available.\n"
            "  Install mangoplot (comes with MangoHud) or: pip install matplotlib"
        )
        return 1
    return _gen_graphs(
        ip, od, fmt=args.format, dpi=args.dpi, w=args.width, h=args.height
    )


# -- summary ----------------------------------------------------------------


def _print_summary(path: pathlib.Path) -> None:
    cols, rows = parse_csv(path)
    if not rows:
        print(f"  Summary: {path.name} -- no data rows.")
        return

    n = len(rows)
    info = detect_os()
    print("=" * 72)
    print(f"  MANGOHUD LOG SUMMARY: {path.name}")
    print("=" * 72)
    print(f"  File       : {path}")
    print(f"  Size       : {path.stat().st_size / 1024:.1f} KB")
    print(f"  Samples    : {n}")
    print(f"  OS         : {info.get('PRETTY_NAME', 'Unknown')}")
    if is_bazzite():
        print("  Platform   : Bazzite (SteamOS derivative)")
    elif is_steamos():
        print("  Platform   : SteamOS derivative")
    print()

    def _stat(key_cands: List[str], label: str, unit: str = "") -> None:
        k = _fcol(cols, key_cands)
        if not k:
            return
        vs = sorted([sf(r.get(k, "0")) for r in rows])
        if not vs or max(vs) == 0:
            return
        avg = sum(vs) / len(vs)
        print(
            f"  {label:20s}  avg={avg:8.1f}{unit}  "
            f"min={vs[0]:.1f}  max={vs[-1]:.1f}  "
            f"1%={pctl(vs,1):.1f}  5%={pctl(vs,5):.1f}  "
            f"95%={pctl(vs,95):.1f}  99%={pctl(vs,99):.1f}"
        )

    print("  --- Performance ---")
    _stat(["fps", "FPS"], "FPS", " fps")
    _stat(["frametime", "frametime_ms", "Frametime"], "Frame Time", " ms")
    print("\n  --- Thermals ---")
    _stat(["cpu_temp", "CPU_Temp"], "CPU Temp", " C")
    _stat(["gpu_temp", "GPU_Temp"], "GPU Temp", " C")
    print("\n  --- Power ---")
    _stat(["cpu_power", "CPU_Power"], "CPU Power", " W")
    _stat(["gpu_power", "GPU_Power"], "GPU Power", " W")
    _stat(["battery_power"], "Battery Power", " W")
    print("\n  --- Memory ---")
    _stat(["ram", "RAM"], "RAM", " MB")
    _stat(["vram", "VRAM"], "VRAM", " MB")
    _stat(["swap"], "Swap", " MB")

    # FPS stability
    fk = _fcol(cols, ["fps", "FPS"])
    if fk:
        fv = [sf(r.get(fk, "0")) for r in rows]
        avg = sum(fv) / len(fv) if fv else 0
        if avg > 0:
            stab = (1 - (sum((v - avg) ** 2 for v in fv) / len(fv)) ** 0.5 / avg) * 100
            print(f"\n  FPS Stability : {max(0,stab):.1f}%  (100%=perfectly stable)")

    ftk = _fcol(cols, ["frametime", "frametime_ms", "Frametime"])
    if ftk:
        tv = sorted([sf(r.get(ftk, "0")) for r in rows])
        if tv:
            p99 = pctl(tv, 99)
            p1 = pctl(tv, 1)
            jitter = p99 - p1
            print(f"  Frametime Jitter (P99-P1): {jitter:.2f} ms")

    # Web viewer info
    print("\n  --- Upload to Web Viewers ---")
    print(f"  Log file for upload: {path}")
    for v in WEB_VIEWERS:
        print(f"    * {v['name']}: {v['url']}")
        print(f"      {v['note']}")
    print("=" * 72)
    print()


def cmd_games(args: argparse.Namespace) -> int:
    """List unique game names discovered from MangoHud log filenames."""
    d = pathlib.Path(args.log_dir) if args.log_dir else None
    names = discover_games(d)
    if not names:
        print("  No MangoHud logs found.")
        print(f"    Searched: {MANGOHUD_LOG_DIR}, {MANGOHUD_ALT_LOG}")
        return 1
    print(f"  Games found in MangoHud logs ({len(names)}):\n")
    for n in names:
        count = len(find_logs(d, game=n))
        print(f"    {n:30s}  ({count} log{'s' if count != 1 else ''})")
    print("\n  Use --game NAME with configure/graph/summary to target a specific game.")
    return 0


def cmd_summary(args: argparse.Namespace) -> int:
    game = getattr(args, "game", None)
    paths: List[pathlib.Path] = []
    if args.input:
        for p in args.input:
            pp = pathlib.Path(p)
            if pp.is_file():
                paths.append(pp)
            elif pp.is_dir():
                paths.extend(find_logs(pp, game=game))
            else:
                log.warning("Not found: %s", pp)
    else:
        if game:
            paths = find_logs(game=game)
        else:
            nl = newest_log()
            if nl:
                paths.append(nl)
    if not paths:
        log.error(
            "No log files found.%s", f" (filtered by game '{game}')" if game else ""
        )
        return 1
    for p in paths:
        _print_summary(p)
    if args.json_output:
        _write_json_summary(paths, pathlib.Path(args.json_output))
    return 0


# -- organize ---------------------------------------------------------------


def _extract_game_name(stem: str) -> str:
    """Extract game name from MangoHud log filename stem."""
    m = re.match(r"^(.+?)_\d{4}[-_]", stem)
    name = m.group(1) if m else stem
    # Strip Windows .exe suffix common in Proton game logs
    if name.lower().endswith(".exe"):
        name = name[:-4]
    return name


def _rotate_game_logs(game_dir: pathlib.Path, max_logs: int = MAX_LOGS_PER_GAME) -> int:
    """Delete oldest logs if game folder exceeds max_logs. Returns deleted count."""
    csvs = sorted(game_dir.glob("*.csv"), key=lambda p: p.stat().st_mtime)
    removed = 0
    while len(csvs) > max_logs:
        oldest = csvs.pop(0)
        oldest.unlink()
        removed += 1
        log.info("Rotated (deleted): %s", oldest)
    return removed


def cmd_organize(args: argparse.Namespace) -> int:
    """Sort MangoHud logs into per-game/date folders with rotation.

    Layout created:
        ~/Documents/MangoBench_Logs/
          <GameName>/
            <GameName>_YYYY-MM-DD_HH-MM-SS.csv
            current.csv  -> symlink to today's newest log
    """
    src_dir = pathlib.Path(args.source) if args.source else None
    dest = pathlib.Path(args.dest) if args.dest else BENCH_LOG_DIR
    max_logs = args.max_logs
    dry = args.dry_run

    raw_logs = [
        p for p in find_logs(src_dir)
        if not p.name.endswith("_summary.csv")
        and not p.name.endswith("-current-mangohud.csv")
    ]

    dest.mkdir(parents=True, exist_ok=True)
    dest_has_games = dest.exists() and any(p.is_dir() for p in dest.iterdir())

    if not raw_logs and not dest_has_games:
        print("  No MangoHud CSV logs found to organize.")
        print(f"    Searched: {MANGOHUD_LOG_DIR}, {MANGOHUD_ALT_LOG}")
        return 1
    moved = 0
    rotated = 0
    skipped = 0
    deleted = 0
    today = datetime.date.today().isoformat()
    originals_to_delete: List[pathlib.Path] = []

    for src in raw_logs:
        game = _extract_game_name(src.stem)
        game_dir = dest / game
        target = game_dir / src.name

        if target.exists():
            skipped += 1
            originals_to_delete.append(src)
            continue

        if dry:
            print(f"    [dry-run] {src.name} -> {game_dir}/")
            moved += 1
            continue

        game_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(src), str(target))
        moved += 1
        originals_to_delete.append(src)
        log.info("Copied: %s -> %s", src, target)

    # Delete originals from source directory after successful copy
    if not dry:
        for src in originals_to_delete:
            try:
                src.unlink()
                deleted += 1
                log.info("Deleted original: %s", src)
            except OSError as e:
                log.warning("Could not delete %s: %s", src, e)

    # Rotation + current symlinks
    if not dry:
        for game_dir in sorted(dest.iterdir()):
            if not game_dir.is_dir():
                continue
            rotated += _rotate_game_logs(game_dir, max_logs)

            # Update current symlink -> today's newest real CSV (not summary/current)
            day_logs = sorted(
                [
                    f
                    for f in game_dir.glob("*.csv")
                    if today in f.name
                    and not f.name.endswith("_summary.csv")
                    and not f.name.endswith("-current-mangohud.csv")
                    and f.name != "current.csv"
                ],
                key=lambda p: p.stat().st_mtime,
            )
            game_name = game_dir.name
            current_name = f"{game_name}-current-mangohud.csv"
            current_link = game_dir / current_name
            non_link_csvs = [
                f
                for f in game_dir.glob("*.csv")
                if not f.name.endswith("-current-mangohud.csv")
                and not f.name.endswith("_summary.csv")
                and f.name != "current.csv"
            ]
            if day_logs:
                if current_link.is_symlink() or current_link.exists():
                    current_link.unlink()
                current_link.symlink_to(day_logs[-1].name)
                log.info("%s -> %s", current_name, day_logs[-1].name)
            elif not current_link.exists():
                all_csvs = sorted(non_link_csvs, key=lambda p: p.stat().st_mtime)
                if all_csvs:
                    current_link.symlink_to(all_csvs[-1].name)

    print(f"  Organize complete: {dest}")
    print(f"    Copied  : {moved} log(s)")
    print(f"    Skipped : {skipped} (already exist)")
    print(f"    Deleted : {deleted} original(s) from source")
    print(f"    Rotated : {rotated} old log(s) deleted (max {max_logs}/game)")

    # Show tree
    for game_dir in sorted(dest.iterdir()):
        if not game_dir.is_dir():
            continue
        csvs = sorted(game_dir.glob("*.csv"))
        gn = game_dir.name
        real_csvs = [c for c in csvs if not c.name.endswith("-current-mangohud.csv")]
        cur = game_dir / f"{gn}-current-mangohud.csv"
        cur_target = cur.resolve().name if cur.is_symlink() else "none"
        print(f"    {game_dir.name}/  ({len(real_csvs)} logs, current -> {cur_target})")
    return 0


# -- bundle -----------------------------------------------------------------


def cmd_bundle(args: argparse.Namespace) -> int:
    """Create a zip of selected logs for upload to FlightlessSomething.

    FlightlessSomething accepts multiple CSV uploads per Benchmark.
    Each CSV becomes a separate "Run" displayed side-by-side.
    """
    import zipfile

    game = getattr(args, "game", None)
    src_dir = pathlib.Path(args.source) if args.source else BENCH_LOG_DIR
    out = pathlib.Path(args.output) if args.output else None

    # Collect CSVs
    csvs: List[pathlib.Path] = []
    if game:
        game_dir = src_dir / game
        if game_dir.is_dir():
            csvs = sorted(
                [f for f in game_dir.glob("*.csv") if f.name != "current.csv"],
                key=lambda p: p.stat().st_mtime,
            )
        else:
            # Fallback: search flat dir
            csvs = find_logs(src_dir, game=game)
    else:
        # All games  pick the "current.csv" or newest from each game folder
        if src_dir.is_dir():
            for gd in sorted(src_dir.iterdir()):
                if not gd.is_dir():
                    continue
                cur = gd / "current.csv"
                if cur.is_symlink() or cur.exists():
                    csvs.append(cur.resolve())
                else:
                    latest = sorted(
                        [f for f in gd.glob("*.csv")], key=lambda p: p.stat().st_mtime
                    )
                    if latest:
                        csvs.append(latest[-1])

    if not csvs:
        print("  No logs found to bundle.")
        print(f"    Source: {src_dir}")
        if game:
            print(f"    Game filter: {game}")
        print(f"\n    Run '{PROG_NAME} organize' first to sort logs into game folders.")
        return 1

    # Limit
    limit = args.limit
    if limit and len(csvs) > limit:
        csvs = csvs[-limit:]

    # Determine output path
    if not out:
        tag = game if game else "all-games"
        ts = datetime.datetime.now().strftime("%Y%m%d_%H%M")
        out = src_dir / f"benchmark_{tag}_{ts}.zip"

    out.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(str(out), "w", zipfile.ZIP_DEFLATED) as zf:
        for csv in csvs:
            zf.write(str(csv), csv.name)

    total_kb = sum(c.stat().st_size for c in csvs) / 1024
    zip_kb = out.stat().st_size / 1024

    print(f"  Bundle created: {out}")
    print(
        f"    Files : {len(csvs)} CSV(s) ({total_kb:.0f} KB -> {zip_kb:.0f} KB zipped)"
    )
    print("    Upload to FlightlessSomething:")
    print(f"      {FLIGHTLESS_URL}")
    print("      Select all CSVs from the zip (or upload the individual files).")
    print("\n    Included logs:")
    for c in csvs:
        print(f"      {c.name}  ({c.stat().st_size/1024:.1f} KB)")
    return 0


# -- upload -----------------------------------------------------------------


def _is_real_csv(p: pathlib.Path) -> bool:
    """Exclude summary/current helper files; keep only raw MangoHud logs."""
    return (
        not p.name.endswith("-current-mangohud.csv")
        and not p.name.endswith("_summary.csv")
        and p.name != "current.csv"
    )


def _tui_file_picker(
    root: pathlib.Path,
    already_uploaded: Optional[set] = None,
    force: bool = False,
) -> Optional[List[pathlib.Path]]:
    """Curses-based file picker with checkbox selection and folder navigation.

    Returns selected files, or None if the user cancelled (ESC).
    Falls back to None on non-TTY / curses failure so caller can use text picker.
    already_uploaded: set of file stems already in this benchmark.
    """
    import curses as _curses

    already = already_uploaded or set()
    selected: set = set()
    result: Optional[List[pathlib.Path]] = [None]  # mutable container for wrapper

    def _dir_files(d: pathlib.Path) -> List[pathlib.Path]:
        try:
            return sorted(
                [f for f in d.iterdir() if f.is_file() and _is_real_csv(f)],
                key=lambda p: p.name,
            )
        except OSError:
            return []

    def _dir_subdirs(d: pathlib.Path) -> List[pathlib.Path]:
        try:
            return sorted(
                [p for p in d.iterdir() if p.is_dir()
                 and any(_is_real_csv(f) for f in p.iterdir() if f.is_file())],
                key=lambda p: p.name,
            )
        except OSError:
            return []

    def _build_items(d: pathlib.Path) -> list:
        return _dir_subdirs(d) + _dir_files(d)

    def _run(stdscr) -> None:
        _curses.curs_set(0)
        try:
            _curses.use_default_colors()
            _curses.init_pair(1, _curses.COLOR_CYAN, -1)    # dirs / header
            _curses.init_pair(2, _curses.COLOR_GREEN, -1)   # selected files
            _curses.init_pair(3, _curses.COLOR_YELLOW, -1)  # already-uploaded
            _curses.init_pair(4, -1, _curses.COLOR_BLUE)    # cursor row
        except Exception:
            pass

        nav_stack: list = []  # each entry: (dir, items, cursor, scroll)
        cur_dir = root
        items = _build_items(root)
        cursor = 0
        scroll = 0

        while True:
            h, w = stdscr.getmaxyx()
            stdscr.erase()

            # display list: None = ".." back entry, then items
            display: list = ([None] if nav_stack else []) + items
            cursor = max(0, min(cursor, len(display) - 1))

            # scroll so cursor stays visible (header=2, footer=2, preview=1)
            list_h = max(1, h - 5)
            if cursor >= scroll + list_h:
                scroll = cursor - list_h + 1
            if cursor < scroll:
                scroll = cursor

            # ── header ──────────────────────────────────────────────────
            rel = str(cur_dir).replace(str(pathlib.Path.home()), "~")
            n_sel = len(selected)
            right = f" [{n_sel} selected] "
            left = f" {rel}/ "
            pad = max(0, w - 1 - len(left) - len(right))
            try:
                stdscr.addstr(0, 0, (left + " " * pad + right)[:w - 1], _curses.A_BOLD)
                stdscr.addstr(1, 0, "─" * (w - 1))
            except _curses.error:
                pass

            # ── item rows ───────────────────────────────────────────────
            for row in range(list_h):
                idx = scroll + row
                if idx >= len(display):
                    break
                y = row + 2
                item = display[idx]
                is_cur = idx == cursor

                if item is None:
                    line = "  [↑] .."
                    attr = _curses.color_pair(1)
                elif item.is_dir():
                    files = _dir_files(item)
                    n = len(files)
                    n_s = sum(1 for f in files if f in selected)
                    box = "[*]" if (n_s == n and n > 0) else ("[-]" if n_s > 0 else "[ ]")
                    line = f"  {box} {item.name}/  ({n} file{'s' if n != 1 else ''})"
                    attr = _curses.color_pair(1)
                else:
                    is_sel = item in selected
                    is_old = item.stem in already
                    box = "[*]" if is_sel else "[ ]"
                    kb = item.stat().st_size / 1024
                    tag = "  ↑" if is_old else ""
                    line = f"  {box} {item.name}  ({kb:.1f} KB){tag}"
                    attr = (
                        _curses.color_pair(2) if is_sel
                        else _curses.color_pair(3) if is_old
                        else 0
                    )

                try:
                    if is_cur:
                        padded = (line + " " * w)[:w - 1]
                        stdscr.addstr(y, 0, padded, _curses.color_pair(4) | _curses.A_BOLD)
                    else:
                        stdscr.addstr(y, 0, line[:w - 1], attr)
                except _curses.error:
                    pass

            # ── title preview (above footer) ────────────────────────────
            if selected and already is None:  # new benchmark mode
                game_names = sorted({
                    _extract_game_name(c.parent.name) if c.parent != root
                    else _extract_game_name(c.stem)
                    for c in selected
                })
                preview = " Benchmark title: " + (", ".join(game_names) or "(unknown)") + " "
            elif selected and already is not None:
                preview = f" Appending {len(selected)} run(s) to existing benchmark "
            else:
                preview = " (no files selected) "
            try:
                stdscr.addstr(h - 2, 0, preview[:w - 1], _curses.A_BOLD)
            except _curses.error:
                pass

            # ── footer ──────────────────────────────────────────────────
            footer = " ↑↓:move  SPC:toggle  ENTER:open folder  ←/BKSP:back  u:upload  ESC:cancel "
            try:
                stdscr.addstr(h - 1, 0, footer[:w - 1], _curses.A_DIM)
            except _curses.error:
                pass

            stdscr.refresh()

            # ── input ───────────────────────────────────────────────────
            key = stdscr.getch()

            if key == _curses.KEY_UP:
                cursor = max(0, cursor - 1)
            elif key == _curses.KEY_DOWN:
                cursor = min(len(display) - 1, cursor + 1)
            elif key in (_curses.KEY_BACKSPACE, 127, _curses.KEY_LEFT):
                if nav_stack:
                    cur_dir, items, cursor, scroll = nav_stack.pop()
            elif key == 27:  # ESC → cancel
                result[0] = None
                return
            elif key == ord('u'):  # u → confirm/upload
                sel = list(selected)
                if already and not force:
                    sel = [p for p in sel if p.stem not in already]
                result[0] = sel
                return
            elif key in (10, 13, ord(' ')):  # ENTER or SPACE
                if not display:
                    continue
                item = display[cursor]
                if item is None:
                    if nav_stack:
                        cur_dir, items, cursor, scroll = nav_stack.pop()
                elif item.is_dir():
                    if key in (10, 13):  # ENTER → drill in
                        nav_stack.append((cur_dir, items, cursor, scroll))
                        cur_dir = item
                        items = _build_items(item)
                        cursor = 0
                        scroll = 0
                    else:  # SPACE → toggle all files in dir
                        files = _dir_files(item)
                        if files and all(f in selected for f in files):
                            for f in files:
                                selected.discard(f)
                        else:
                            for f in files:
                                selected.add(f)
                else:
                    if item in selected:
                        selected.discard(item)
                    else:
                        selected.add(item)

    if not sys.stdout.isatty():
        return None
    try:
        _curses.wrapper(_run)
    except Exception as exc:
        log.debug("TUI picker error: %s", exc)
        return None
    return result[0]


def _collect_csvs_for_upload(args: argparse.Namespace) -> List[pathlib.Path]:
    """Collect CSV files based on --game, --input, or organized folders."""
    game = getattr(args, "game", None)
    src_dir = pathlib.Path(args.source) if args.source else BENCH_LOG_DIR
    inputs = getattr(args, "input", None)

    csvs: List[pathlib.Path] = []

    # Explicit input files
    if inputs:
        for p in inputs:
            pp = pathlib.Path(p)
            if pp.is_file() and pp.suffix == ".csv":
                csvs.append(pp)
            elif pp.is_dir():
                csvs.extend(sorted(pp.glob("*.csv")))
        return csvs

    # Game-specific
    if game:
        game_dir = src_dir / game
        if game_dir.is_dir():
            csvs = sorted(
                [f for f in game_dir.glob("*.csv") if _is_real_csv(f)],
                key=lambda p: p.stat().st_mtime,
            )
        else:
            csvs = [f for f in find_logs(src_dir, game=game) if _is_real_csv(f)]
    else:
        # All games: pick *-current-mangohud.csv symlink target or newest real CSV
        if src_dir.is_dir():
            for gd in sorted(src_dir.iterdir()):
                if not gd.is_dir():
                    continue
                gn = gd.name
                cur = gd / f"{gn}-current-mangohud.csv"
                if not cur.exists():
                    cur = gd / "current.csv"
                if cur.is_symlink() or cur.exists():
                    resolved = cur.resolve()
                    if resolved.exists() and _is_real_csv(resolved):
                        csvs.append(resolved)
                else:
                    real = sorted(
                        [f for f in gd.glob("*.csv") if _is_real_csv(f)],
                        key=lambda p: p.stat().st_mtime,
                    )
                    if real:
                        csvs.append(real[-1])
    return csvs


def _load_token_file() -> Optional[str]:
    """Read API token from ~/.flightless-token, enforcing mode 600.

    Returns the token string, or None if the file doesn't exist.
    Exits with an error message if the file exists but has wrong permissions.
    """
    p = FLIGHTLESS_TOKEN_FILE
    if not p.exists():
        return None
    mode = p.stat().st_mode & 0o777
    if mode != 0o600:
        log.error(
            "%s has permissions %04o -- must be 600.\n"
            "  Fix with: chmod 600 %s",
            p, mode, p,
        )
        sys.exit(1)
    token = p.read_text(encoding="utf-8").strip()
    if not token:
        log.error("%s is empty.", p)
        sys.exit(1)
    return token


def _prompt_and_save_token() -> str:
    """Interactively prompt for a FlightlessSomething API token.

    Masks input with '*' as the user types or pastes.  On success writes
    the token to ~/.flightless-token with mode 600 so future runs pick it
    up automatically without any flags or env vars.
    """
    import termios
    import tty

    if not sys.stdin.isatty():
        log.error(
            "No API token found and stdin is not a terminal.\n"
            "  Set FLIGHTLESS_TOKEN env var or create %s (mode 600).",
            FLIGHTLESS_TOKEN_FILE,
        )
        sys.exit(1)

    print()
    print("  No FlightlessSomething API token found.")
    print(f"  Get one at: {FLIGHTLESS_BASE}/api-tokens")
    print()
    print(f"  Token will be saved to {FLIGHTLESS_TOKEN_FILE} (mode 600).")
    print("  Paste your API token then press Enter:")
    print("  > ", end="", flush=True)

    token_chars: List[str] = []
    fd = sys.stdin.fileno()
    old = termios.tcgetattr(fd)
    try:
        tty.cbreak(fd)
        while True:
            ch = sys.stdin.read(1)
            if ch in ("\n", "\r"):
                break
            elif ch in ("\x7f", "\x08"):  # backspace / delete
                if token_chars:
                    token_chars.pop()
                    sys.stdout.write("\b \b")
                    sys.stdout.flush()
            elif ch == "\x03":  # Ctrl-C
                raise KeyboardInterrupt
            elif ch == "\x04":  # Ctrl-D
                break
            else:
                token_chars.append(ch)
                sys.stdout.write("*")
                sys.stdout.flush()
    finally:
        termios.tcsetattr(fd, termios.TCSADRAIN, old)

    print()  # newline after masked input

    token = "".join(token_chars).strip()
    if not token:
        log.error("No token entered.")
        sys.exit(1)

    FLIGHTLESS_TOKEN_FILE.write_text(token + "\n", encoding="utf-8")
    FLIGHTLESS_TOKEN_FILE.chmod(0o600)
    print(f"  Token saved to {FLIGHTLESS_TOKEN_FILE}")
    print()
    return token


def _fetch_current_user_id(token: str, base_url: str) -> Optional[int]:
    """Return the authenticated user's ID from /api/tokens."""
    import urllib.request

    print(f"  Authenticating with {base_url} ...", end="", flush=True)
    req = urllib.request.Request(
        f"{base_url}/api/tokens",
        headers={"Authorization": f"Bearer {token}"},
    )
    try:
        data = json.loads(urllib.request.urlopen(req).read().decode("utf-8", errors="replace"))
        if isinstance(data, list) and data:
            uid = data[0].get("UserID") or data[0].get("user_id")
            print(f" OK (user ID {uid})")
            return uid
        print(" OK (no tokens returned)")
        return None
    except Exception as exc:
        print(f" FAILED")
        log.warning("Could not fetch current user ID: %s", exc)
        return None


def _fetch_benchmarks(
    token: str, base_url: str, per_page: int = 50
) -> List[Dict[str, Any]]:
    """Return all benchmarks belonging to the authenticated user."""
    import urllib.request

    user_id = _fetch_current_user_id(token, base_url)

    all_benchmarks: List[Dict[str, Any]] = []
    page = 1
    # Try filtering server-side by user_id first (avoids paginating all public benchmarks)
    user_filter = f"&user_id={user_id}" if user_id else ""
    while True:
        url = f"{base_url}/api/benchmarks?per_page={per_page}&page={page}{user_filter}"
        print(f"  Fetching benchmarks (page {page}) ...", end="", flush=True)
        req = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {token}"}
        )
        try:
            data = json.loads(urllib.request.urlopen(req).read().decode("utf-8", errors="replace"))
        except Exception as exc:
            print(" FAILED")
            log.error("Failed to fetch benchmark list: %s", exc)
            break

        benchmarks = data.get("benchmarks") or []
        if not benchmarks:
            print(" done")
            break

        matched = [
            b for b in benchmarks
            if user_id is None or (b.get("UserID") or b.get("user_id")) == user_id
        ]
        all_benchmarks.extend(matched)
        total_pages = data.get("total_pages", 1)
        print(f" {len(matched)} matched (total so far: {len(all_benchmarks)})")

        if page >= total_pages:
            break
        # If server-side filter isn't supported and we got a full page with
        # zero matches, the results are sorted by newest-first so our benchmarks
        # would appear early — stop after two empty pages to avoid scanning all.
        if not user_filter and len(matched) == 0 and page >= 2:
            log.debug("No matches on consecutive pages, stopping early.")
            break
        page += 1

    return all_benchmarks


_UPLOAD_HISTORY_FILE = (
    pathlib.Path.home() / ".local" / "share" / "mango-hud-profiler" / "uploads.json"
)


def _load_upload_history() -> Dict[str, List[str]]:
    """Return {benchmark_id: [filename, ...]} of previously uploaded files."""
    if not _UPLOAD_HISTORY_FILE.exists():
        return {}
    try:
        return json.loads(_UPLOAD_HISTORY_FILE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def _save_upload_history(history: Dict[str, List[str]]) -> None:
    _UPLOAD_HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    _UPLOAD_HISTORY_FILE.write_text(
        json.dumps(history, indent=2), encoding="utf-8"
    )


def _mark_uploaded(benchmark_id: str, filenames: List[str]) -> None:
    history = _load_upload_history()
    existing = set(history.get(benchmark_id, []))
    existing.update(filenames)
    history[benchmark_id] = sorted(existing)
    _save_upload_history(history)


def _fetch_benchmark_run_names(token: str, base_url: str, benchmark_id: str) -> Optional[set]:
    """Return set of filenames already in the benchmark from the API, or None on error."""
    import urllib.request

    url = f"{base_url}/api/benchmarks/{benchmark_id}"
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    try:
        data = json.loads(urllib.request.urlopen(req).read().decode("utf-8", errors="replace"))
        # API returns run_labels as a list of name strings (no extension)
        labels = data.get("run_labels") or []
        return set(labels)
    except Exception as exc:
        log.debug("Could not fetch benchmark runs from API: %s", exc)
        return None


def _pick_csvs(
    csvs: List[pathlib.Path],
    already: Optional[set] = None,
    force: bool = False,
) -> List[pathlib.Path]:
    """Interactive CSV picker. already = set of stems already uploaded (optional)."""

    def _is_already(p: pathlib.Path) -> bool:
        return already is not None and p.stem in already

    print()
    print("  Available CSVs (* = already uploaded):")
    print()
    for i, p in enumerate(csvs, 1):
        marker = "* " if _is_already(p) else "  "
        print(f"    {i:>3}.  {marker}{p.name}  ({p.stat().st_size/1024:.1f} KB)")
    print()

    if already is not None:
        unuploaded = [p for p in csvs if not _is_already(p)]
        default_label = f"all {len(unuploaded)} not yet uploaded" if unuploaded else "none (all already uploaded)"
    else:
        unuploaded = csvs
        default_label = f"all {len(csvs)}"

    print(f"  Select CSVs to upload (e.g. 1,3 or 1-3), or ENTER for {default_label}:")

    while True:
        try:
            raw = input("  > ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return []
        if not raw:
            return unuploaded

        selected: List[pathlib.Path] = []
        valid = True
        for part in raw.replace(" ", "").split(","):
            if "-" in part:
                lo_s, _, hi_s = part.partition("-")
                if lo_s.isdigit() and hi_s.isdigit():
                    lo, hi = int(lo_s) - 1, int(hi_s) - 1
                    if 0 <= lo <= hi < len(csvs):
                        selected.extend(csvs[lo : hi + 1])
                        continue
                valid = False
                break
            elif part.isdigit():
                idx = int(part) - 1
                if 0 <= idx < len(csvs):
                    selected.append(csvs[idx])
                    continue
                valid = False
                break
            else:
                valid = False
                break

        if valid and selected:
            dupes = [p for p in selected if _is_already(p)]
            if dupes and not force:
                print(f"  Already uploaded: {', '.join(p.name for p in dupes)}")
                print("  Use --force to re-upload existing runs.")
                continue
            return selected
        print(f"  Enter numbers between 1 and {len(csvs)}, e.g. 1,2 or 1-3.")



def _select_benchmark(
    benchmarks: List[Dict[str, Any]],
) -> Optional[Dict[str, Any]]:
    """Display a numbered benchmark list and prompt the user to pick one."""
    if not benchmarks:
        print("  No benchmarks found in your account.")
        return None

    print()
    print("  Your benchmarks:")
    print()
    for i, b in enumerate(benchmarks, 1):
        runs = b.get("run_count", "?")
        ts = (b.get("CreatedAt") or b.get("created_at") or "")[:10]
        title = b.get("Title") or b.get("title") or "(untitled)"
        bid = b.get("ID") or b.get("id")
        print(f"    {i:>3}.  {title}  [{runs} run(s), {ts}]  (id:{bid})")
    print()

    while True:
        try:
            raw = input(f"  Select benchmark to append to [1-{len(benchmarks)}]: ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            return None
        if not raw:
            return None
        if raw.isdigit():
            idx = int(raw) - 1
            if 0 <= idx < len(benchmarks):
                return benchmarks[idx]
        print(f"  Enter a number between 1 and {len(benchmarks)}.")


def cmd_upload(args: argparse.Namespace) -> int:
    """Upload MangoHud CSV logs to FlightlessSomething via their API.

    API: POST /api/benchmarks  (multipart/form-data)
    Auth: Authorization: Bearer <api_token>
    Fields: title, description, files (multiple)
    """
    import urllib.error
    import urllib.request

    token = args.token or os.environ.get("FLIGHTLESS_TOKEN", "")
    if token:
        print("  Token: from argument/environment")
    else:
        token = _load_token_file()
        if token:
            print(f"  Token: loaded from {FLIGHTLESS_TOKEN_FILE}")
        else:
            token = _prompt_and_save_token()
    if not token:
        log.error("No API token available.")
        return 1

    base_url = args.url or FLIGHTLESS_BASE
    append_mode = getattr(args, "append", False)

    # ── Append mode: pick an existing benchmark ────────────────────────
    benchmarks = _fetch_benchmarks(token, base_url)
    append_benchmark: Optional[Dict[str, Any]] = None
    if append_mode:
        append_benchmark = _select_benchmark(benchmarks)
        if not append_benchmark:
            print("  No benchmark selected. Cancelled.")
            return 0
        bid = append_benchmark.get("ID") or append_benchmark.get("id")
        endpoint = f"{base_url}/api/benchmarks/{bid}/runs"
    else:
        endpoint = f"{base_url}/api/benchmarks"

    force = getattr(args, "force", False)
    src_dir = pathlib.Path(args.source) if args.source else BENCH_LOG_DIR
    inputs = getattr(args, "input", None)

    # Resolve already-uploaded set for append mode
    already_set: Optional[set] = None
    if append_mode and append_benchmark:
        bid_str = str(append_benchmark.get("ID") or append_benchmark.get("id"))
        print(f"  Checking existing runs in benchmark {bid_str} ...", end="", flush=True)
        api_names = _fetch_benchmark_run_names(token, base_url, bid_str)
        if api_names is not None:
            print(f" {len(api_names)} run(s) found")
            already_set = {pathlib.Path(n).stem for n in api_names}
            _mark_uploaded(bid_str, list(api_names))
        else:
            print(" (API unavailable, using local history)")
            history = _load_upload_history()
            already_set = {pathlib.Path(n).stem for n in history.get(bid_str, [])}

    # File picker: TUI when no explicit --input, else text picker
    if inputs:
        # Explicit files given — collect them and use text picker
        csvs = _collect_csvs_for_upload(args)
        if not csvs:
            print("  No CSV files found to upload.")
            return 1
        csvs = _pick_csvs(csvs, already=already_set, force=force) or []
    else:
        # TUI folder browser, falling back to text picker
        tui_result = _tui_file_picker(src_dir, already_uploaded=already_set, force=force)
        if tui_result is None:
            # TUI cancelled or unavailable — fall back to text picker on collected CSVs
            csvs = _collect_csvs_for_upload(args)
            if not csvs:
                print("  No CSV files found to upload.")
                print(f"  Run '{PROG_NAME} organize' first, or specify --input files.")
                return 1
            csvs = _pick_csvs(csvs, already=already_set, force=force) or []
        else:
            csvs = tui_result

    limit = args.limit
    if limit and len(csvs) > limit:
        csvs = csvs[-limit:]

    if not csvs:
        print("  No files selected. Cancelled.")
        return 0

    game = getattr(args, "game", None)

    print()
    if append_benchmark:
        bid = append_benchmark.get("ID") or append_benchmark.get("id")
        btitle = append_benchmark.get("Title") or append_benchmark.get("title") or "(untitled)"
        print(f"  Appending runs to: \"{btitle}\"")
        print(f"    Benchmark ID : {bid}")
        print(f"    URL          : {base_url}/benchmarks/{bid}")
    else:
        if args.title:
            title = args.title
        else:
            # Derive title from the selected files' parent folder name(s)
            game_names = sorted({
                _extract_game_name(c.parent.name) if c.parent != src_dir else _extract_game_name(c.stem)
                for c in csvs
            })
            title = ", ".join(game_names) if game_names else (game or "All Games")
        description = args.description or f"Uploaded via {PROG_NAME} v{VERSION} (SteamOS-Tools)"
        # Check for title conflict before prompting
        existing_titles = {
            (b.get("Title") or b.get("title") or "").strip().lower()
            for b in benchmarks
        }
        if title.strip().lower() in existing_titles:
            if not force:
                log.error(
                    "Benchmark \"%s\" already exists. Use --force to append the date and create new.",
                    title,
                )
                return 1
            log.warning("Benchmark \"%s\" already exists.", title)
            title = f"{title} - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"
            print(f"  Benchmark title (date appended): {title}")
        elif not args.yes and not args.title:
            try:
                edit = input(f"\n  Benchmark title: {title}\n  Edit title? [y/N] ").strip().lower()
                if edit in ("y", "yes"):
                    new_title = input("  Title: ").strip()
                    if new_title:
                        title = new_title
            except (EOFError, KeyboardInterrupt):
                print("\n  Cancelled.")
                return 0
        print("  Uploading to FlightlessSomething:")
        print(f"    Title    : {title}")

    print(f"    Files    : {len(csvs)} CSV(s)")
    for c in csvs:
        print(f"      {c.name}  ({c.stat().st_size/1024:.1f} KB)")

    if not args.yes:
        action = "Append runs?" if append_benchmark else "Create new benchmark?"
        try:
            answer = input(f"\n  {action} [y/N] ").strip().lower()
            if answer not in ("y", "yes"):
                print("  Cancelled.")
                return 0
        except (EOFError, KeyboardInterrupt):
            print("\n  Cancelled.")
            return 0

    # Build multipart form data
    boundary = f"----MHPBoundary{int(time.time()*1000)}"
    body_parts: List[bytes] = []

    def _add_field(name: str, value: str) -> None:
        body_parts.append(f"--{boundary}\r\n".encode())
        body_parts.append(
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode()
        )
        body_parts.append(f"{value}\r\n".encode())

    def _add_file(filepath: pathlib.Path) -> None:
        body_parts.append(f"--{boundary}\r\n".encode())
        body_parts.append(
            f'Content-Disposition: form-data; name="files"; filename="{filepath.name}"\r\n'.encode()
        )
        body_parts.append(b"Content-Type: text/csv\r\n\r\n")
        # Normalize to 3-line spec format so FlightlessSomething can parse it.
        # MangoHud 0.8+ writes preamble lines (v1, version, --- separators)
        # that the upload parser doesn't handle.
        body_parts.append(_normalize_csv_for_flightless(filepath).encode("utf-8"))
        body_parts.append(b"\r\n")

    if not append_benchmark:
        _add_field("title", title)
        _add_field("description", description)
    for csv_file in csvs:
        _add_file(csv_file)
    body_parts.append(f"--{boundary}--\r\n".encode())

    body = b"".join(body_parts)
    content_type = f"multipart/form-data; boundary={boundary}"

    req = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "Content-Type": content_type,
            "Authorization": f"Bearer {token}",
        },
    )

    print(f"\n  Uploading {len(csvs)} file(s) ...", end="", flush=True)
    log.info("POST %s (%d bytes, %d files)", endpoint, len(body), len(csvs))

    try:
        response = urllib.request.urlopen(req)
        status = response.status
        resp_body = response.read().decode("utf-8", errors="replace")
        print(f" HTTP {status}")
    except urllib.error.HTTPError as e:
        status = e.code
        try:
            resp_body = e.read().decode("utf-8", errors="replace")
        except OSError:
            resp_body = ""
        print(f" HTTP {status}")
        log.error("Upload failed: HTTP %d", status)
        if resp_body:
            log.error("Response: %s", resp_body[:500])
        return 1
    except urllib.error.URLError as e:
        log.error("Connection failed: %s", e.reason)
        return 1

    if status in (200, 201):
        data = {}
        try:
            data = json.loads(resp_body)
        except json.JSONDecodeError:
            pass

        print("\n  Success!")
        if append_benchmark:
            bid_str = str(append_benchmark.get("ID") or append_benchmark.get("id"))
            _mark_uploaded(bid_str, [c.name for c in csvs])
            runs_added = data.get("runs_added", len(csvs))
            total = data.get("total_run_count", "?")
            print(f"    Runs added   : {runs_added}")
            print(f"    Total runs   : {total}")
            print(f"    Benchmark URL: {base_url}/benchmarks/{bid}")
        else:
            benchmark_id = data.get("id")
            if benchmark_id:
                print(f"    Benchmark URL: {base_url}/benchmarks/{benchmark_id}")
            print(f"    {len(csvs)} CSV(s) uploaded as separate runs.")
        return 0
    else:
        log.warning("Unexpected status: HTTP %d", status)
        if resp_body:
            log.warning("Response: %s", resp_body[:300])
        return 1


def _write_json_summary(paths: List[pathlib.Path], out: pathlib.Path) -> None:
    results = []
    for path in paths:
        cols, rows = parse_csv(path)
        if not rows:
            continue
        entry: Dict[str, Any] = {"file": str(path), "samples": len(rows)}
        for cands, key in [
            (["fps", "FPS"], "fps"),
            (["frametime", "frametime_ms"], "frametime"),
            (["cpu_temp", "CPU_Temp"], "cpu_temp"),
            (["gpu_temp", "GPU_Temp"], "gpu_temp"),
            (["cpu_power", "CPU_Power"], "cpu_power"),
            (["gpu_power", "GPU_Power"], "gpu_power"),
            (["ram", "RAM"], "ram"),
            (["vram", "VRAM"], "vram"),
        ]:
            k = _fcol(cols, cands)
            if k:
                vs = sorted([sf(r.get(k, "0")) for r in rows])
                if vs and max(vs) > 0:
                    entry[key] = {
                        "avg": round(sum(vs) / len(vs), 2),
                        "min": round(vs[0], 2),
                        "max": round(vs[-1], 2),
                        "p1": round(pctl(vs, 1), 2),
                        "p99": round(pctl(vs, 99), 2),
                    }
        results.append(entry)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, indent=2), encoding="utf-8")
    print(f"  JSON summary written: {out}")


# -- test-config ------------------------------------------------------------


def cmd_test(args: argparse.Namespace) -> int:
    """Simulate the gamescope MANGOHUD_CONFIGFILE override and verify logging.

    Reproduces exactly what gamescope-session-plus does:
      1. Create a temp MANGOHUD_CONFIGFILE containing only "no_display"
      2. Set MANGOHUD_CONFIG from our environment.d file (or build it live)
      3. Run a short renderer session with autostart_log so a CSV is written
      4. Confirm the log appeared in output_folder

    This validates the fix for Bazzite where MANGOHUD_CONFIGFILE overrides
    MangoHud.conf/presets.conf and logging keys would otherwise be lost.
    """
    if not mangohud_installed():
        log.error("MangoHud not found in PATH.")
        return 1

    # Find a display -- try the gamescope X server first, then env
    display = os.environ.get("DISPLAY", "")
    if not display:
        for candidate in (":0", ":1"):
            xsock = pathlib.Path(f"/tmp/.X11-unix/X{candidate.lstrip(':')}")
            if xsock.exists():
                display = candidate
                break
    if not display:
        log.error(
            "No X display found. Run from within the gamescope session or set DISPLAY."
        )
        return 1

    # Prefer Vulkan apps -- they work with MANGOHUD=1 via the implicit layer.
    # glxgears is OpenGL and requires the mangohud wrapper to load the shim.
    renderer = None
    use_mangohud_wrapper = False
    for prog in ("vkcube", "vkcube-wayland"):
        if shutil.which(prog):
            renderer = prog
            break
    if not renderer and shutil.which("glxgears"):
        renderer = "glxgears"
        use_mangohud_wrapper = True  # OpenGL needs explicit mangohud preload
    if not renderer:
        log.error(
            "No test renderer found (tried: vkcube, glxgears). "
            "Install vulkan-tools or mesa-demos."
        )
        return 1

    log_dir = pathlib.Path(args.log_dir) if args.log_dir else MANGOHUD_LOG_DIR
    log_dir.mkdir(parents=True, exist_ok=True)

    # Build MANGOHUD_CONFIG: prefer the installed env.d file so we test the
    # real deployed value; fall back to constructing it from constants.
    if MANGOHUD_ENV_CONF.exists() and not args.live:
        raw = MANGOHUD_ENV_CONF.read_text(encoding="utf-8")
        mangohud_config = ""
        for line in raw.splitlines():
            line = line.strip()
            if line.startswith("MANGOHUD_CONFIG="):
                mangohud_config = line.split("=", 1)[1].strip().strip('"')
                break
        if not mangohud_config:
            log.warning("Could not parse MANGOHUD_CONFIG from %s", MANGOHUD_ENV_CONF)
    else:
        mangohud_config = None

    if not mangohud_config:
        # Build from constants (mirrors sync_gamescope_logging_env)
        logging_keys = {
            "output_folder": str(log_dir),
            "toggle_logging": "Shift_L+F2",
            "log_duration": "0",
            "log_interval": "100",
            "log_versioning": "1",
        }
        mangohud_config = ",".join(f"{k}={v}" for k, v in logging_keys.items())

    # Override output_folder with test log_dir and force autostart + short duration
    # so the test completes without user input.
    dur = args.duration
    parts = [p for p in mangohud_config.split(",") if not p.startswith("output_folder=")
             and not p.startswith("autostart_log=") and not p.startswith("log_duration=")]
    parts += [
        f"output_folder={log_dir}",
        "autostart_log=1",
        f"log_duration={dur}",
    ]
    mangohud_config = ",".join(parts)

    # Simulate gamescope: temp MANGOHUD_CONFIGFILE with just "no_display"
    import tempfile
    with tempfile.NamedTemporaryFile(
        prefix="mangohud.", dir="/tmp", mode="w", suffix="", delete=False
    ) as tf:
        tf.write("no_display\n")
        fake_configfile = tf.name

    print("  MangoHud logging test")
    cmd = (["mangohud", renderer] if use_mangohud_wrapper else [renderer])
    print(f"    Display         : {display}")
    print(f"    Renderer        : {' '.join(cmd)}")
    print(f"    Log dir         : {log_dir}")
    print(f"    Duration        : {dur}s")
    print(f"    Fake CONFIGFILE : {fake_configfile}  (no_display -- like gamescope)")
    print(f"    MANGOHUD_CONFIG : {mangohud_config}")
    print()

    env = dict(os.environ)
    env["DISPLAY"] = display
    env["MANGOHUD"] = "1"
    env["MANGOHUD_CONFIGFILE"] = fake_configfile
    env["MANGOHUD_CONFIG"] = mangohud_config

    before = set(find_logs(log_dir))
    try:
        proc = subprocess.Popen(
            cmd, env=env,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    except FileNotFoundError:
        log.error("Failed to launch %s", renderer)
        pathlib.Path(fake_configfile).unlink(missing_ok=True)
        return 1

    try:
        proc.wait(timeout=dur + 3)
    except subprocess.TimeoutExpired:
        proc.terminate()
        try:
            proc.wait(timeout=3)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()

    pathlib.Path(fake_configfile).unlink(missing_ok=True)
    time.sleep(0.5)

    new = sorted(set(find_logs(log_dir)) - before)
    if new:
        print("  PASS -- log file(s) created:")
        for f in new:
            _, rows = parse_csv(f)
            print(f"    {f}  ({f.stat().st_size / 1024:.1f} KB, {len(rows)} rows)")
        if not is_steamos():
            print("\n  Note: not a SteamOS/Bazzite system -- gamescope session fix")
            print("  not required, but the logging mechanism works correctly.")
        return 0
    else:
        print("  FAIL -- no log file appeared in:", log_dir)
        print("    Check that MangoHud is properly installed and DISPLAY is reachable.")
        if not MANGOHUD_ENV_CONF.exists():
            print(f"\n    {MANGOHUD_ENV_CONF} not found.")
            print("    Run: mango-hud-profiler configure --preset logging")
        return 1


# -- argparse ---------------------------------------------------------------


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog=PROG_NAME,
        description=(
            "MangoHud Performance Profiler for Bazzite / SteamOS.\n\n"
            "Configure MangoHud, launch profiling sessions, generate graphs\n"
            "from CSV logs, and produce summaries with web-viewer upload hints."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=textwrap.dedent(
            f"""\
            examples:
              {PROG_NAME} configure --preset logging
              {PROG_NAME} profile --duration 120 --command "gamescope -- %command%"
              {PROG_NAME} graph --input /tmp/MangoHud/MyGame.csv
              {PROG_NAME} summary --input /tmp/MangoHud/MyGame.csv

            web viewers (upload your CSV):
              FlightlessMango : https://flightlessmango.com/games/new
              CapFrameX       : https://www.capframex.com/analysis

            version: {VERSION}
        """
        ),
    )
    p.add_argument("-V", "--version", action="version", version=f"%(prog)s {VERSION}")
    p.add_argument(
        "-v",
        "--verbose",
        action="count",
        default=0,
        help="Increase verbosity (-v=INFO, -vv=DEBUG).",
    )
    p.add_argument(
        "--logfile", metavar="PATH", help="Also write log messages to this file."
    )
    sub = p.add_subparsers(
        dest="command",
        title="subcommands",
        description="Run '<subcommand> --help' for details.",
    )

    # -- configure --
    pc = sub.add_parser(
        "configure",
        help="Generate a MangoHud config file.",
        description=(
            "Generate or overwrite a MangoHud configuration file from a preset.\n"
            "Presets:\n"
            + "\n".join(
                f"  {k:10s} {v['description']}" for k, v in CONFIG_PRESETS.items()
            )
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pc.add_argument(
        "-p",
        "--preset",
        default="logging",
        choices=list(CONFIG_PRESETS.keys()),
        help="Config preset (default: logging).",
    )
    pc.add_argument(
        "-o",
        "--output",
        default=str(MANGOHUD_CONF_FILE),
        help=f"Output path (default: {MANGOHUD_CONF_FILE}).",
    )
    pc.add_argument(
        "--set",
        nargs="*",
        metavar="KEY=VAL",
        help="Override individual config keys (e.g. --set font_size=24 position=top-right).",
    )
    pc.add_argument(
        "--log-dir", metavar="DIR", help="Override the output_folder for CSV logs."
    )
    pc.add_argument(
        "-g",
        "--game",
        metavar="NAME",
        help="Generate a per-game config (writes to ~/.config/MangoHud/<NAME>.conf). "
        "MangoHud auto-applies it when the game executable matches NAME.",
    )
    pc.add_argument(
        "--check",
        action="store_true",
        help="Check existing config and add missing bottleneck/logging keys. "
        "Does not overwrite -- only appends missing keys.",
    )
    pc.add_argument(
        "-f", "--force", action="store_true", help="Overwrite existing config file."
    )
    pc.set_defaults(func=cmd_configure)

    # -- profile --
    pp = sub.add_parser(
        "profile",
        help="Run a timed profiling session (launch, log, stop).",
        description=(
            "Launch a command with MangoHud, wait for the specified duration\n"
            "(or until the process exits / Ctrl-C), then stop and report.\n"
            "Optionally auto-generates graphs and/or a summary."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pp.add_argument("-c", "--command", required=True, help="The command to profile.")
    pp.add_argument(
        "-d",
        "--duration",
        type=float,
        default=60,
        help="Duration in seconds (default: 60).",
    )
    pp.add_argument(
        "--log-dir", metavar="DIR", help="Override the MangoHud log output directory."
    )
    pp.add_argument("--config", metavar="PATH", help="Path to a MangoHud config file.")
    pp.add_argument(
        "--auto-summary",
        action="store_true",
        default=True,
        help="Print summary after profiling (default: on).",
    )
    pp.add_argument(
        "--no-auto-summary",
        dest="auto_summary",
        action="store_false",
        help="Skip automatic summary.",
    )
    pp.add_argument(
        "--auto-graph",
        action="store_true",
        default=False,
        help="Generate graphs after profiling.",
    )
    pp.add_argument(
        "--graph-output", metavar="DIR", help="Directory for auto-generated graphs."
    )
    pp.add_argument(
        "--graph-format",
        default="png",
        choices=["png", "svg", "pdf"],
        help="Graph image format (default: png).",
    )
    pp.set_defaults(func=cmd_profile)

    # -- graph --
    pg = sub.add_parser(
        "graph",
        help="Generate graphs from MangoHud CSV logs (mangoplot or matplotlib).",
        description=textwrap.dedent(
            """\
            Generate performance charts from MangoHud CSV logs.

            By default uses mangoplot (ships with MangoHud on Bazzite/SteamOS)
            for the best bottleneck analysis. Falls back to matplotlib if
            mangoplot is unavailable.

            Charts are saved to ~/mangohud-perf/<GAME>/charts/

            mangoplot provides: FPS, frametime, CPU/GPU load, core_load
            (single-core bottleneck detection), GPU clock graphs.

            Use --matplotlib to force matplotlib backend instead.
        """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pg.add_argument(
        "-i",
        "--input",
        metavar="CSV",
        help="Input CSV file (default: newest log in standard dirs).",
    )
    pg.add_argument(
        "-g",
        "--game",
        metavar="NAME",
        help="Filter: only use logs whose filename starts with NAME.",
    )
    pg.add_argument(
        "-o",
        "--output",
        metavar="DIR",
        help="Output directory for graphs (default: same as input).",
    )
    pg.add_argument(
        "-f",
        "--format",
        default="png",
        choices=["png", "svg", "pdf"],
        help="Image format (default: png).",
    )
    pg.add_argument("--dpi", type=int, default=150, help="Graph DPI (default: 150).")
    pg.add_argument(
        "--width", type=float, default=14.0, help="Graph width in inches (default: 14)."
    )
    pg.add_argument(
        "--height", type=float, default=6.0, help="Graph height in inches (default: 6)."
    )
    pg.add_argument(
        "--matplotlib",
        action="store_true",
        help="Force matplotlib backend even if mangoplot is available.",
    )
    pg.set_defaults(func=cmd_graph)

    # -- summary --
    pm = sub.add_parser(
        "summary",
        help="Print a summary of MangoHud log file(s).",
        description=(
            "Parse one or more MangoHud CSV logs and print a human-readable\n"
            "summary with statistics (avg, min, max, percentiles) for FPS,\n"
            "frametime, thermals, power, and memory.\n\n"
            "Also shows FPS stability score, frametime jitter, and lists\n"
            "web-based viewers where the CSV can be uploaded for interactive\n"
            "analysis."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pm.add_argument(
        "-i",
        "--input",
        nargs="*",
        metavar="PATH",
        help="CSV file(s) or directory. Default: newest log.",
    )
    pm.add_argument(
        "-g",
        "--game",
        metavar="NAME",
        help="Filter: only summarise logs whose filename starts with NAME.",
    )
    pm.add_argument(
        "--json-output",
        metavar="PATH",
        help="Also write a machine-readable JSON summary to this file.",
    )
    pm.set_defaults(func=cmd_summary)

    # -- games (list) --
    pl = sub.add_parser(
        "games",
        help="List game names found in MangoHud log files.",
        description=(
            "Scan the MangoHud log directory for CSV files and extract unique\n"
            "game names from filenames.  Useful for discovering which games\n"
            "have been profiled and what to pass to --game."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pl.add_argument(
        "--log-dir",
        metavar="DIR",
        help="Directory to scan (default: standard MangoHud log dirs).",
    )
    pl.set_defaults(func=cmd_games)

    # -- organize --
    po = sub.add_parser(
        "organize",
        help="Sort MangoHud logs into per-game folders with rotation.",
        description=textwrap.dedent(
            f"""\
            Copy MangoHud CSV logs from /tmp/MangoHud into an organised tree:

              ~/Documents/MangoBench_Logs/
                Cyberpunk2077/
                  Cyberpunk2077_2026-02-22_14-30-00.csv
                  current.csv  ->  (symlink to today's newest)
                HalfLife2/
                  ...

            Rotation: keeps at most --max-logs per game (default {MAX_LOGS_PER_GAME}),
            deleting the oldest when exceeded.

            current.csv: always symlinks to today's newest log for quick access.
            This layout is FlightlessSomething-friendly: each game folder is a
            natural set of "runs" you can upload as one Benchmark.
        """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    po.add_argument(
        "--source",
        metavar="DIR",
        help="Source directory for raw MangoHud logs (default: /tmp/MangoHud).",
    )
    po.add_argument(
        "--dest",
        metavar="DIR",
        default=str(BENCH_LOG_DIR),
        help=f"Destination root (default: {BENCH_LOG_DIR}).",
    )
    po.add_argument(
        "--max-logs",
        type=int,
        default=MAX_LOGS_PER_GAME,
        help=f"Max CSV files per game before oldest are deleted (default: {MAX_LOGS_PER_GAME}).",
    )
    po.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be done without copying/deleting.",
    )
    po.set_defaults(func=cmd_organize)

    # -- bundle --
    pb = sub.add_parser(
        "bundle",
        help="Create a zip of logs for FlightlessSomething upload.",
        description=textwrap.dedent(
            """\
            Package selected MangoHud CSV logs into a zip file ready for
            batch upload to FlightlessSomething (or similar web viewers).

            On FlightlessSomething, a "Benchmark" is a container. Uploading
            multiple CSVs to the same Benchmark creates side-by-side
            comparison of different games/runs  like benchmark #1937.

            Without --game, bundles the "current.csv" (today's newest)
            from each game folder.  With --game, bundles all logs for
            that specific game.

            Workflow:
              1. Play games (MangoHud logs automatically)
              2. mango-hud-profiler organize
              3. mango-hud-profiler bundle
              4. Upload the zip to FlightlessSomething
        """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pb.add_argument(
        "-g", "--game", metavar="NAME", help="Bundle only logs for this game."
    )
    pb.add_argument(
        "--source",
        metavar="DIR",
        default=str(BENCH_LOG_DIR),
        help=f"Source directory (default: {BENCH_LOG_DIR}).",
    )
    pb.add_argument(
        "-o",
        "--output",
        metavar="ZIP",
        help="Output zip path (default: auto-named in source dir).",
    )
    pb.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max number of CSVs to include (newest first).",
    )
    pb.set_defaults(func=cmd_bundle)

    # -- upload --
    pu = sub.add_parser(
        "upload",
        help="Upload logs to FlightlessSomething via API.",
        description=textwrap.dedent(
            f"""\
            Upload MangoHud CSV logs directly to FlightlessSomething, creating
            a new Benchmark with each CSV as a separate "Run" for side-by-side
            comparison.

            Requires an API token from FlightlessSomething:
              1. Log in at {FLIGHTLESS_BASE}
              2. Go to /api-tokens and create a token
              3. Store it (recommended):
                   echo YOUR_TOKEN > ~/.flightless-token
                   chmod 600 ~/.flightless-token
              Token lookup order: --token > FLIGHTLESS_TOKEN env > ~/.flightless-token

            Examples:
              # Upload all current logs
              {PROG_NAME} upload --token YOUR_TOKEN

              # Upload only Cyberpunk logs
              {PROG_NAME} upload --game Cyberpunk2077 --token YOUR_TOKEN

              # Upload specific files
              {PROG_NAME} upload --input file1.csv file2.csv --token YOUR_TOKEN

              # Non-interactive (skip confirmation)
              {PROG_NAME} upload --game Cyberpunk2077 -y --token YOUR_TOKEN
        """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pu.add_argument(
        "-t",
        "--token",
        metavar="TOKEN",
        help="FlightlessSomething API token (from /api-tokens). "
        "Also reads FLIGHTLESS_TOKEN env var.",
    )
    pu.add_argument(
        "--append",
        action="store_true",
        help="Append runs to an existing benchmark instead of creating a new one. "
        "Lists your benchmarks and prompts for selection.",
    )
    pu.add_argument(
        "--force",
        action="store_true",
        help="Allow re-uploading files already present in the benchmark.",
    )
    pu.add_argument(
        "-g", "--game", metavar="NAME", help="Upload only logs for this game."
    )
    pu.add_argument(
        "-i",
        "--input",
        nargs="*",
        metavar="PATH",
        help="Specific CSV file(s) or directories to upload.",
    )
    pu.add_argument(
        "--source",
        metavar="DIR",
        default=str(BENCH_LOG_DIR),
        help=f"Source directory for organized logs (default: {BENCH_LOG_DIR}).",
    )
    pu.add_argument(
        "--title", metavar="TEXT", help="Benchmark title (default: auto-generated)."
    )
    pu.add_argument(
        "--description",
        metavar="TEXT",
        help="Benchmark description (default: auto-generated).",
    )
    pu.add_argument(
        "--url",
        metavar="URL",
        help=f"FlightlessSomething base URL (default: {FLIGHTLESS_BASE}).",
    )
    pu.add_argument(
        "--limit",
        type=int,
        default=None,
        help="Max number of CSVs to upload (newest first).",
    )
    pu.add_argument(
        "-y", "--yes", action="store_true", help="Skip confirmation prompt."
    )
    pu.set_defaults(func=cmd_upload)

    # -- test-config --
    pt = sub.add_parser(
        "test",
        help="Verify MangoHud logging works (simulates the gamescope MANGOHUD_CONFIGFILE override).",
        description=(
            "Simulate the gamescope-session environment and confirm that logging\n"
            "keys from MANGOHUD_CONFIG survive the MANGOHUD_CONFIGFILE override.\n\n"
            "Launches a short renderer session (glxgears/vkcube) with autostart_log\n"
            "and checks that a CSV log is created in the configured output folder."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pt.add_argument(
        "--log-dir",
        metavar="DIR",
        help=f"Log output dir to test (default: {MANGOHUD_LOG_DIR}).",
    )
    pt.add_argument(
        "--duration",
        type=int,
        default=5,
        metavar="SECS",
        help="How long to run the renderer (default: 5s).",
    )
    pt.add_argument(
        "--live",
        action="store_true",
        help="Build MANGOHUD_CONFIG from constants rather than reading the installed env.d file.",
    )
    pt.set_defaults(func=cmd_test)

    return p


def main(argv: Optional[List[str]] = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    setup_logging(args.verbose, getattr(args, "logfile", None))

    if not hasattr(args, "func"):
        parser.print_help()
        return 0

    log.debug(
        "OS detection: bazzite=%s steamos=%s mangohud=%s",
        is_bazzite(),
        is_steamos(),
        mangohud_installed(),
    )
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
