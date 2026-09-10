"""Run xboxdrv as a userspace Xbox 360 controller driver.

Port of utilities/xboxdrv.sh. Unloads the kernel xpad driver first since it
conflicts with xboxdrv claiming the device.
"""

from __future__ import annotations

import logging

from steamostools.process import run

logger = logging.getLogger("steamostools.xboxdrv")

DEFAULT_ARGS = [
    "--daemon",
    "--silent",
    "--dbus", "session",
    "--controller-slot", "0",
    "--trigger-as-button",
    "--ui-axismap", "x2=ABS_Z,y2=ABS_RZ",
    "--ui-buttonmap", "A=BTN_B,B=BTN_X,X=BTN_A,TR=BTN_THUMBL,TL=BTN_MODE,GUIDE=BTN_THUMBR",
    "--next-controller",
    "--trigger-as-button",
    "--ui-axismap", "x2=ABS_Z,y2=ABS_RZ",
    "--ui-buttonmap", "A=BTN_B,B=BTN_X,X=BTN_A,TR=BTN_THUMBL,TL=BTN_MODE,GUIDE=BTN_THUMBR",
]


def start_xboxdrv(extra_args: list[str] | None = None) -> None:
    """Unload the xpad kernel module and start the xboxdrv daemon with the
    two-controller remap used by the original script."""
    run(["sudo", "rmmod", "xpad"], check=False)  # not loaded is not a failure
    run(["xboxdrv", *DEFAULT_ARGS, *(extra_args or [])], capture=False)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("xboxdrv", help="run xboxdrv as a userspace Xbox 360 driver")
    sub = parser.add_subparsers(dest="xboxdrv_command", required=True)
    sub.add_parser("start", help="unload xpad and start the xboxdrv daemon").set_defaults(
        func=_cmd_start
    )


def _cmd_start(args) -> int:
    start_xboxdrv()
    return 0
