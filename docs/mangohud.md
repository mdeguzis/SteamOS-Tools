# MangoHud, mangoplot & FlightlessSomething — Guide for Bazzite / SteamOS

This document covers everything you need to know about MangoHud performance
monitoring, `mangoplot` chart generation, and uploading results to
FlightlessSomething — specifically for **Bazzite** and **SteamOS** derivatives.

---

## Table of Contents

- [What is MangoHud?](#what-is-mangohud)
- [What is mangoplot?](#what-is-mangoplot)
- [What is FlightlessSomething?](#what-is-flightlesssomething)
- [Installation on Bazzite / SteamOS](#installation-on-bazzite--steamos)
- [Configuration](#configuration)
  - [Config File Locations](#config-file-locations)
  - [Config Precedence](#config-precedence)
  - [Per-Game Configs](#per-game-configs)
  - [Recommended Config for Logging](#recommended-config-for-logging)
  - [Bottleneck Detection Keys](#bottleneck-detection-keys)
  - [All Config Options Reference](#all-config-options-reference)
- [Logging](#logging)
  - [Enabling Logging](#enabling-logging)
  - [Log File Locations](#log-file-locations)
  - [Log File Format](#log-file-format)
- [Using mangoplot](#using-mangoplot)
- [Using mango-hud-profiler.py](#using-mango-hud-profilerpy)
- [FlightlessSomething Workflow](#flightlesssomething-workflow)
  - [What is a Benchmark?](#what-is-a-benchmark)
  - [Upload Workflow](#upload-workflow)
  - [API Upload](#api-upload)
- [References](#references)

---

## What is MangoHud?

[MangoHud](https://github.com/flightlessmango/MangoHud) is a Vulkan and
OpenGL overlay for monitoring FPS, temperatures, CPU/GPU load, and more. It is
the standard performance overlay on **SteamOS**, **Bazzite**, and the
**Steam Deck**.

- **Repository**: <https://github.com/flightlessmango/MangoHud>
- **License**: MIT
- **Stars**: 8.3k+
- **Languages**: C (53%), C++ (41%), Python, Shell

MangoHud can:
- Display a real-time OSD (on-screen display) with FPS, frametime, temps, etc.
- **Log all metrics to CSV files** for offline analysis
- Be configured globally or per-game

On Bazzite, MangoHud is pre-installed at `/usr/bin/mangohud` and is always
active in gamescope (the SteamOS compositor).

---

## What is mangoplot?

`mangoplot` is a companion Python script that ships with MangoHud. It reads
MangoHud CSV log files and generates **PNG charts** with:

- FPS over time
- Frametime graphs (pacing analysis)
- CPU/GPU load
- Per-core CPU load (`core_load`) — crucial for single-core bottleneck detection
- GPU clock speeds — detects thermal throttling / downclocking

On Bazzite/SteamOS, it is available as `mangoplot` in the system PATH (installed
alongside MangoHud).

**Usage:**
```bash
mangoplot /path/to/MangoHud_log.csv
```

Charts are saved as PNG files in the current working directory.

---

## What is FlightlessSomething?

[FlightlessSomething](https://flightlesssomething.ambrosia.one/) is a
**web-based MangoHud log viewer** for interactive performance analysis and
comparison.

- **URL**: <https://flightlesssomething.ambrosia.one/>
- **Upload**: <https://flightlesssomething.ambrosia.one/benchmarks/new>
- **API reference**: <https://github.com/erkexzcx/FlightlessSomething-auto>

### Key Concepts

- A **Benchmark** is a container (like a folder). Example: `/benchmarks/1937`
- Each CSV you upload becomes a separate **Run** within that Benchmark
- Multiple runs are displayed **side-by-side** for comparison
- You can name each run (e.g. "Cyberpunk - Low" vs "Cyberpunk - Ultra")

### What It Reads

FlightlessSomething reads the `title` and `version` from MangoHud CSV headers.
It supports all standard MangoHud log columns.

> **Important**: Do NOT merge multiple game CSVs into one file. Upload them as
> separate files to the same Benchmark for side-by-side comparison.

### Other Web Viewers

| Viewer | URL | Notes |
|--------|-----|-------|
| FlightlessMango (original) | <https://flightlessmango.com/games/new> | Upload CSV directly |
| CapFrameX Web Analysis | <https://www.capframex.com/analysis> | Accepts MangoHud CSVs since v1.7 |

---

## Installation on Bazzite / SteamOS

### Bazzite (default — already installed)

MangoHud is part of the Bazzite image. The system binary is at:
```
/usr/bin/mangohud
```

It reads config from `~/.config/MangoHud/MangoHud.conf`.

### If Not Installed

```bash
# Bazzite / Fedora Atomic
rpm-ostree install mangohud

# Or via Flatpak (Vulkan layer)
flatpak install flathub org.freedesktop.Platform.VulkanLayer.MangoHud

# Arch-based
pacman -S mangohud

# Debian/Ubuntu
apt install mangohud
```

### Verify Installation

```bash
mangohud --version
mangoplot --help
```

---

## Configuration

### Config File Locations

| Target | Path |
|--------|------|
| **Global (user)** | `~/.config/MangoHud/MangoHud.conf` |
| **Steam Flatpak** | `~/.var/app/com.valvesoftware.Steam/config/MangoHud/MangoHud.conf` |
| **Per-game (Proton/Wine)** | `~/.config/MangoHud/wine-<GameName>.conf` |
| **Per-game (native)** | `~/.config/MangoHud/<executable>.conf` |
| **System example** | `/usr/share/doc/mangohud/MangoHud.conf.example` |
| **Upstream example** | <https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf> |

### Config Precedence

MangoHud checks these in order and **stops at the first one it finds**:

1. **`MANGOHUD_CONFIGFILE`** environment variable (highest priority)
2. **Per-game config**: `~/.config/MangoHud/wine-<GameName>.conf`
3. **Global config**: `~/.config/MangoHud/MangoHud.conf`
4. **Flatpak sandbox**: `~/.var/app/com.valvesoftware.Steam/config/MangoHud/MangoHud.conf`

You can also override individual keys at runtime:
```bash
MANGOHUD_CONFIG="fps,frametime,cpu_stats,gpu_stats" mangohud %command%
```

### Per-Game Configs

For **Proton/Wine** games (most Steam games):
```
~/.config/MangoHud/wine-<GameName>.conf
```

For **native Linux** games:
```
~/.config/MangoHud/<executable_name>.conf
```

Example:
```bash
# Create config specifically for Cyberpunk 2077 (Proton)
cp ~/.config/MangoHud/MangoHud.conf ~/.config/MangoHud/wine-Cyberpunk2077.conf
# Edit as needed
```

### Recommended Config for Logging

This configuration enables comprehensive CSV logging with all metrics needed
for bottleneck analysis. Place in `~/.config/MangoHud/MangoHud.conf`:

```ini
### Logging
output_folder=~/Documents/MangoLogs
toggle_logging=Shift_L+F2
log_duration=0
log_interval=100
log_versioning=1

### Performance metrics (essential for mangoplot bottleneck analysis)
fps
frametime
frame_timing
cpu_stats
gpu_stats
core_load
gpu_core_clock

### Detailed CPU
cpu_temp
cpu_power
cpu_mhz

### Detailed GPU
gpu_temp
gpu_power
gpu_mem_clock
gpu_mem_temp

### Memory
vram
ram
swap

### Power / Battery (Steam Deck / handheld)
battery
battery_power
gamepad_battery
throttling_status

### Wine/Proton info
wine
winesync
engine_version
vulkan_driver
gpu_name

### OSD appearance
position=top-left
background_alpha=0.4
font_size=20
```

> **Note**: MangoHud does NOT save logs by default. You MUST set
> `output_folder` and use `toggle_logging` (Shift+F2) to start/stop recording,
> or set `autostart_log=1` to log automatically.

### Bottleneck Detection Keys

These keys are **critical** for useful `mangoplot` analysis:

| Key | Why It Matters |
|-----|---------------|
| `cpu_stats` | Overall CPU usage — basic load monitoring |
| `gpu_stats` | Overall GPU usage — basic load monitoring |
| `core_load` | **Per-core CPU load** — finds single-core bottlenecks that `cpu_stats` misses |
| `gpu_core_clock` | **GPU clock speed** — detects thermal throttling / power-limit downclocking |
| `frametime` | **Frame pacing data** — the raw data behind frametime graphs |
| `frame_timing` | Frametime line graph on the OSD |

Without these keys, mangoplot output will be incomplete and you won't be able
to diagnose bottlenecks.

### All Config Options Reference

The full list of MangoHud config options is in the upstream example:
<https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf>

**Categories:**

#### Performance Tuning
- `fps_limit` — Limit FPS (e.g. `fps_limit=60`)
- `vsync` — VSync mode (0=adaptive, 1=off, 2=mailbox, 3=on)

#### OSD Presets
- `preset` — Quick preset (-1=default, 0=no display, 1=fps only, 2=horizontal, 3=extended, 4=high detail)
- `full` — Enable most toggleable parameters

#### GPU Information
- `gpu_stats`, `gpu_temp`, `gpu_junction_temp`, `gpu_core_clock`
- `gpu_mem_temp`, `gpu_mem_clock`, `gpu_power`, `gpu_power_limit`
- `gpu_fan`, `gpu_voltage` (AMD only)
- `gpu_load_change`, `gpu_load_value`, `gpu_load_color`

#### CPU Information
- `cpu_stats`, `cpu_temp`, `cpu_power`, `cpu_mhz`
- `core_load`, `core_load_change`, `core_bars`, `core_type`
- `cpu_load_change`, `cpu_load_value`, `cpu_load_color`

#### Memory
- `vram`, `ram`, `swap`
- `procmem`, `procmem_shared`, `procmem_virt`, `proc_vram`

#### Battery (Steam Deck / Handheld)
- `battery`, `battery_icon`, `battery_watt`, `battery_time`
- `device_battery=gamepad,mouse`

#### FPS & Frametime
- `fps`, `frametime`, `frame_count`
- `fps_sampling_period`, `fps_color_change`
- `fps_metrics=avg,0.01` (percentile values)
- `throttling_status`, `throttling_status_graph`

#### I/O
- `io_read`, `io_write`

#### Misc Info
- `engine_version`, `gpu_name`, `vulkan_driver`
- `wine`, `winesync`, `exec_name`, `present_mode`
- `arch`, `resolution`, `display_server`, `refresh_rate`

#### Gamescope (SteamOS)
- `fsr`, `hide_fsr_sharpness`, `debug`, `hdr`, `refresh_rate`

#### Steam Deck Specific
- `fan` — Show fan RPM
- `show_fps_limit`

#### Graphs
- `graphs=gpu_load,cpu_load,gpu_core_clock,gpu_mem_clock,vram,ram,cpu_temp,gpu_temp`

#### Logging
- `output_folder` — Directory for CSV logs
- `toggle_logging` — Keybind (e.g. `Shift_L+F2`)
- `log_duration` — Seconds (0 = manual start/stop)
- `log_interval` — Milliseconds between samples
- `log_versioning` — Append version numbers to filenames
- `autostart_log` — Start logging immediately

#### Appearance
- `position` — `top-left`, `top-right`, `bottom-left`, `bottom-right`
- `font_size`, `font_scale`, `background_alpha`
- `round_corners`, `hud_no_margin`, `hud_compact`
- `text_outline`, `text_outline_color`, `text_outline_thickness`

---

## Logging

### Enabling Logging

Add these to your `MangoHud.conf`:

```ini
output_folder=~/Documents/MangoLogs
toggle_logging=Shift_L+F2
log_duration=0
log_interval=100
log_versioning=1
```

Then while gaming:
1. Press **Shift+F2** to start recording
2. Play for your desired duration
3. Press **Shift+F2** again to stop

Or set `autostart_log=1` to log automatically whenever MangoHud is active.

### Log File Locations

| Source | Path |
|--------|------|
| Configured output | `~/Documents/MangoLogs/` (recommended) |
| Default (if no config) | `/tmp/MangoHud/` |
| XDG fallback | `~/.local/share/MangoHud/` |

### Log File Format

MangoHud logs are CSV files named:
```
<GameName>_<YYYY-MM-DD_HH-MM-SS>.csv
```

Example: `Cyberpunk2077_2026-02-22_14-30-00.csv`

The CSV contains columns like:
```
fps,frametime,cpu_stats,gpu_stats,cpu_temp,gpu_temp,cpu_power,gpu_power,
gpu_core_clock,vram,ram,battery,...
```

Each row is one sample at the configured `log_interval` (default 100ms).

---

## Using mangoplot

`mangoplot` ships with MangoHud and is available in PATH on Bazzite/SteamOS.

### Basic Usage

```bash
# Generate charts from a log file
mangoplot ~/Documents/MangoLogs/Cyberpunk2077_2026-02-22_14-30-00.csv
```

Charts are saved as PNG files in the current directory.

### Best Results

For the most informative charts, ensure your config includes:
- `core_load` — shows per-core CPU load (finds single-core bottlenecks)
- `gpu_core_clock` — shows if GPU is downclocking under load
- `frametime` — the raw data for pacing analysis

### Output

mangoplot generates charts including:
- **FPS over time** — see average, drops, stability
- **Frametime graph** — identify stutter/pacing issues
- **CPU/GPU load** — utilization analysis
- **Core load** — per-core view for CPU bottleneck detection
- **GPU clocks** — thermal throttling detection

---

## Using mango-hud-profiler.py

The `utilities/mango-hud-profiler.py` script in this repo provides a complete
workflow for MangoHud profiling:

### Subcommands

| Command | Description |
|---------|-------------|
| `configure` | Generate MangoHud config from presets, per-game, or `--check` existing |
| `profile` | Timed profiling session (launch, log, stop, report) |
| `graph` | Generate charts via mangoplot (or matplotlib fallback) |
| `summary` | Stats with percentiles, FPS stability, frametime jitter |
| `games` | List profiled games from log filenames |
| `organize` | Sort logs into per-game folders, rotate (keep 15), create `<game>-current-mangohud.csv` symlink |
| `bundle` | Zip logs for FlightlessSomething manual upload |
| `upload` | Upload directly to FlightlessSomething via API |

### Quick Start

```bash
# 1. Set up MangoHud config with all bottleneck keys
./utilities/mango-hud-profiler.py configure --preset logging

# 2. Or just check/fix your existing config
./utilities/mango-hud-profiler.py configure --check

# 3. Play games, press Shift+F2 to log

# 4. Organize logs into per-game folders
./utilities/mango-hud-profiler.py organize

# 5. Generate charts (uses mangoplot)
./utilities/mango-hud-profiler.py graph --game Cyberpunk2077

# 6. View summary
./utilities/mango-hud-profiler.py summary --game Cyberpunk2077

# 7. Upload to FlightlessSomething
export FLIGHTLESS_SESSION="your_mysession_cookie"
./utilities/mango-hud-profiler.py upload --game Cyberpunk2077
```

### Directory Layout

After running `organize`:
```
~/Documents/MangoLogs/
  Cyberpunk2077/
    Cyberpunk2077_2026-02-22_14-30-00.csv
    Cyberpunk2077_2026-02-21_20-15-00.csv
    Cyberpunk2077-current-mangohud.csv -> (symlink to newest)
  HalfLife2/
    ...

~/mangohud-perf/
  Cyberpunk2077/
    charts/
      *.png  (mangoplot output)
  HalfLife2/
    charts/
      ...
```

---

## FlightlessSomething Workflow

### What is a Benchmark?

On FlightlessSomething, a **Benchmark** (e.g. `/benchmarks/1937`) is a
container that holds multiple CSV uploads. Each CSV becomes a separate "Run"
shown side-by-side.

This means:
- **Don't** merge game CSVs into one file
- **Do** upload multiple CSVs to the same Benchmark
- Each CSV = one game or one settings variant

### Upload Workflow

#### Manual (Web Browser)

1. Play games and log (Shift+F2)
2. Go to <https://flightlesssomething.ambrosia.one/benchmarks/new>
3. Select multiple CSV files at once
4. The site creates a single Benchmark URL with all runs side-by-side

#### Using mango-hud-profiler.py

```bash
# Organize logs first
./utilities/mango-hud-profiler.py organize

# Bundle into a zip (for manual upload)
./utilities/mango-hud-profiler.py bundle

# Or upload directly via API
./utilities/mango-hud-profiler.py upload --session YOUR_TOKEN
```

### API Upload

Based on [FlightlessSomething-auto](https://github.com/erkexzcx/FlightlessSomething-auto):

```
POST /benchmark
Content-Type: multipart/form-data
Cookie: mysession=<session_token>

Fields:
  title=<benchmark title>
  description=<benchmark description>
  files=@file1.csv
  files=@file2.csv
  ...

Success: HTTP 303 with Location header -> /benchmarks/<ID>
```

**Getting your session token:**
1. Log in at <https://flightlesssomething.ambrosia.one/>
2. Open browser DevTools → Application → Cookies
3. Copy the `mysession` cookie value

**curl example:**
```bash
curl -i "https://flightlesssomething.ambrosia.one/benchmark" \
  -X POST \
  -H "Cookie: mysession=$MYSESSION" \
  -F "title=My Benchmark" \
  -F "description=Testing" \
  -F "files=@Cyberpunk2077_2026-02-22.csv" \
  -F "files=@HalfLife2_2026-02-22.csv"
```

---

## References

### Official MangoHud

| Resource | URL |
|----------|-----|
| GitHub repository | <https://github.com/flightlessmango/MangoHud> |
| Upstream example config | <https://github.com/flightlessmango/MangoHud/blob/master/data/MangoHud.conf> |
| Releases | <https://github.com/flightlessmango/MangoHud/releases> |
| mangoplot (included) | Ships with MangoHud as `mangoplot` |

### FlightlessSomething

| Resource | URL |
|----------|-----|
| Web viewer | <https://flightlesssomething.ambrosia.one/> |
| Upload page | <https://flightlesssomething.ambrosia.one/benchmarks/new> |
| API automation | <https://github.com/erkexzcx/FlightlessSomething-auto> |

### Other Viewers

| Resource | URL |
|----------|-----|
| FlightlessMango (original) | <https://flightlessmango.com/games/new> |
| CapFrameX | <https://www.capframex.com/analysis> |

### SteamOS / Bazzite

| Resource | URL |
|----------|-----|
| Bazzite | <https://bazzite.gg/> |
| SteamOS | <https://store.steampowered.com/steamos> |
| MangoHud on Bazzite | Pre-installed at `/usr/bin/mangohud` |

### This Repository

| Resource | Path |
|----------|------|
| mango-hud-profiler.py | `utilities/mango-hud-profiler.py` |
| This documentation | `docs/mangohud.md` |