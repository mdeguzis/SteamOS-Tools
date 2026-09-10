"""Fix PS4 controller Bluetooth wake-from-sleep on Bazzite HTPC setups.

Port of utilities/controllers/install-ps4-wake-on-usb.sh. Bazzite/Fedora
ostree specific (rpm-ostree kargs, /etc/bluetooth/main.conf) -- does not
apply to Arch-based SteamOS, unlike most of the rest of this package.
"""

from __future__ import annotations

import logging
from pathlib import Path

from steamostools.platform_detect import Platform, require_platform
from steamostools.process import run

logger = logging.getLogger("steamostools.ps4_wake")

UDEV_RULE_PATH = Path("/etc/udev/rules.d/90-ps4-controller-wake.rules")
UDEV_RULE_CONTENT = (
    '# Enable wake for Intel Bluetooth (Bus 1, Port 14)\n'
    'ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="8087", ATTR{power/wakeup}="enabled"\n\n'
    '# Enable wake for the parent root hub (Bus 1)\n'
    'ACTION=="add", SUBSYSTEM=="usb", KERNEL=="usb1", ATTR{power/wakeup}="enabled"\n'
)
REQUIRED_KARGS = ("mem_sleep_default=deep", "pcie_port_pm=off")
ACPI_WAKEUP_PATH = Path("/proc/acpi/wakeup")
BLUETOOTH_CONF = Path("/etc/bluetooth/main.conf")
NOISY_ACPI_TRIGGERS = ("XHCI", "AWAC")


def missing_kargs(current_kargs: str) -> list[str]:
    return [k for k in REQUIRED_KARGS if k not in current_kargs]


def apply_kernel_args() -> list[str]:
    """Append any missing required kernel args via rpm-ostree. Returns the
    args actually added (empty means already configured -- a reboot is
    only needed when this is non-empty)."""
    result = run(["rpm-ostree", "kargs"])
    missing = missing_kargs(result.stdout)
    for karg in missing:
        run(["sudo", "rpm-ostree", "kargs", f"--append={karg}"])
        logger.info("Added kernel arg: %s", karg)
    return missing


def install_udev_rule(rule_path: Path = UDEV_RULE_PATH) -> None:
    rule_path.parent.mkdir(parents=True, exist_ok=True)
    rule_path.write_text(UDEV_RULE_CONTENT)
    run(["sudo", "udevadm", "control", "--reload-rules"])
    run(["sudo", "udevadm", "trigger"])
    logger.info("Installed udev rule at %s", rule_path)


def disable_noisy_acpi_triggers(acpi_wakeup_path: Path = ACPI_WAKEUP_PATH) -> list[str]:
    """Disable ACPI wake triggers known to cause spurious wakeups. Returns
    the triggers actually disabled -- already-disabled or missing triggers
    are skipped, which is a legitimate outcome, not an error."""
    if not acpi_wakeup_path.exists():
        return []
    text = acpi_wakeup_path.read_text()
    disabled = []
    for trigger in NOISY_ACPI_TRIGGERS:
        if any(trigger in line and "enabled" in line for line in text.splitlines()):
            run(["sudo", "bash", "-c", f"echo {trigger} > {acpi_wakeup_path}"])
            disabled.append(trigger)
            logger.info("Disabled ACPI wake trigger: %s", trigger)
        else:
            logger.debug("ACPI trigger %s already disabled or not found", trigger)
    return disabled


def enable_bluetooth_fast_connectable(bluetooth_conf: Path = BLUETOOTH_CONF) -> None:
    if not bluetooth_conf.exists():
        logger.warning("%s not found, skipping FastConnectable setting", bluetooth_conf)
        return
    run(["sudo", "sed", "-i", r"s/^#\(FastConnectable = \).*/\1true/", str(bluetooth_conf)])
    run(["sudo", "sed", "-i", r"s/^\(FastConnectable = \).*/\1true/", str(bluetooth_conf)])
    logger.info("Enabled Bluetooth FastConnectable in %s", bluetooth_conf)


def apply_ps4_wake_fix() -> dict:
    require_platform(Platform.BAZZITE_OSTREE)
    added_kargs = apply_kernel_args()
    install_udev_rule()
    disabled_triggers = disable_noisy_acpi_triggers()
    enable_bluetooth_fast_connectable()
    return {"added_kargs": added_kargs, "disabled_triggers": disabled_triggers}


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "ps4-wake", help="fix PS4 controller Bluetooth wake-from-sleep on Bazzite HTPC setups"
    )
    sub = parser.add_subparsers(dest="ps4_wake_command", required=True)
    sub.add_parser("apply", help="apply kernel args, udev rule, ACPI, and Bluetooth fixes").set_defaults(
        func=_cmd_apply
    )


def _cmd_apply(args) -> int:
    result = apply_ps4_wake_fix()
    if result["added_kargs"]:
        logger.warning(
            "Kernel args changed (%s) -- a reboot is required", ", ".join(result["added_kargs"])
        )
    return 0
