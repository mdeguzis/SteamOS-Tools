"""Collect a Steam-style hardware/system diagnostic report.

Port of utilities/protondb-systeminfo-tool.sh (originally sourced from
ChimeraOS, per the original script's own credit comment). Produces the
same text block format as Steam's own System Information dialog (the
format ProtonDB bug reports ask for), plus a --json output for
programmatic use -- the parsing logic here is organized as small pure
functions over raw command output specifically so it's testable without
needing real hardware or a display.
"""

from __future__ import annotations

import json
import logging
import re
import shutil
from dataclasses import asdict, dataclass, field
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.systeminfo")

UNKNOWN = "Unknown"

CPU_FLAG_LABELS = [
    ("ht", "HyperThreading"), ("cmov", "FCMOV"), ("sse2", "SSE2"), ("sse3", "SSE3"),
    ("sse4a", "SSE4a"), ("sse4_1", "SSE41"), ("sse4_2", "SSE42"), ("aes", "AES"),
    ("avx", "AVX"), ("avx2", "AVX2"), ("avx512f", "AVX512F"), ("avx512pf", "AVX512PF"),
    ("avx512er", "AVX512ER"), ("avx512cd", "AVX512CD"), ("avx512_vnni", "AVX512VNNI"),
    ("sha_ni", "SHA"), ("cx16", "CMPXCHG16B"), ("lahf_lm", "LAHF/SAHF"), ("prefetch", "PrefetchW"),
]


# ---------------------------------------------------------------------------
# Small helpers for degrading gracefully -- an optional diagnostic tool being
# missing is not a fatal error for the whole report, it just leaves that
# field "Unknown" (matching Steam's own System Information dialog).
# ---------------------------------------------------------------------------


def run_text(cmd: list[str]) -> str:
    if shutil.which(cmd[0]) is None:
        logger.debug("%s not available, skipping", cmd[0])
        return ""
    result = run(cmd, check=False)
    return result.stdout


def read_text(path: Path) -> str:
    try:
        return path.read_text(errors="replace")
    except OSError:
        return ""


# ---------------------------------------------------------------------------
# /proc/cpuinfo parsing
# ---------------------------------------------------------------------------


def parse_cpuinfo_field(cpuinfo_text: str, field_name: str) -> str:
    for line in cpuinfo_text.splitlines():
        key, sep, value = line.partition(":")
        if sep and key.strip() == field_name:
            return value.strip()
    return ""


def parse_cpu_flags(cpuinfo_text: str) -> set[str]:
    flags_line = parse_cpuinfo_field(cpuinfo_text, "flags")
    return set(flags_line.split()) if flags_line else set()


def cpu_flag_report(flags: set[str]) -> dict[str, bool]:
    return {label: flag in flags for flag, label in CPU_FLAG_LABELS}


def _hex_field(cpuinfo_text: str, field_name: str) -> str:
    raw = parse_cpuinfo_field(cpuinfo_text, field_name)
    if not raw.isdigit():
        return UNKNOWN
    return f"0x{int(raw):x}"


# ---------------------------------------------------------------------------
# glxinfo / xdpyinfo / xrandr parsing
# ---------------------------------------------------------------------------


def parse_glxinfo_field(glxinfo_text: str, label: str) -> str:
    for line in glxinfo_text.splitlines():
        if label in line:
            return line.split(":", 1)[1].strip()
    return UNKNOWN


def parse_xdpyinfo_field(xdpyinfo_text: str, label: str) -> str | None:
    for line in xdpyinfo_text.splitlines():
        if label in line:
            return line.split(":", 1)[1].strip()
    return None


def parse_xdpyinfo_color_depth(xdpyinfo_text: str) -> str:
    line = parse_xdpyinfo_field(xdpyinfo_text, "depth of root window:")
    if not line:
        return "24"
    m = re.search(r"(\d+)", line)
    return m.group(1) if m else "24"


def parse_xdpyinfo_resolution(xdpyinfo_text: str) -> str:
    line = parse_xdpyinfo_field(xdpyinfo_text, "dimensions:")
    if not line:
        return UNKNOWN
    m = re.search(r"(\d+x\d+)", line)
    return m.group(1).replace("x", " x ") if m else UNKNOWN


def parse_refresh_rate(xrandr_text: str) -> str:
    m = re.search(r"(\d\d\.\d\d)\*", xrandr_text)
    return m.group(1).split(".")[0] if m else UNKNOWN


def parse_num_monitors(xrandr_listmonitors_text: str) -> str:
    first_line = xrandr_listmonitors_text.splitlines()[0] if xrandr_listmonitors_text else ""
    if ":" not in first_line:
        return UNKNOWN
    return first_line.split(":", 1)[1].strip()


