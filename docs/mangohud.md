# MangoHud Profiling Guide for Bazzite / SteamOS

A comprehensive guide to MangoHud's default behaviour, log management, the
FlightlessSomething web viewer, and the `mango-hud-profiler.py` utility
included in this repository.

---

## Table of Contents

1. [What is MangoHud?](#what-is-mangohud)
2. [MangoHud Default Behaviour on Bazzite / SteamOS](#mangohud-default-behaviour-on-bazzite--steamos)
3. [MangoHud CSV Log Format](#mangohud-csv-log-format)
4. [Per-Game Configuration](#per-game-configuration)
5. [FlightlessSomething Web Viewer](#flightlessomething-web-viewer)
6. [mango-hud-profiler.py — Our Utility](#mango-hud-profilerpy--our-utility)
7. [Typical Workflow](#typical-workflow)
8. [Resources & References](#resources--references)

---

## What is MangoHud?

MangoHud is a Vulkan and OpenGL overlay for monitoring FPS, frame times,
CPU/GPU temperatures, power draw, memory usage, and more. It can also log
all of these metrics to CSV files for offline analysis.

On **Bazzite** (a SteamOS derivative based on Fedora Atomic), MangoHud is
**pre-installed and always available**. It runs as a Vulkan layer that
automatically hooks into every game launched through Steam or Gamescope.

---

## MangoHud Default Behaviour on Bazzite / SteamOS

### OSD (On-Screen Display)

- MangoHud's overlay is toggled via a keybind (default: `Right_Shift + F12`)
- On SteamOS/Bazzite in Game Mode, the performance overlay is accessible via
  the Quick Access Menu (QAM) → Performance → Performance Overlay Level (1–4)
- Level 1 = FPS only, Level 4 = full metrics

### Logging

By default, MangoHud does **not** log to CSV automatically. Logging must be
enabled via one of:

| Method | How |
|--------|-----|
| **Config file** | Set `log_duration=0` and `autostart_log=1` in `MangoHud.conf` |
| **Keybind** | Press `Right_Shift + F2` during gameplay to toggle logging on/off |
| **Environment variable** | Launch with `MANGOHUD_LOG=1` |

### Default Log Location

When logging is active, MangoHud writes CSV files to:

```
/tmp/MangoHud/<GameName>_<YYYY-MM-DD_HH-MM-SS>.csv
```

- `/tmp/MangoHud/` is created automatically
- Files are named after the game executable + timestamp
- **Important**: `/tmp/` is cleared on reboot on most Linux systems, so logs
  are ephemeral unless copied elsewhere

### Default Config Location

MangoHud reads its configuration from (in order of priority):

1. `MANGOHUD_CONFIGFILE` environment variable (if set)
2. `~/.config/MangoHud/<executable_name>.conf` (per-game config)
3. `~/.config/MangoHud/MangoHud.conf` (global config)

If no config file exists, MangoHud uses built-in defaults (OSD only, no logging).

### Key Config Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `fps` | 1 | Show FPS on overlay |
| `frametime` | 0 | Show frame time on overlay |
| `cpu_stats` | 0 | Show CPU usage/frequency |
| `gpu_stats` | 0 | Show GPU usage |
| `cpu_temp` | 0 | Show CPU temperature |
| `gpu_temp` | 0 | Show GPU temperature |
| `ram` | 0 | Show RAM usage |
| `vram` | 0 | Show VRAM usage |
| `battery` | 0 | Show battery level (handhelds) |
| `output_folder` | `/tmp/MangoHud` | Where CSV logs are written |
| `log_duration` | 0 | Log duration in seconds (0 = unlimited) |
| `log_interval` | 100 | Logging interval in milliseconds |
| `log_versioning` | 0 | Append version numbers to log filenames |
| `autostart_log` | 0 | Start logging automatically when game launches |

Full parameter reference: https://github.com/flightlessmango/MangoHud#mangohud_config

---

## MangoHud CSV Log Format

MangoHud CSV files have a header row followed by data rows. Example:

```csv
os,cpu,gpu,ram,kernel,driver,cpuscheduler,fps,frametime,cpu_load,gpu_load,cpu_temp,gpu_temp,cpu_power,gpu_power,vram,ram_used,swap,battery
Linux,AMD Ryzen 7 7840U,AMD Radeon 780M,...,60,16.67,45,62,71,68,15.2,8.1,4096,8192,0,85
```

### Key Columns

| Column | Unit | Description |
|--------|------|-------------|
| `fps` | frames/s | Frames per second |
| `frametime` | ms | Time per frame |
| `cpu_load` | % | CPU utilisation |
| `gpu_load` | % | GPU utilisation |
| `cpu_temp` | °C | CPU temperature |
| `gpu_temp` | °C | GPU temperature |
| `cpu_power` | W | CPU power draw |
| `gpu_power` | W | GPU power draw |
| `ram` / `ram_used` | MB | RAM usage |
| `vram` | MB | VRAM usage |
| `battery` | % | Battery level |
| `battery_power` | W | Battery discharge rate |

The exact columns present depend on your MangoHud config and hardware capabilities.

---

## Per-Game Configuration

MangoHud supports per-game configs by placing a file named after the game
executable in the config directory:

```
~/.config/MangoHud/<executable_name>.conf
```

For example:
- `~/.config/MangoHud/Cyberpunk2077.conf` — applies only to Cyberpunk 2077
- `~/.config/MangoHud/hl2_linux.conf` — applies only to Half-Life 2

Per-game configs override the global `MangoHud.conf` for that specific game.
This is useful for:
- Enabling heavy logging for one game while keeping the HUD minimal for others
- Using the `battery` preset for handheld gaming on specific titles
- Disabling the overlay entirely for competitive games

---

## FlightlessSomething Web Viewer

**URL**: https://flightlesssomething.com

FlightlessSomething is the primary web-based viewer for MangoHud CSV logs.
It provides interactive charts, statistical analysis, and comparison views.

### How It Works

1. **Benchmarks are containers**: Each "Benchmark" on FlightlessSomething is a
   collection of one or more CSV uploads. A single Benchmark URL
   (e.g., `/benchmarks/1937`) can contain multiple "Runs."

2. **Each CSV = one Run**: When you upload a MangoHud CSV, it becomes a
   separate Run within the Benchmark. Multiple CSVs uploaded together create
   side-by-side comparisons (like comparing FPS across different games or
   settings).

3. **Do NOT merge CSVs**: Never combine multiple game logs into one CSV file.
   The timestamps, metadata, and column headers will break the visualiser.
   Upload them as separate files to the same Benchmark instead.

### Upload Workflow

1. Go to https://flightlesssomething.com/benchmarks/new
2. Select **multiple** CSV files at once (or upload one at a time)
3. Each file becomes a separate Run in the same Benchmark
4. The site reads game name, GPU info, and driver version from the CSV headers

### Building Benchmarks Over Time

- Create an account to save Benchmarks persistently
- Return to an existing Benchmark page and use "Add Runs" to grow it
- This lets you compare today's performance against yesterday's

### What FlightlessSomething Reads from CSVs

The site parses these MangoHud CSV header fields for metadata:
- `os` — Operating system
- `cpu` — CPU model
- `gpu` — GPU model
- `driver` — GPU driver version
- `kernel` — Linux kernel version
- `ram` — Total RAM

These appear in the Benchmark sidebar for each Run.

### Other Compatible Viewers

| Viewer | URL | Notes |
|--------|-----|-------|
| FlightlessMango (legacy) | https://flightlessmango.com/games/new | Older upload portal, same backend |
| CapFrameX | https://www.capframex.com/analysis | Accepts MangoHud CSVs since v1.7 |
| mangoplot (CLI) | `pip install mangoplot` | Local terminal-based plot tool |

---

## mango-hud-profiler.py — Our Utility

Located at `utilities/mango-hud-profiler.py`, this script provides a complete
CLI for managing MangoHud logging sessions on Bazzite/SteamOS.

### Subcommands

| Command | Description |
|---------|-------------|
| `configure` | Generate MangoHud config files from presets (global or per-game) |
| `profile` | Run a timed profiling session (launch → wait → stop → report) |
| `graph` | Generate PNG/SVG/PDF graphs from MangoHud CSV logs |
| `summary` | Print statistics with percentiles, FPS stability, frametime jitter |
| `games` | List game names discovered from MangoHud log filenames |
| `organize` | Sort raw logs into per-game folders with rotation (max 30/game) |
| `bundle` | Create a zip of logs for FlightlessSomething batch upload |

### Config Presets

| Preset | Description |
|--------|-------------|
| `logging` | Full CSV logging, minimal OSD — best for data collection |
| `minimal` | FPS + frametime only, no logging |
| `full` | Everything on OSD + all logging enabled |
| `battery` | Power/battery metrics — ideal for Steam Deck and handhelds |

### Organised Log Layout

After running `organize`, logs are structured as:

```
~/Documents/MangoBench_Logs/
├── Cyberpunk2077/
│   ├── Cyberpunk2077_2026-02-22_14-30-00.csv
│   ├── Cyberpunk2077_2026-02-21_20-15-00.csv
│   ├── Cyberpunk2077_2026-02-20_18-00-00.csv
│   └── current.csv  →  Cyberpunk2077_2026-02-22_14-30-00.csv
├── HalfLife2/
│   ├── HalfLife2_2026-02-22_16-00-00.csv
│   └── current.csv  →  HalfLife2_2026-02-22_16-00-00.csv
└── benchmark_all-games_20260222_1630.zip   (created by 'bundle')
```

- **Per-game folders**: Each game gets its own directory
- **current.csv**: Always a symlink to today's newest log (1-day lifespan concept)
- **Rotation**: Oldest logs deleted when a game exceeds 30 files (configurable)
- **Bundle-ready**: Each game folder is a natural set of "Runs" for FlightlessSomething

### Per-Game Config Generation

```bash
# Global config (all games)
mango-hud-profiler configure --preset logging

# Per-game config (only Cyberpunk)
mango-hud-profiler configure --preset logging --game Cyberpunk2077

# Per-game with custom overrides
mango-hud-profiler configure --preset battery --game PortalDeck \
    --set log_interval=200 font_size=16
```

Per-game configs are written to `~/.config/MangoHud/<GameName>.conf` and
MangoHud picks them up automatically for that executable.

### Summary Output

The `summary` command produces per-metric statistics:

```
========================================================================
  MANGOHUD LOG SUMMARY: Cyberpunk2077_2026-02-22_14-30-00.csv
========================================================================
  File       : /home/user/Documents/MangoBench_Logs/Cyberpunk2077/...
  Size       : 245.3 KB
  Samples    : 7200
  OS         : Bazzite Linux 41
  Platform   : Bazzite (SteamOS derivative)

  --- Performance ---
  FPS                   avg=    62.4 fps  min=45.0  max=75.0  1%=48.2  99%=74.1
  Frame Time            avg=    16.0 ms   min=13.3  max=22.2  1%=13.5  99%=20.8

  --- Thermals ---
  CPU Temp              avg=    72.3 C    min=65.0  max=85.0
  GPU Temp              avg=    68.1 C    min=60.0  max=78.0

  FPS Stability : 87.3%  (100%=perfectly stable)
  Frametime Jitter (P99-P1): 7.30 ms

  --- Upload to Web Viewers ---
  Log file for upload: /home/user/Documents/MangoBench_Logs/Cyberpunk2077/...
    * FlightlessMango Log Viewer: https://flightlessmango.com/games/new
    * CapFrameX Web Analysis: https://www.capframex.com/analysis
========================================================================
```

### Graph Output

The `graph` command generates individual charts for each metric:
- `<game>_fps.png` — FPS over time
- `<game>_frametime.png` — Frame time over time
- `<game>_cpu_temp.png` — CPU temperature
- `<game>_gpu_temp.png` — GPU temperature
- `<game>_cpu_power.png` / `<game>_gpu_power.png` — Power draw
- `<game>_battery.png` — Battery level (if applicable)
- `<game>_ram.png` / `<game>_vram.png` — Memory usage
- `<game>_overview.png` — Combined FPS + frametime dual chart

Requires `matplotlib`: `pip install matplotlib`

---

## Typical Workflow

### One-Time Setup

```bash
# 1. Generate a logging-oriented MangoHud config
mango-hud-profiler configure --preset logging --force

# 2. Or per-game configs
mango-hud-profiler configure --preset logging --game Cyberpunk2077
mango-hud-profiler configure --preset battery --game PortalDeck
```

### Daily Gaming + Profiling

```bash
# Play your games normally — MangoHud logs to /tmp/MangoHud/ automatically
# (Press Right_Shift + F2 to toggle logging if autostart_log=0)

# After gaming, organise the raw logs into per-game folders
mango-hud-profiler organize

# See what games have logs
mango-hud-profiler games

# Summarise a specific game
mango-hud-profiler summary --game Cyberpunk2077

# Generate graphs
mango-hud-profiler graph --game Cyberpunk2077

# Create a bundle for FlightlessSomething upload
mango-hud-profiler bundle
# Or for a specific game:
mango-hud-profiler bundle --game Cyberpunk2077
```

### Uploading to FlightlessSomething

1. Run `mango-hud-profiler bundle` to create a zip
2. Go to https://flightlesssomething.com/benchmarks/new
3. Extract the zip and select all CSVs (or drag-drop them)
4. Each CSV becomes a separate "Run" in the same Benchmark
5. Share the Benchmark URL for comparison

**Pro tip**: Create an account on FlightlessSomething to save Benchmarks and
add more Runs over time (e.g., before/after a driver update).

---

## Resources & References

### MangoHud

- **GitHub**: https://github.com/flightlessmango/MangoHud
- **Configuration docs**: https://github.com/flightlessmango/MangoHud#mangohud_config
- **Keybinds**: https://github.com/flightlessmango/MangoHud#keybindings
- **FPS logging docs**: https://github.com/flightlessmango/MangoHud#fps-logging
- **MangoHud Releases**: https://github.com/flightlessmango/MangoHud/releases

### FlightlessSomething / FlightlessMango

- **FlightlessSomething** (primary viewer): https://flightlesssomething.com
- **Upload new benchmark**: https://flightlesssomething.com/benchmarks/new
- **FlightlessMango** (legacy): https://flightlessmango.com/games/new
- **FlightlessMango GitHub**: https://github.com/flightlessmango

### Bazzite / SteamOS

- **Bazzite**: https://bazzite.gg
- **Bazzite GitHub**: https://github.com/ublue-os/bazzite
- **SteamOS**: https://store.steampowered.com/steamos
- **Gamescope** (compositor): https://github.com/ValveSoftware/gamescope

### Analysis Tools

- **mangoplot** (CLI plotter): `pip install mangoplot` — https://github.com/flightlessmango/mangoplot
- **CapFrameX**: https://www.capframex.com — Desktop app + web analysis
- **matplotlib** (for `graph` subcommand): `pip install matplotlib`

### This Tool

- **Script**: `utilities/mango-hud-profiler.py`
- **Help**: `mango-hud-profiler --help`
- **Per-subcommand help**: `mango-hud-profiler <subcommand> --help`
- **Dependencies**: Python 3.8+ (stdlib only; matplotlib optional for graphs)