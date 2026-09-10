import pytest

from steamostools.tools import emudeck


def test_update_emudeck_raises_if_updaters_missing(tmp_path):
    with pytest.raises(emudeck.EmuDeckNotInstalledError):
        emudeck.update_emudeck(tmp_path)


def test_update_emudeck_runs_both_updaters(tmp_path, monkeypatch):
    flatpak_updater, bin_updater = emudeck.updater_paths(tmp_path)
    flatpak_updater.parent.mkdir(parents=True)
    flatpak_updater.write_text("#!/bin/bash\n")
    bin_updater.parent.mkdir(parents=True)
    bin_updater.write_text("#!/bin/bash\n")

    calls = []
    monkeypatch.setattr(emudeck, "run", lambda cmd, **kw: calls.append(cmd))

    emudeck.update_emudeck(tmp_path)

    assert ["bash", str(flatpak_updater)] in calls
    assert ["bash", str(bin_updater)] in calls
