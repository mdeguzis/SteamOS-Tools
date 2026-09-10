from pathlib import Path

import pytest

from steamostools.tools import skyscraper


def test_build_command_shape():
    cmd = skyscraper.build_command("mame", "alice", "hunter2", roms_root=Path("/roms"))
    assert cmd == [
        "Skyscraper",
        "-f", "emulationstation",
        "-s", "screenscraper",
        "-u", "alice:hunter2",
        "-i", "/roms/mame",
        "-g", "/roms/mame",
        "-o", "/roms/mame",
        "-p", "mame",
    ]


def test_run_skyscraper_raises_if_binary_missing(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: None)
    with pytest.raises(skyscraper.SkyscraperNotAvailableError):
        skyscraper.run_skyscraper("mame", user="a", password="b")


def test_run_skyscraper_raises_if_credentials_missing(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/Skyscraper")
    monkeypatch.delenv("SKYSCRAPER_USER", raising=False)
    monkeypatch.delenv("SKYSCRAPER_PASSWORD", raising=False)
    with pytest.raises(skyscraper.MissingCredentialsError):
        skyscraper.run_skyscraper("mame")


def test_run_skyscraper_prefers_explicit_args_over_env(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/Skyscraper")
    monkeypatch.setenv("SKYSCRAPER_USER", "envuser")
    monkeypatch.setenv("SKYSCRAPER_PASSWORD", "envpass")
    calls = []
    monkeypatch.setattr(skyscraper, "run", lambda cmd, **kw: calls.append(cmd))

    skyscraper.run_skyscraper("mame", user="cliuser", password="clipass")

    assert "cliuser:clipass" in calls[0]


def test_run_skyscraper_falls_back_to_env(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/Skyscraper")
    monkeypatch.setenv("SKYSCRAPER_USER", "envuser")
    monkeypatch.setenv("SKYSCRAPER_PASSWORD", "envpass")
    calls = []
    monkeypatch.setattr(skyscraper, "run", lambda cmd, **kw: calls.append(cmd))

    skyscraper.run_skyscraper("mame")

    assert "envuser:envpass" in calls[0]
