#!/usr/bin/env python3
"""
mango-hud-profiler.py -- MangoHud Performance Profiler for Bazzite / SteamOS

A fully-featured utility to configure, launch, profile, graph, and summarise
MangoHud performance-logging sessions.  Designed for Bazzite (SteamOS
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
MANGOHUD_LOG_DIR = pathlib.Path.home() / "manglogs"
MANGOHUD_TMP_LOG = pathlib.Path("/tmp/MangoHud")
MANGOHUD_ALT_LOG = XDG_DATA / "MangoHud"
BENCH_LOG_DIR = MANGOHUD_LOG_DIR  # organized logs live alongside raw logs
CHART_BASE_DIR = pathlib.Path.home() / "mangohud-perf"
MAX_LOGS_PER_GAME = 15

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
FLIGHTLESS_UPLOAD_ENDPOINT = f"{FLIGHTLESS_BASE}/benchmark"

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

LOG_FMT = "%(asctime)s [%(levelname)-7s] %(name)s: %(message)s"
LOG_DATEFMT = "%Y-%m-%d %H:%M:%S"
log = logging.getLogger(PROG_NAME)


def setup_logging(verbosity: int = 0, logfile: Optional[str] = None) -> None:
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


def parse_csv(path: pathlib.Path) -> Tuple[List[str], List[Dict[str, str]]]:
    lines = [
        s
        for s in path.read_text(encoding="utf-8", errors="replace").splitlines()
        if s.strip()
    ]
    if not lines:
        return [], []
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
    rows: List[Dict[str, str]] = []
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

def sync_config_to_preset():
    source_path = os.path.expanduser("~/.config/MangoHud/MangoHud.conf")
    target_path = os.path.expanduser("~/.config/MangoHud/presets.conf")

    if not os.path.exists(source_path):
        print(f"❌ Source config not found at {source_path}")
        return

    # Read your existing master config
    with open(source_path, 'r') as f:
        master_config = f.read()

    # Wrap it in the [preset 2] header
    # This effectively "buffs" the Steam Slider Level 2 with your settings
    preset_data = f"[preset 2]\n{master_config}"

    # Write it to the presets file
    try:
        with open(target_path, 'w') as f:
            f.write(preset_data)
        print(f"✅ Successfully copied MangoHud.conf into Preset 2 hijack.")
        print("🚀 Just set the Steam Overlay to Level 2 (Horizontal) to begin.")
    except Exception as e:
        print(f"❌ Error writing to presets.conf: {e}")

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

    # TEMPORARY
    # Copy to presets "2" so moving to slider 2 uses our config
    # This allows skipping having to set launch options
    sync_config_to_preset()

    out.write_text(txt, encoding="utf-8")
    scope = f"game '{args.game}' (wine-{args.game}.conf)" if args.game else "global"
    print(f"  Config written: {out}")
    print(f"    Preset: {pn} -- {pr['description']}")
    print(f"    Scope : {scope}")
    print(f"    Logs  : {log_dir}")
    print(f"    Toggle: Shift_L+F2 to start/stop logging")
    if args.game:
        print(f"    MangoHud auto-applies when running '{args.game}' via Proton/Wine.")
    # Show all config paths for reference
    print(f"\n    Config precedence (MangoHud checks in order):")
    print(f"      1. MANGOHUD_CONFIGFILE env var")
    if args.game:
        print(f"      2. ~/.config/MangoHud/wine-{args.game}.conf  <-- this file")
    print(f"      3. {MANGOHUD_CONF_FILE}")
    print(f"      4. ~/.var/app/com.valvesoftware.Steam/config/MangoHud/MangoHud.conf")
    if is_bazzite():
        print("    Bazzite: /usr/bin/mangohud reads from ~/.config/MangoHud/")
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
            [_print_summary(f) for f in new]
        if args.auto_graph:
            print()
            od = pathlib.Path(args.graph_output) if args.graph_output else new[0].parent
            [_gen_graphs(f, od, fmt=args.graph_format) for f in new]
    else:
        print(f"\n  No new logs found. Check config. Expected dir: {ld}")
    return 0


# -- graph ------------------------------------------------------------------

_MPL = False
try:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    _MPL = True
except ImportError:
    pass


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
    ax.plot(x, vals, color=color, lw=0.7)
    ax.fill_between(x, vals, alpha=fa, color=color)
    ax.set_title(title, fontsize=13, fontweight="bold")
    ax.set_ylabel(ylabel)
    ax.set_xlabel("Sample")
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    fig.savefig(str(out))
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
    # Combined FPS+Frametime
    fk = _fcol(cols, ["fps", "FPS"])
    ftk = _fcol(cols, ["frametime", "frametime_ms", "Frametime"])
    if fk and ftk and _MPL:
        fig, (a1, a2) = plt.subplots(2, 1, figsize=(w, h * 1.2), dpi=dpi, sharex=True)
        x = list(range(len(rows)))
        fv = [sf(r.get(fk, "0")) for r in rows]
        tv = [sf(r.get(ftk, "0")) for r in rows]
        a1.plot(x, fv, color="#2ecc71", lw=0.7)
        a1.fill_between(x, fv, alpha=0.2, color="#2ecc71")
        a1.set_ylabel("FPS")
        a1.set_title(f"Overview -- {s}", fontsize=13, fontweight="bold")
        a1.grid(True, alpha=0.3)
        a2.plot(x, tv, color="#e74c3c", lw=0.7)
        a2.fill_between(x, tv, alpha=0.15, color="#e74c3c")
        a2.set_ylabel("Frametime (ms)")
        a2.set_xlabel("Sample")
        a2.grid(True, alpha=0.3)
        fig.tight_layout()
        o = out_dir / f"{s}_overview.{fmt}"
        fig.savefig(str(o))
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
            cmd, cwd=str(out_dir), capture_output=True, text=True, timeout=60
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
    print(f"\n  --- Upload to Web Viewers ---")
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
    print(
        f"\n  Use --game NAME with configure/graph/summary to target a specific game."
    )
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
    return m.group(1) if m else stem


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

    raw_logs = find_logs(src_dir)
    if not raw_logs:
        print("  No MangoHud CSV logs found to organize.")
        print(f"    Searched: {MANGOHUD_LOG_DIR}, {MANGOHUD_ALT_LOG}")
        return 1

    dest.mkdir(parents=True, exist_ok=True)
    moved = 0
    rotated = 0
    skipped = 0
    today = datetime.date.today().isoformat()

    for src in raw_logs:
        game = _extract_game_name(src.stem)
        game_dir = dest / game
        target = game_dir / src.name

        if target.exists():
            skipped += 1
            continue

        if dry:
            print(f"    [dry-run] {src.name} -> {game_dir}/")
            moved += 1
            continue

        game_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(str(src), str(target))
        moved += 1
        log.info("Copied: %s -> %s", src, target)

    # Rotation + current symlinks
    if not dry:
        for game_dir in sorted(dest.iterdir()):
            if not game_dir.is_dir():
                continue
            rotated += _rotate_game_logs(game_dir, max_logs)

            # Update "current.csv" symlink -> today's newest CSV
            day_logs = sorted(
                [
                    f
                    for f in game_dir.glob("*.csv")
                    if f.name != "current.csv" and today in f.name
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
        print(f"  No logs found to bundle.")
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
    print(f"    Upload to FlightlessSomething:")
    print(f"      {FLIGHTLESS_URL}")
    print(f"      Select all CSVs from the zip (or upload the individual files).")
    print(f"\n    Included logs:")
    for c in csvs:
        print(f"      {c.name}  ({c.stat().st_size/1024:.1f} KB)")
    return 0


# -- upload -----------------------------------------------------------------


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
                [f for f in game_dir.glob("*.csv") if f.name != "current.csv"],
                key=lambda p: p.stat().st_mtime,
            )
        else:
            csvs = find_logs(src_dir, game=game)
    else:
        # All games: pick current.csv or newest from each folder
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
    return csvs


def cmd_upload(args: argparse.Namespace) -> int:
    """Upload MangoHud CSV logs to FlightlessSomething via their API.

    API (from github.com/erkexzcx/FlightlessSomething-auto):
      POST /benchmark  (multipart/form-data)
      Cookie: mysession=<session_token>
      Fields: title, description, files (multiple)
      Success: HTTP 303 with Location header -> benchmark URL
    """
    import urllib.error
    import urllib.request

    session = args.session
    if not session:
        # Check environment variable
        session = os.environ.get("FLIGHTLESS_SESSION", "")
    if not session:
        log.error(
            "No session token provided. Use --session TOKEN or set "
            "FLIGHTLESS_SESSION environment variable.\n"
            "  To get your session token:\n"
            "    1. Log in at %s\n"
            "    2. Open browser DevTools -> Application -> Cookies\n"
            "    3. Copy the 'mysession' cookie value",
            FLIGHTLESS_BASE,
        )
        return 1

    base_url = args.url or FLIGHTLESS_BASE
    endpoint = f"{base_url}/benchmark"

    csvs = _collect_csvs_for_upload(args)
    limit = args.limit
    if limit and len(csvs) > limit:
        csvs = csvs[-limit:]

    if not csvs:
        print("  No CSV files found to upload.")
        print(f"  Run '{PROG_NAME} organize' first, or specify --input files.")
        return 1

    game = getattr(args, "game", None)
    title = (
        args.title
        or f"Benchmark: {game or 'All Games'} - {datetime.datetime.now().strftime('%Y-%m-%d %H:%M')}"
    )
    description = args.description or f"Uploaded via {PROG_NAME} v{VERSION}"

    print(f"  Uploading to FlightlessSomething:")
    print(f"    Endpoint : {endpoint}")
    print(f"    Title    : {title}")
    print(f"    Files    : {len(csvs)} CSV(s)")
    for c in csvs:
        print(f"      {c.name}  ({c.stat().st_size/1024:.1f} KB)")

    if not args.yes:
        try:
            answer = input("\n  Proceed with upload? [y/N] ").strip().lower()
            if answer not in ("y", "yes"):
                print("  Upload cancelled.")
                return 0
        except (EOFError, KeyboardInterrupt):
            print("\n  Upload cancelled.")
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
        body_parts.append(filepath.read_bytes())
        body_parts.append(b"\r\n")

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
            "Cookie": f"mysession={session}",
        },
    )

    log.info("POST %s (%d bytes, %d files)", endpoint, len(body), len(csvs))

    try:
        # FlightlessSomething returns 303 redirect on success
        # urllib follows redirects by default, so we need a custom handler
        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, headers, newurl):
                return None  # Don't follow redirects

        opener = urllib.request.build_opener(NoRedirect)
        response = opener.open(req)
        status = response.status
        location = response.getheader("Location", "")
    except urllib.error.HTTPError as e:
        status = e.code
        location = e.headers.get("Location", "") if hasattr(e, "headers") else ""
        if status != 303:
            log.error("Upload failed: HTTP %d", status)
            try:
                err_body = e.read().decode("utf-8", errors="replace")[:500]
                log.error("Response: %s", err_body)
            except Exception:
                pass
            return 1
    except urllib.error.URLError as e:
        log.error("Connection failed: %s", e.reason)
        return 1

    if status == 303 and location:
        full_url = f"{base_url}{location}" if location.startswith("/") else location
        print(f"\n  Upload successful!")
        print(f"    Benchmark URL: {full_url}")
        print(f"    {len(csvs)} CSV(s) uploaded as separate runs.")
        return 0
    elif status == 303:
        print("\n  Upload successful! (no redirect URL returned)")
        return 0
    else:
        log.warning("Unexpected status: HTTP %d (expected 303)", status)
        print(f"\n  Upload may have succeeded (HTTP {status}).")
        if location:
            print(f"    Location: {base_url}{location}")
        return 0


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
            f"""\
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

            Requires a session token from FlightlessSomething (log in via
            browser, then extract the 'mysession' cookie from DevTools).

            Auth via --session TOKEN or FLIGHTLESS_SESSION env var.

            API based on: github.com/erkexzcx/FlightlessSomething-auto

            Examples:
              # Upload all current logs
              {PROG_NAME} upload --session YOUR_TOKEN

              # Upload only Cyberpunk logs
              {PROG_NAME} upload --game Cyberpunk2077 --session YOUR_TOKEN

              # Upload specific files
              {PROG_NAME} upload --input file1.csv file2.csv --session YOUR_TOKEN

              # Non-interactive (skip confirmation)
              {PROG_NAME} upload --game Cyberpunk2077 -y --session YOUR_TOKEN
        """
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    pu.add_argument(
        "-s",
        "--session",
        metavar="TOKEN",
        help="FlightlessSomething 'mysession' cookie value. "
        "Also reads FLIGHTLESS_SESSION env var.",
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