def parse_primary_display_size(xrandr_text: str) -> str:
    """Physical diagonal size in inches from xrandr's mm dimensions,
    preferring the primary monitor but falling back to any connected one
    if the primary is disconnected in a multi-monitor setup."""
    for pattern in (r"^\S+ connected primary.*?(\d+)mm x (\d+)mm", r"^\S+ connected.*?(\d+)mm x (\d+)mm"):
        m = re.search(pattern, xrandr_text, re.MULTILINE)
        if m:
            width_mm, height_mm = int(m.group(1)), int(m.group(2))
            diag_in = ((width_mm / 10) ** 2 + (height_mm / 10) ** 2) ** 0.5 / 2.54
            return f'{diag_in:.2f}" (diag)'
    return UNKNOWN


# ---------------------------------------------------------------------------
# udevadm / touchscreen detection
# ---------------------------------------------------------------------------


def detect_touch_input(udevadm_text: str) -> str:
    if "ID_INPUT_TOUCHSCREEN=1" not in udevadm_text:
        return "No Touch Input Detected"
    for block in udevadm_text.split("\n\n"):
        if "ID_INPUT_TOUCHSCREEN=1" not in block:
            continue
        for line in block.splitlines():
            if line.startswith("E: NAME="):
                name = line.split("=", 1)[1].strip().strip('"')
                return f"Touch Input Detected: {name}"
    return "Touch Input Detected"


# ---------------------------------------------------------------------------
# VGA / PCI
# ---------------------------------------------------------------------------


def parse_vga_pci_id(lspci_vga_text: str) -> tuple[str, str]:
    m = re.search(r"([0-9a-fA-F]{4}):([0-9a-fA-F]{4})", lspci_vga_text)
    if not m:
        return UNKNOWN, UNKNOWN
    return f"0x{m.group(1)}", f"0x{m.group(2)}"


# ---------------------------------------------------------------------------
# lsblk storage classification
# ---------------------------------------------------------------------------


def classify_storage(devices: list[dict]) -> tuple[int, int]:
    """Count non-USB block devices as SSD or HDD based on their rotational
    flag. `devices` is lsblk's parsed `--json` "blockdevices" list.

    The original script parsed whitespace-delimited `lsblk` text by column
    position (`awk '{print $2}'`/`'{print $3}'`), which silently misreads
    every field after `tran` is empty -- a common case for NVMe drives, whose
    transport column lsblk leaves blank. `--json` sidesteps that ambiguity
    entirely, so this is a correctness fix, not just a straight port."""
    ssd = hdd = 0
    for dev in devices:
        if dev.get("tran") == "usb":
            continue
        rota = dev.get("rota")
        if rota is True or rota in ("1", 1):
            hdd += 1
        else:
            ssd += 1
    return ssd, hdd


def parse_lscpu_max_mhz(lscpu_text: str) -> str:
    for line in lscpu_text.splitlines():
        if "CPU max MHz" in line:
            value = line.split(":", 1)[1].strip()
            return value.split(".")[0]
    return UNKNOWN


def parse_pulsemixer_default_sink(pulsemixer_text: str) -> str:
    for line in pulsemixer_text.splitlines():
        if "Default" not in line:
            continue
        fields = line.split(",")
        if len(fields) < 2:
            continue
        return fields[1].replace("Name:", "").strip()
    return UNKNOWN


def parse_df_output(df_text: str) -> str:
    lines = [line.strip() for line in df_text.splitlines() if line.strip()]
    if len(lines) < 2:
        return UNKNOWN
    return lines[-1].rstrip("M").strip()


def detect_window_manager() -> str:
    if run(["pidof", "-q", "gamescope"], check=False).returncode == 0:
        return "Gamescope"
    if run(["pidof", "-q", "steamcompmgr"], check=False).returncode == 0:
        return "Steam"
    return UNKNOWN


def detect_steam_runtime_version(steam_common_dir: Path) -> str:
    if not steam_common_dir.is_dir():
        return "None"
    for os_release in steam_common_dir.glob("SteamLinuxRuntime*/var/tmp-*/usr/lib/os-release"):
        text = read_text(os_release)
        m = re.search(r'BUILD_ID="([^"]+)"', text)
        if m:
            return f"steam-runtime_{m.group(1)}"
    return "None"


# ---------------------------------------------------------------------------
# Top-level report
# ---------------------------------------------------------------------------


