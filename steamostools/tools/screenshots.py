"""Sync Steam screenshots to a cloud remote via rclone.

Port of utilities/steam-screenshot-sync/{sync-screenshots.sh,symlink-screenshots.sh}.
utilities/gdrive-path-sync/* was a byte-identical/near-duplicate of these two
scripts and was deleted rather than ported (see conversion tracking issue).

Two steps, matching the original two scripts:
  link  -- flatten Steam's per-appid screenshot dirs into one flat directory
           of symlinks (rclone can't sync a "flattened" view of a nested
           tree directly), pruning local files the remote no longer has
           and cleaning up broken symlinks.
  sync  -- rclone-sync that flat directory to the remote.

A file lock prevents `sync` from running concurrently with `link` on the
same source directory (mutating it mid-sync could desync local/remote).
"""

from __future__ import annotations

import contextlib
import fcntl
import logging
import shutil
import time
from dataclasses import dataclass, field
from pathlib import Path

from steamostools.rclone_sync import RcloneRemoteTarget, RcloneSync
from steamostools.systemd_units import SystemdUserUnit

logger = logging.getLogger("steamostools.screenshots")

SOURCE_DIR = Path.home() / ".steam-screenshots"
BACKUP_DIR = Path.home() / ".steam-screenshots-backup"
STEAM_USERDATA_DIR = Path.home() / ".local" / "share" / "Steam" / "userdata"
BACKUP_RETENTION_DAYS = 180
LOCK_PATH = Path.home() / ".cache" / "steamos-tools" / "screenshots.lock"

DEFAULT_REMOTE = RcloneRemoteTarget(remote_name="gphoto", remote_path="album/Steam-screenshots")

UNIT_PREFIX = "steamos-tools-screenshots"


class LinkInProgressError(RuntimeError):
    pass


@contextlib.contextmanager
def _lock(*, blocking: bool):
    LOCK_PATH.parent.mkdir(parents=True, exist_ok=True)
    with LOCK_PATH.open("w") as f:
        flags = fcntl.LOCK_EX if blocking else (fcntl.LOCK_EX | fcntl.LOCK_NB)
        try:
            fcntl.flock(f, flags)
        except BlockingIOError:
            raise LinkInProgressError(
                "screenshots link is already running against this source directory"
            ) from None
        try:
            yield
        finally:
            fcntl.flock(f, fcntl.LOCK_UN)


@dataclass
class LinkResult:
    linked: list[Path] = field(default_factory=list)
    pruned_deleted_remote: list[Path] = field(default_factory=list)
    pruned_broken_symlinks: list[Path] = field(default_factory=list)
    pruned_old_backups: list[Path] = field(default_factory=list)


def _iter_screenshot_dirs(steam_userdata_dir: Path):
    if not steam_userdata_dir.is_dir():
        return
    for d in steam_userdata_dir.rglob("screenshots"):
        if d.is_dir() and "thumbnails" not in d.parts:
            yield d


def prune_deleted_from_remote(source_dir: Path, backup_dir: Path, remote_files: list[str]) -> list[Path]:
    """Crude "sync back" for remote-side deletions: if a local file is no
    longer in the remote listing, back it up and remove it locally so the
    path unit picks up the change and the next sync reflects the deletion
    both ways."""
    remote_set = set(remote_files)
    pruned = []
    for link in sorted(source_dir.glob("*.jpg")):
        if link.name in remote_set:
            continue
        backup_dir.mkdir(parents=True, exist_ok=True)
        real_target = link.resolve()
        if real_target.exists():
            shutil.copy2(real_target, backup_dir / link.name)
            real_target.unlink()
        link.unlink(missing_ok=True)
        pruned.append(link)
        logger.info("Pruned %s (not present in remote listing)", link.name)
    return pruned


def link_new_screenshots(source_dir: Path, steam_userdata_dir: Path) -> list[Path]:
    source_dir.mkdir(parents=True, exist_ok=True)
    linked = []
    for screenshots_dir in _iter_screenshot_dirs(steam_userdata_dir):
        for jpg in screenshots_dir.rglob("*.jpg"):
            if "thumbnails" in jpg.parts:
                continue
            link_path = source_dir / jpg.name
            if not link_path.exists():
                link_path.symlink_to(jpg)
                linked.append(link_path)
                logger.debug("Linked %s -> %s", link_path, jpg)
    return linked


def prune_broken_symlinks(source_dir: Path) -> list[Path]:
    pruned = []
    for link in sorted(source_dir.glob("*.jpg")):
        if link.is_symlink() and not link.resolve().exists():
            link.unlink()
            pruned.append(link)
            logger.info("Removed broken symlink %s", link)
    return pruned


