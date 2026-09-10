import pytest

from steamostools.tools import local_roms_transfer


def test_transfer_raises_when_source_missing(tmp_path):
    with pytest.raises(FileNotFoundError):
        local_roms_transfer.transfer(tmp_path / "missing", tmp_path / "dest")


def test_transfer_copies_file(tmp_path):
    source = tmp_path / "rom.zip"
    source.write_text("data")
    dest = tmp_path / "dest"

    target = local_roms_transfer.transfer(source, dest)

    assert target == dest / "rom.zip"
    assert target.read_text() == "data"
    assert source.exists()  # copy, not move


def test_transfer_copies_directory(tmp_path):
    source = tmp_path / "romset"
    source.mkdir()
    (source / "a.zip").write_text("x")
    dest = tmp_path / "dest"

    target = local_roms_transfer.transfer(source, dest)

    assert (target / "a.zip").exists()


def test_transfer_applies_legacy_owner_when_recognized(tmp_path, monkeypatch):
    source = tmp_path / "rom.zip"
    source.write_text("data")
    dest = tmp_path / "dest"
    calls = []
    monkeypatch.setattr(local_roms_transfer, "run", lambda cmd, **kw: calls.append(cmd))

    local_roms_transfer.transfer(source, dest, owner="steam")

    assert ["sudo", "chown", "-R", "steam:steam", str(dest)] in calls
    assert ["sudo", "chmod", "-R", "755", str(dest)] in calls


def test_transfer_skips_ownership_for_unrecognized_owner(tmp_path, monkeypatch):
    source = tmp_path / "rom.zip"
    source.write_text("data")
    dest = tmp_path / "dest"
    calls = []
    monkeypatch.setattr(local_roms_transfer, "run", lambda cmd, **kw: calls.append(cmd))

    local_roms_transfer.transfer(source, dest, owner="deck")

    assert calls == []