@dataclass
class SystemInfo:
    manufacturer: str = UNKNOWN
    model: str = UNKNOWN
    form_factor: str = UNKNOWN
    touch_input: str = "No Touch Input Detected"
    cpu_vendor: str = UNKNOWN
    cpu_name: str = UNKNOWN
    cpu_family: str = UNKNOWN
    cpu_model: str = UNKNOWN
    cpu_stepping: str = UNKNOWN
    cpu_logical: int = 0
    cpu_physical: str = UNKNOWN
    cpu_speed_mhz: str = UNKNOWN
    cpu_flags: dict[str, bool] = field(default_factory=dict)
    os_pretty_name: str = UNKNOWN
    kernel_name: str = UNKNOWN
    kernel_version: str = UNKNOWN
    x_server_vendor: str = UNKNOWN
    x_server_release: str = UNKNOWN
    window_manager: str = UNKNOWN
    steam_runtime_version: str = "None"
    opengl_renderer: str = UNKNOWN
    opengl_version_long: str = UNKNOWN
    opengl_version_short: str = UNKNOWN
    color_depth: str = "24"
    desktop_resolution: str = UNKNOWN
    refresh_rate_hz: str = UNKNOWN
    vga_vendor_id: str = UNKNOWN
    vga_device_id: str = UNKNOWN
    num_monitors: str = UNKNOWN
    num_video_cards: str = UNKNOWN
    primary_display_size: str = UNKNOWN
    primary_vram: str = UNKNOWN
    audio_device: str = UNKNOWN
    ram_mb: int = 0
    disk_size_mb: str = UNKNOWN
    disk_avail_mb: str = UNKNOWN
    num_ssd: int = 0
    num_hdd: int = 0

    def to_dict(self) -> dict:
        return asdict(self)

    def to_json(self, *, indent: int = 2) -> str:
        return json.dumps(self.to_dict(), indent=indent)

    def to_report(self) -> str:
        flags_text = "\n".join(
            f"    {label}:  {'Supported' if supported else 'Unsupported'}"
            for label, supported in self.cpu_flags.items()
        )
        return f"""
Computer Information:
    Manufacturer:  {self.manufacturer}
    Model:  {self.model}
    Form Factor: {self.form_factor}
    {self.touch_input}

Processor Information:
    CPU Vendor:  {self.cpu_vendor}
    CPU Brand:  {self.cpu_name}
    CPU Family:  {self.cpu_family}
    CPU Model:  {self.cpu_model}
    CPU Stepping  {self.cpu_stepping}
    Speed:  {self.cpu_speed_mhz} Mhz
    {self.cpu_logical} logical processors
    {self.cpu_physical} physical processors
{flags_text}

Operating System Version:
    {self.os_pretty_name}
    Kernel Name:  {self.kernel_name}
    Kernel Version:  {self.kernel_version}
    X Server Vendor:  {self.x_server_vendor}
    X Server Release:  {self.x_server_release}
    X Window Manager:  {self.window_manager}
    Steam Runtime Version:  {self.steam_runtime_version}

Video Card:
    Driver:  {self.opengl_renderer}
    Driver Version:  {self.opengl_version_long}
    OpenGL Version: {self.opengl_version_short}
    Desktop Color Depth: {self.color_depth} bits per pixel
    Monitor Refresh Rate: {self.refresh_rate_hz} Hz
    VendorID:  {self.vga_vendor_id}
    DeviceID:  {self.vga_device_id}
    Number of Monitors:  {self.num_monitors}
    Number of Logical Video Cards:  {self.num_video_cards}
    Desktop Resolution: {self.desktop_resolution}
    Primary Display Size: {self.primary_display_size}
    Primary VRAM: {self.primary_vram}

Sound card:
    Audio device: {self.audio_device}

Memory:
    RAM:  {self.ram_mb} MB

Miscellaneous:
    Total Hard Disk Space Available:  {self.disk_size_mb} MB
    Largest Free Hard Disk Block:  {self.disk_avail_mb} MB

Storage:
    Number of SSDs: {self.num_ssd}
    Number of HDDs: {self.num_hdd}
"""