def prune_old_backups(backup_dir: Path, *, retention_days: int = BACKUP_RETENTION_DAYS) -> list[Path]:
    if not backup_dir.is_dir():
        return []
    cutoff = time.time() - retention_days * 86400
    pruned = []
    for f in backup_dir.iterdir():
        if f.is_file() and f.stat().st_mtime < cutoff:
            f.unlink()
            pruned.append(f)
    return pruned


def link_screenshots(
    remote: RcloneSync,
    *,
    source_dir: Path = SOURCE_DIR,
    backup_dir: Path = BACKUP_DIR,
    steam_userdata_dir: Path = STEAM_USERDATA_DIR,
) -> LinkResult:
    with _lock(blocking=False):
        source_dir.mkdir(parents=True, exist_ok=True)
        remote_files = remote.list_remote()  # raises on failure -- no listing means we can't safely prune

        result = LinkResult()
        result.pruned_deleted_remote = prune_deleted_from_remote(source_dir, backup_dir, remote_files)
        result.linked = link_new_screenshots(source_dir, steam_userdata_dir)
        result.pruned_broken_symlinks = prune_broken_symlinks(source_dir)
        result.pruned_old_backups = prune_old_backups(backup_dir)
        return result


def sync_screenshots(remote: RcloneSync) -> None:
    with _lock(blocking=True):
        remote.sync()


def _executable() -> str:
    return shutil.which("steamos-tools") or "steamos-tools"


def render_units() -> dict[str, str]:
    exe = _executable()
    return {
        f"{UNIT_PREFIX}-link.service": (
            "[Unit]\nDescription=Symlink Steam screenshots into a flat sync directory\n\n"
            f"[Service]\nType=oneshot\nExecStart={exe} screenshots link\n"
        ),
        f"{UNIT_PREFIX}-link.timer": (
            f"[Unit]\nDescription=Periodically run {UNIT_PREFIX}-link.service\n\n"
            "[Timer]\nOnUnitActiveSec=15min\nOnBootSec=2min\n\n[Install]\nWantedBy=timers.target\n"
        ),
        f"{UNIT_PREFIX}-sync.path": (
            "[Unit]\nDescription=Watch the flat screenshot sync directory for changes\n\n"
            f"[Path]\nPathModified={SOURCE_DIR}\nUnit={UNIT_PREFIX}-sync.service\n\n"
            "[Install]\nWantedBy=paths.target\n"
        ),
        f"{UNIT_PREFIX}-sync.service": (
            "[Unit]\nDescription=Sync screenshots to remote via rclone\n\n"
            f"[Service]\nType=oneshot\nExecStart={exe} screenshots sync\n"
        ),
    }


def install_units() -> SystemdUserUnit:
    unit = SystemdUserUnit(
        [f"{UNIT_PREFIX}-sync.path", f"{UNIT_PREFIX}-link.timer"],
    )
    unit.install(render_units())
    unit.enable_now()
    return unit


def uninstall_units() -> None:
    unit = SystemdUserUnit(
        [
            f"{UNIT_PREFIX}-sync.path",
            f"{UNIT_PREFIX}-sync.service",
            f"{UNIT_PREFIX}-link.timer",
            f"{UNIT_PREFIX}-link.service",
        ],
    )
    unit.uninstall()


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("screenshots", help="sync Steam screenshots to a cloud remote")
    parser.add_argument("--remote-name", default=DEFAULT_REMOTE.remote_name)
    parser.add_argument("--remote-path", default=DEFAULT_REMOTE.remote_path)
    shots_sub = parser.add_subparsers(dest="screenshots_command", required=True)

    shots_sub.add_parser("link", help="flatten Steam screenshots into the sync directory").set_defaults(
        func=_cmd_link
    )
    shots_sub.add_parser("sync", help="rclone-sync the flat directory to the remote").set_defaults(
        func=_cmd_sync
    )
    shots_sub.add_parser("install", help="install systemd --user units for automatic sync").set_defaults(
        func=_cmd_install
    )
    shots_sub.add_parser("uninstall", help="remove the systemd --user units").set_defaults(
        func=_cmd_uninstall
    )


def _remote(args) -> RcloneSync:
    target = RcloneRemoteTarget(remote_name=args.remote_name, remote_path=args.remote_path)
    return RcloneSync(SOURCE_DIR, target, excludes=["**/thumbnails/**"])


def _cmd_link(args) -> int:
    result = link_screenshots(_remote(args))
    logger.info(
        "Linked %d new, pruned %d deleted-remote, %d broken symlinks, %d old backups",
        len(result.linked),
        len(result.pruned_deleted_remote),
        len(result.pruned_broken_symlinks),
        len(result.pruned_old_backups),
    )
    return 0


def _cmd_sync(args) -> int:
    sync_screenshots(_remote(args))
    return 0


def _cmd_install(args) -> int:
    _remote(args).mkdir_remote()
    install_units()
    return 0


def _cmd_uninstall(args) -> int:
    uninstall_units()
    return 0
