"""Binary Steam shortcuts.vdf read/write.

Steam's shortcuts.vdf is not the human-readable text KeyValues format
(that's config.vdf/libraryfolders.vdf -- see steamostools.vdf.textvdf).
It's a separate binary format using \\x00/\\x01/\\x02/\\x08 type/section
markers. This implements just enough of it to add, remove, and list
non-Steam-game shortcut entries -- not a general-purpose binary VDF parser
-- which is all app-image-manager.sh and update-software.sh needed (they
each shelled out to an inline python3 heredoc implementing this exact
same logic, duplicated between the two scripts).
"""

from __future__ import annotations

import re
import shutil
import struct
import time
import zlib
from pathlib import Path

HEADER = b"\x00shortcuts\x00"
FOOTER = b"\x08\x08"

DEFAULT_STEAM_USERDATA_DIRS = (
    Path.home() / ".local" / "share" / "Steam" / "userdata",
    Path.home() / ".steam" / "steam" / "userdata",
    Path.home() / ".steam" / "root" / "userdata",
)


class ShortcutsVdfFormatError(RuntimeError):
    pass


class ShortcutNotFoundError(LookupError):
    pass


def generate_appid(exe: str, name: str) -> int:
    """Matches Steam's CRC-based non-Steam appid algorithm."""
    key = exe + name
    top = zlib.crc32(key.encode("utf-8")) | 0x80000000
    return top & 0xFFFFFFFF


def _pack_str(key: str, value: str) -> bytes:
    return b"\x01" + key.encode() + b"\x00" + value.encode() + b"\x00"


def _pack_int(key: str, value: int) -> bytes:
    return b"\x02" + key.encode() + b"\x00" + struct.pack("<I", value)


def build_entry(index: int, app_name: str, exe: str, start_dir: str, icon: str) -> bytes:
    appid = generate_appid(exe, app_name)
    return (
        b"\x00" + str(index).encode() + b"\x00"
        + _pack_int("appid", appid)
        + _pack_str("AppName", app_name)
        + _pack_str("Exe", exe)
        + _pack_str("StartDir", start_dir)
        + _pack_str("icon", icon)
        + _pack_str("ShortcutPath", "")
        + _pack_str("LaunchOptions", "")
        + _pack_int("IsHidden", 0)
        + _pack_int("AllowDesktopConfig", 1)
        + _pack_int("AllowOverlay", 1)
        + _pack_int("OpenVR", 0)
        + _pack_int("Devkit", 0)
        + _pack_str("DevkitGameID", "")
        + _pack_int("DevkitOverrideAppID", 0)
        + _pack_int("LastPlayTime", int(time.time()))
        + _pack_str("FlatpakAppID", "")
        + b"\x00tags\x00\x08\x08"
    )


def load_or_init(vdf_path: Path) -> bytes:
    if vdf_path.exists() and vdf_path.stat().st_size > 4:
        return vdf_path.read_bytes()
    return HEADER + FOOTER


def has_app(data: bytes, app_name: str) -> bool:
    return app_name.encode() in data


def count_entries(data: bytes) -> int:
    return len(re.findall(rb"\x00(\d+)\x00", data))


def _backup(vdf_path: Path) -> None:
    if vdf_path.exists():
        shutil.copy2(vdf_path, vdf_path.parent / f"{vdf_path.name}.bak")


def add_shortcut(vdf_path: Path, app_name: str, exe: str, start_dir: str, icon: str = "") -> bool:
    """Add a non-Steam-game shortcut entry to vdf_path. Returns False
    (no-op) if an entry with this AppName already exists -- an existing
    shortcut is a legitimate "nothing to do" outcome, not an error.
    Backs up the existing file to <path>.bak before writing."""
    data = load_or_init(vdf_path)
    if has_app(data, app_name):
        return False

    entry = build_entry(count_entries(data), app_name, exe, start_dir, icon)
    _backup(vdf_path)

    if data.endswith(FOOTER):
        data = data[:-2] + entry + FOOTER
    else:
        data = data + entry + FOOTER

    vdf_path.parent.mkdir(parents=True, exist_ok=True)
    vdf_path.write_bytes(data)
    return True


def remove_shortcut(vdf_path: Path, app_name: str) -> None:
    """Remove a non-Steam-game shortcut entry by AppName. Raises
    ShortcutNotFoundError if no such entry exists, or
    ShortcutsVdfFormatError if the file doesn't look like a valid
    shortcuts.vdf. Backs up to <path>.bak before writing."""
    if not vdf_path.exists():
        raise ShortcutNotFoundError(f"{vdf_path} does not exist")

    data = vdf_path.read_bytes()
    if not data.startswith(HEADER):
        raise ShortcutsVdfFormatError(f"Unexpected shortcuts.vdf format in {vdf_path}")

    needle = b"\x01AppName\x00" + app_name.encode() + b"\x00"
    pos = data.find(needle)
    if pos == -1:
        raise ShortcutNotFoundError(f"'{app_name}' not found in {vdf_path}")

    entry_start = None
    for i in range(pos - 1, len(HEADER) - 1, -1):
        if data[i] == 0x00:
            j = i + 1
            while j < len(data) and 0x30 <= data[j] <= 0x39:
                j += 1
            if j > i + 1 and j < len(data) and data[j] == 0x00:
                entry_start = i
                break
    if entry_start is None:
        raise ShortcutsVdfFormatError("Could not locate entry start")

    tags_pos = data.find(b"\x00tags\x00", pos)
    if tags_pos == -1:
        raise ShortcutsVdfFormatError("Could not locate tags dict")

    entry_end = data.find(FOOTER, tags_pos)
    if entry_end == -1:
        raise ShortcutsVdfFormatError("Could not locate entry end")
    entry_end += len(FOOTER)

    _backup(vdf_path)
    vdf_path.write_bytes(data[:entry_start] + data[entry_end:])


def find_shortcuts_vdf_files(userdata_dirs: tuple[Path, ...] = DEFAULT_STEAM_USERDATA_DIRS) -> list[Path]:
    """Find all shortcuts.vdf files across possible Steam userdata roots
    (handles multiple linked accounts, and Steam's several possible
    install-path conventions). Real layout is userdata/<userid>/config/shortcuts.vdf."""
    found = set()
    for root in userdata_dirs:
        if not root.is_dir():
            continue
        for vdf in root.glob("*/*/shortcuts.vdf"):
            found.add(vdf.resolve())
    return sorted(found)
