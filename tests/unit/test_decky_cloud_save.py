import pytest

from steamostools.tools import decky_cloud_save


def test_run_backup_raises_if_rclone_missing(tmp_path):
    with pytest.raises(decky_cloud_save.DeckyCloudSaveNotInstalledError):
        decky_cloud_save.run_backup(
            rclone_bin=tmp_path / "missing-rclone", filter_file=tmp_path / "filter.txt"
        )


def test_run_backup_invokes_rclone_with_hostname(tmp_path, monkeypatch):
    rclone_bin = tmp_path / "rclone"
    rclone_bin.write_text("#!/bin/sh\n")
    filter_file = tmp_path / "filter.txt"
    filter_file.write_text("+ /**\n")

    calls = []
    monkeypatch.setattr(decky_cloud_save, "run", lambda cmd, **kw: calls.append(cmd))

    decky_cloud_save.run_backup(hostname="my-deck", rclone_bin=rclone_bin, filter_file=filter_file)

    cmd = calls[0]
    assert cmd[0] == str(rclone_bin)
    assert cmd[1] == "copy"
    assert "backend:decky-cloud-save-my-deck" in cmd
    assert "--filter-from" in cmd
