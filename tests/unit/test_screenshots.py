import fcntl
import os
import time

import pytest

from steamostools.tools import screenshots


class _FakeRemote:
    def __init__(self, remote_files):
        self.remote_files = remote_files
        self.synced = False

    def list_remote(self):
        return self.remote_files

    def sync(self):
        self.synced = True


def test_prune_deleted_from_remote_backs_up_and_removes(tmp_path):
    source = tmp_path / "source"
    backup = tmp_path / "backup"
    source.mkdir()
    real = tmp_path / "real.jpg"
    real.write_text("img")
    link = source / "real.jpg"
    link.symlink_to(real)

    pruned = screenshots.prune_deleted_from_remote(source, backup, remote_files=[])

    assert pruned == [link]
    assert not link.exists()
    assert not real.exists()
    assert (backup / "real.jpg").exists()


def test_prune_deleted_from_remote_keeps_files_present_remotely(tmp_path):
    source = tmp_path / "source"
    backup = tmp_path / "backup"
    source.mkdir()
    real = tmp_path / "real.jpg"
    real.write_text("img")
    link = source / "real.jpg"
    link.symlink_to(real)

    pruned = screenshots.prune_deleted_from_remote(source, backup, remote_files=["real.jpg"])

    assert pruned == []
    assert link.exists()


def test_link_new_screenshots_finds_and_links_excluding_thumbnails(tmp_path):
    userdata = tmp_path / "userdata"
    shots_dir = userdata / "12345" / "760" / "remote" / "999" / "screenshots"
    shots_dir.mkdir(parents=True)
    shot = shots_dir / "shot1.jpg"
    shot.write_text("img")
    thumb_dir = shots_dir / "thumbnails"
    thumb_dir.mkdir()
    (thumb_dir / "shot1.jpg").write_text("thumb")

    source = tmp_path / "source"
    linked = screenshots.link_new_screenshots(source, userdata)

    assert len(linked) == 1
    assert linked[0].name == "shot1.jpg"
    assert linked[0].resolve() == shot.resolve()


def test_link_new_screenshots_skips_already_linked(tmp_path):
    userdata = tmp_path / "userdata"
    shots_dir = userdata / "1" / "screenshots"
    shots_dir.mkdir(parents=True)
    shot = shots_dir / "shot1.jpg"
    shot.write_text("img")

    source = tmp_path / "source"
    source.mkdir()
    (source / "shot1.jpg").symlink_to(shot)

    linked = screenshots.link_new_screenshots(source, userdata)
    assert linked == []


def test_prune_broken_symlinks_removes_dangling_links(tmp_path):
    source = tmp_path / "source"
    source.mkdir()
    target = tmp_path / "gone.jpg"
    target.write_text("x")
    link = source / "gone.jpg"
    link.symlink_to(target)
    target.unlink()

    pruned = screenshots.prune_broken_symlinks(source)

    assert pruned == [link]
    assert not link.exists()


def test_prune_old_backups_removes_files_older_than_retention(tmp_path):
    backup = tmp_path / "backup"
    backup.mkdir()
    old_file = backup / "old.jpg"
    old_file.write_text("x")
    old_time = time.time() - 200 * 86400
    os.utime(old_file, (old_time, old_time))

    new_file = backup / "new.jpg"
    new_file.write_text("x")

    pruned = screenshots.prune_old_backups(backup, retention_days=180)

    assert pruned == [old_file]
    assert not old_file.exists()
    assert new_file.exists()


def test_link_screenshots_raises_if_lock_held(tmp_path, monkeypatch):
    monkeypatch.setattr(screenshots, "LOCK_PATH", tmp_path / "lock")
    lock_file = open(tmp_path / "lock", "w")
    fcntl.flock(lock_file, fcntl.LOCK_EX)
    try:
        remote = _FakeRemote([])
        with pytest.raises(screenshots.LinkInProgressError):
            screenshots.link_screenshots(
                remote,
                source_dir=tmp_path / "src",
                backup_dir=tmp_path / "backup",
                steam_userdata_dir=tmp_path / "userdata",
            )
    finally:
        fcntl.flock(lock_file, fcntl.LOCK_UN)
        lock_file.close()


def test_link_screenshots_orchestrates_all_steps(tmp_path, monkeypatch):
    monkeypatch.setattr(screenshots, "LOCK_PATH", tmp_path / "lock")
    userdata = tmp_path / "userdata"
    shots_dir = userdata / "1" / "screenshots"
    shots_dir.mkdir(parents=True)
    (shots_dir / "new.jpg").write_text("img")

    source = tmp_path / "source"
    backup = tmp_path / "backup"

    remote = _FakeRemote(["new.jpg"])
    result = screenshots.link_screenshots(
        remote, source_dir=source, backup_dir=backup, steam_userdata_dir=userdata
    )

    assert len(result.linked) == 1
    assert (source / "new.jpg").exists()


def test_sync_screenshots_calls_remote_sync(tmp_path, monkeypatch):
    monkeypatch.setattr(screenshots, "LOCK_PATH", tmp_path / "lock")
    remote = _FakeRemote([])
    screenshots.sync_screenshots(remote)
    assert remote.synced is True


def test_render_units_contains_all_expected_unit_names():
    units = screenshots.render_units()
    assert set(units.keys()) == {
        f"{screenshots.UNIT_PREFIX}-link.service",
        f"{screenshots.UNIT_PREFIX}-link.timer",
        f"{screenshots.UNIT_PREFIX}-sync.path",
        f"{screenshots.UNIT_PREFIX}-sync.service",
    }
    assert "ExecStart" in units[f"{screenshots.UNIT_PREFIX}-link.service"]
