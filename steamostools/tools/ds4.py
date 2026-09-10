"""Configure DualShock 4 LED behavior.

Port of utilities/ds4-tools/ds4-led-control.sh (+ its companion
ds4-udev.rule template). Two independent mechanisms, matching the
original: `install` wires up automatic LED color on device-add via udev
(delegating to an external `/usr/local/bin/ds4led` helper -- not part of
this repo, must already be installed on the system), while `set-led` pokes
the sysfs LED brightness files directly for a one-off manual color change.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.ds4")

UDEV_RULE_PATH = Path("/etc/udev/rules.d/10-local-ds4.rules")
UDEV_RULE_TEMPLATE = (
    'ACTION=="add", SUBSYSTEM=="input", ATTRS{{uniq}}=="{device_id}" '
    'RUN+="/usr/local/bin/ds4led \'%p\' 000100"\n'
)
LEDS_SYSFS_ROOT = Path("/sys/class/leds")
LED_NAME_RE = re.compile(r"^[0-9a-f]{4}:[0-9a-f]{4}:[0-9a-f]{4}\.[0-9a-f]{4}$")


class DeviceNotFoundError(RuntimeError):
    pass


def get_js0_device_id() -> str:
    """Read the ATTRS{phys} value for /dev/input/js0, used as the udev
    match key. Raises DeviceNotFoundError if js0 isn't present or the
    attribute can't be found -- matching the original script's implicit
    assumption that a DS4 is already connected."""
    path_result = run(["udevadm", "info", "-q", "path", "-n", "/dev/input/js0"])
    device_path = path_result.stdout.strip()
    info = run(["udevadm", "info", "-a", "-p", device_path])
    for line in info.stdout.splitlines():
        if "ATTRS{phys}" in line:
            return line.split("==", 1)[1].strip().strip('"')
    raise DeviceNotFoundError("Could not determine phys attribute for /dev/input/js0")


def render_udev_rule(device_id: str) -> str:
    return UDEV_RULE_TEMPLATE.format(device_id=device_id)


def install_udev_rule(device_id: str, *, rule_path: Path = UDEV_RULE_PATH) -> None:
    rule_path.parent.mkdir(parents=True, exist_ok=True)
    rule_path.write_text(render_udev_rule(device_id))
    logger.info("Installed udev rule for device %s at %s", device_id, rule_path)


def find_led_name(leds_root: Path = LEDS_SYSFS_ROOT) -> str | None:
    if not leds_root.is_dir():
        return None
    for entry in leds_root.iterdir():
        if entry.name.endswith(":global") and LED_NAME_RE.match(entry.name[: -len(":global")]):
            return entry.name[: -len(":global")]
    return None


def set_led_color(rgb_hex: str, *, leds_root: Path = LEDS_SYSFS_ROOT) -> None:
    """Set the DS4's LED to an RRGGBB hex color via direct sysfs writes.
    Raises DeviceNotFoundError if no DS4 LED device is found."""
    led_name = find_led_name(leds_root)
    if led_name is None:
        raise DeviceNotFoundError("No DS4 LED device found under /sys/class/leds")

    red, green, blue = int(rgb_hex[0:2], 16), int(rgb_hex[2:4], 16), int(rgb_hex[4:6], 16)
    for channel, value in (("red", red), ("green", green), ("blue", blue)):
        (leds_root / f"{led_name}:{channel}" / "brightness").write_text(str(value))
    logger.info("Set DS4 LED %s to #%s", led_name, rgb_hex)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("ds4", help="DualShock 4 LED control")
    sub = parser.add_subparsers(dest="ds4_command", required=True)

    install = sub.add_parser(
        "install", help="install the udev rule that auto-sets LED color on connect"
    )
    install.set_defaults(func=_cmd_install)

    set_led = sub.add_parser("set-led", help="manually set the DS4 LED color via sysfs")
    set_led.add_argument("color", help="6-digit hex color, e.g. ff0000")
    set_led.set_defaults(func=_cmd_set_led)


def _cmd_install(args) -> int:
    device_id = get_js0_device_id()
    install_udev_rule(device_id)
    return 0


def _cmd_set_led(args) -> int:
    set_led_color(args.color)
    return 0
