"""Small per-game configuration fixes.

Currently just Ultratron's XB360 control mapping
(utilities/ultratron-controls-xb360.sh). The other game-specific bash fixes
in the original repo (Rise of the Tomb Raider's Nvidia/Vulkan package
purge, the Rocket League gamepad DLL patcher) targeted long-obsolete
setups and were retired rather than ported -- see the conversion tracking
issue.
"""

from __future__ import annotations

import logging
import os
import tempfile
from pathlib import Path

from steamostools.process import run

logger = logging.getLogger("steamostools.game_fixes")

ULTRATRON_CONFIG = Path("/home/steam/.ultratron_3.03/controls.txt")

ULTRATRON_CONTROLS = """#Controller configuration
controller2.axis.4=fireaxis
controller2.button.7=start
controller2.axis.4=aimX
controller2.button.6=back
controller2.axis.5=aimY
controller2.button.5=action
controller2.button.4=firebutton
controller2.axis.1=moveX
controller2.axis.2=moveY
controller2=device1
controller1=device0
controller1.axis.4=fireaxis
controller1.button.7=start
controller1.axis.4=aimX
controller1.button.6=back
controller1.axis.5=aimY
controller1.button.5=action
controller1.button.4=firebutton
controller1.axis.1=moveX
controller1.axis.2=moveY
device0=Generic X-Box pad
device1=Generic X-Box pad
"""


def apply_ultratron_xb360_fix(config_path: Path = ULTRATRON_CONFIG) -> None:
    """Overwrite Ultratron's controls.txt with a working XB360 gamepad
    mapping, keeping a .bak of whatever was there before."""
    if config_path.exists():
        run(["sudo", "cp", str(config_path), f"{config_path}.bak"])

    fd, tmp_name = tempfile.mkstemp(suffix=".txt")
    tmp_path = Path(tmp_name)
    os.close(fd)
    tmp_path.write_text(ULTRATRON_CONTROLS)

    run(["sudo", "mv", str(tmp_path), str(config_path)])
    run(["sudo", "chmod", "611", str(config_path)])
    run(["sudo", "chown", "steam:steam", str(config_path)])
    logger.info("Wrote Ultratron XB360 control mapping to %s", config_path)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("game-fix", help="apply small per-game configuration fixes")
    sub = parser.add_subparsers(dest="game_fix_command", required=True)
    ultratron = sub.add_parser("ultratron", help="fix Ultratron's XB360 control mapping")
    ultratron.add_argument("--config-path", type=Path, default=ULTRATRON_CONFIG)
    ultratron.set_defaults(func=_cmd_ultratron)


def _cmd_ultratron(args) -> int:
    apply_ultratron_xb360_fix(args.config_path)
    return 0
