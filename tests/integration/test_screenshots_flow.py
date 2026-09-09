"""Integration test for the screenshots tool against fake `rclone` and
`systemctl` binaries on PATH (rather than mocking steamostools.process.run
directly) -- this exercises the real subprocess call boundary."""

import os
import shutil
import stat
from pathlib import Path

import pytest

from steamostools.rclone_sync import RcloneRemoteTarget, RcloneSync
from steamostools.systemd_units import SystemdUserUnit

# Resolve bash's absolute path rather than shebang-ing `/usr/bin/env bash` --
# on Termux, /usr/bin/env doesn't exist at that path, so the shebang itself
# fails to resolve regardless of PATH.
_BASH = shutil.which("bash") or "/bin/bash"


def _make_fake_bin(tmp_path: Path, name: str, script: str) -> Path:
    bin_dir = tmp_path / "fakebin"
    bin_dir.mkdir(exist_ok=True)
    path = bin_dir / name
    path.write_text(f"#!{_BASH}\n{script}\n")
    path.chmod(path.stat().st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH)
    return bin_dir


@pytest.fixture
def fake_rclone_on_path(tmp_path, monkeypatch):
    log_file = tmp_path / "rclone-calls.log"
    script = f'echo "$@" >> "{log_file}"\n' 'if [[ "$1" == "lsf" ]]; then printf "shot1.jpg\\nshot2.jpg\\n"; fi\n' "exit 0"
    bin_dir = _make_fake_bin(tmp_path, "rclone", script)
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")
    return log_file


@pytest.fixture
def fake_systemctl_on_path(tmp_path, monkeypatch):
    log_file = tmp_path / "systemctl-calls.log"
    script = f'echo "$@" >> "{log_file}"\nexit 0'
    bin_dir = _make_fake_bin(tmp_path, "systemctl", script)
    # Prepend without clobbering the rclone fixture's PATH entry if both are used
    monkeypatch.setenv("PATH", f"{bin_dir}:{os.environ['PATH']}")
    return log_file


def test_rclone_sync_hits_real_fake_binary(tmp_path, fake_rclone_on_path):
    target = RcloneRemoteTarget("gphoto", "album/Steam-screenshots")
    sync = RcloneSync(tmp_path / "source", target, excludes=["**/thumbnails/**"])
    sync.check_available()  # would raise RcloneNotAvailableError if the fake binary weren't found
    sync.sync()

    calls = fake_rclone_on_path.read_text()
    assert "sync" in calls
    assert "gphoto:album/Steam-screenshots" in calls


def test_rclone_list_remote_parses_fake_binary_output(tmp_path, fake_rclone_on_path):
    target = RcloneRemoteTarget("gphoto", "album/Steam-screenshots")
    sync = RcloneSync(tmp_path / "source", target)
    assert sync.list_remote() == ["shot1.jpg", "shot2.jpg"]


def test_systemd_unit_install_and_enable_against_fake_systemctl(
    tmp_path, fake_systemctl_on_path
):
    unit_dir = tmp_path / "units"
    unit = SystemdUserUnit(["steamos-tools-screenshots-sync.path"], unit_dir=unit_dir)
    unit.install({"steamos-tools-screenshots-sync.path": "[Unit]\nDescription=test\n"})
    unit.enable_now()

    assert (unit_dir / "steamos-tools-screenshots-sync.path").exists()
    calls = fake_systemctl_on_path.read_text()
    assert "daemon-reload" in calls
    assert "enable --now steamos-tools-screenshots-sync.path" in calls