def collect_system_info(steam_common_dir: Path | None = None) -> SystemInfo:
    """Gather the full report by shelling out to the same diagnostic tools
    the original script used. Any individual tool being unavailable
    degrades that field to "Unknown" rather than aborting the whole
    report."""
    steam_common_dir = steam_common_dir or (Path.home() / ".local" / "share" / "Steam" / "steamapps" / "common")

    cpuinfo_text = read_text(Path("/proc/cpuinfo"))
    glxinfo_text = run_text(["glxinfo"])
    xdpyinfo_text = run_text(["xdpyinfo"])
    xrandr_text = run_text(["xrandr"])
    xrandr_monitors_text = run_text(["xrandr", "--listmonitors"])
    udevadm_text = run_text(["udevadm", "info", "--export-db"])
    os_release_text = read_text(Path("/etc/os-release"))
    meminfo_text = read_text(Path("/proc/meminfo"))
    lsblk_json_text = run_text(
        ["lsblk", "--nodeps", "--output", "name,tran,rota", "--exclude", "7", "--json"]
    )
    try:
        lsblk_devices = json.loads(lsblk_json_text)["blockdevices"] if lsblk_json_text else []
    except (json.JSONDecodeError, KeyError):
        lsblk_devices = []

    flags = parse_cpu_flags(cpuinfo_text)
    ssd, hdd = classify_storage(lsblk_devices)

    os_pretty_match = re.search(r'PRETTY_NAME="([^"]+)"', os_release_text)

    ram_kb_text = parse_cpuinfo_field(meminfo_text, "MemTotal")  # "123456 kB"
    ram_kb = int(ram_kb_text.split()[0]) if ram_kb_text and ram_kb_text.split()[0].isdigit() else 0

    info = SystemInfo(
        manufacturer=read_text(Path("/sys/devices/virtual/dmi/id/board_vendor")).strip() or UNKNOWN,
        model=read_text(Path("/sys/devices/virtual/dmi/id/board_name")).strip() or UNKNOWN,
        form_factor=run_text(["hostnamectl", "chassis"]).strip() or UNKNOWN,
        touch_input=detect_touch_input(udevadm_text),
        cpu_vendor=parse_cpuinfo_field(cpuinfo_text, "vendor_id"),
        cpu_name=parse_cpuinfo_field(cpuinfo_text, "model name"),
        cpu_family=_hex_field(cpuinfo_text, "cpu family"),
        cpu_model=_hex_field(cpuinfo_text, "model"),
        cpu_stepping=_hex_field(cpuinfo_text, "stepping"),
        cpu_logical=int(run_text(["nproc", "--all"]).strip() or 0),
        cpu_physical=parse_cpuinfo_field(cpuinfo_text, "cpu cores") or UNKNOWN,
        cpu_speed_mhz=parse_lscpu_max_mhz(run_text(["lscpu"])),
        cpu_flags=cpu_flag_report(flags),
        os_pretty_name=os_pretty_match.group(1) if os_pretty_match else UNKNOWN,
        kernel_name=run_text(["uname"]).strip() or UNKNOWN,
        kernel_version=run_text(["uname", "-r"]).strip() or UNKNOWN,
        x_server_vendor=parse_xdpyinfo_field(xdpyinfo_text, "vendor string:") or UNKNOWN,
        x_server_release=parse_xdpyinfo_field(xdpyinfo_text, "vendor release number:") or UNKNOWN,
        window_manager=detect_window_manager(),
        steam_runtime_version=detect_steam_runtime_version(steam_common_dir),
        opengl_renderer=parse_glxinfo_field(glxinfo_text, "OpenGL renderer string:"),
        opengl_version_long=parse_glxinfo_field(glxinfo_text, "OpenGL version string:"),
        opengl_version_short=parse_glxinfo_field(glxinfo_text, "OpenGL version string:")[:3],
        color_depth=parse_xdpyinfo_color_depth(xdpyinfo_text),
        desktop_resolution=parse_xdpyinfo_resolution(xdpyinfo_text),
        refresh_rate_hz=parse_refresh_rate(xrandr_text),
        vga_vendor_id=parse_vga_pci_id(run_text(["lspci", "-nd", "::0300"]))[0],
        vga_device_id=parse_vga_pci_id(run_text(["lspci", "-nd", "::0300"]))[1],
        num_monitors=parse_num_monitors(xrandr_monitors_text),
        num_video_cards=str(run_text(["lspci"]).count(" VGA ")),
        primary_display_size=parse_primary_display_size(xrandr_text),
        primary_vram=parse_glxinfo_field(glxinfo_text, "Dedicated video memory:"),
        audio_device=parse_pulsemixer_default_sink(run_text(["pulsemixer", "--list-sinks"])),
        ram_mb=ram_kb // 1024,
        disk_size_mb=parse_df_output(
            run_text(["df", "-h", "--output=size", "--block-size", "M", str(Path.home())])
        ),
        disk_avail_mb=parse_df_output(
            run_text(["df", "-h", "--output=avail", "--block-size", "M", str(Path.home())])
        ),
        num_ssd=ssd,
        num_hdd=hdd,
    )
    return info


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "systeminfo", help="collect a Steam-style hardware/system diagnostic report"
    )
    parser.add_argument("--json", action="store_true", help="output JSON instead of the text report")
    parser.set_defaults(func=_cmd_systeminfo)


def _cmd_systeminfo(args) -> int:
    info = collect_system_info()
    if args.json:
        print(info.to_json())
    else:
        print(info.to_report())
    return 0
