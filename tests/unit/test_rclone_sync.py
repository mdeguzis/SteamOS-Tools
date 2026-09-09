import pytest

from steamostools.rclone_sync import RcloneNotAvailableError, RcloneRemoteTarget, RcloneSync


def test_remote_spec_formats_correctly():
    target = RcloneRemoteTarget(remote_name="gphoto", remote_path="album/Steam-screenshots")
    assert target.remote_spec == "gphoto:album/Steam-screenshots"


def test_check_available_raises_when_rclone_missing(tmp_path, monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: None)
    sync = RcloneSync(tmp_path, RcloneRemoteTarget("r", "p"))
    with pytest.raises(RcloneNotAvailableError):
        sync.check_available()


def test_check_available_passes_when_rclone_present(tmp_path, monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/rclone")
    sync = RcloneSync(tmp_path, RcloneRemoteTarget("r", "p"))
    sync.check_available()  # should not raise


def test_list_remote_parses_lines(tmp_path, monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/rclone")

    class _Result:
        stdout = "a.jpg\nb.jpg\n\n"

    monkeypatch.setattr("steamostools.rclone_sync.run", lambda cmd, **kw: _Result())
    sync = RcloneSync(tmp_path, RcloneRemoteTarget("r", "p"))
    assert sync.list_remote() == ["a.jpg", "b.jpg"]


def test_sync_builds_correct_command(tmp_path, monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/rclone")
    calls = []

    class _Result:
        stdout = ""

    def _fake_run(cmd, **kwargs):
        calls.append(cmd)
        return _Result()

    monkeypatch.setattr("steamostools.rclone_sync.run", _fake_run)
    sync = RcloneSync(tmp_path, RcloneRemoteTarget("gphoto", "album"), excludes=["**/thumbnails/**"])
    sync.sync()

    assert calls[0][:2] == ["rclone", "sync"]
    assert str(tmp_path) in calls[0]
    assert "gphoto:album" in calls[0]
    assert "--exclude=**/thumbnails/**" in calls[0]
