import pytest

from steamostools.tools import plex


def test_render_quadlet_fills_uid_gid():
    content = plex.render_quadlet(uid=1000, gid=1000)
    assert "PUID=1000 PGID=1000" in content
    assert "Image=lscr.io/linuxserver/plex:latest" in content


def test_install_plex_writes_unit_and_succeeds(tmp_path, monkeypatch):
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)

        class _Result:
            returncode = 0

        return _Result()

    monkeypatch.setattr(plex, "run", fake_run)
    monkeypatch.setattr(plex.time, "sleep", lambda s: None)

    plex.install_plex(
        config_dir=tmp_path / "config",
        media_dir=tmp_path / "media",
        quadlet_dir=tmp_path / "quadlet",
    )

    quadlet_file = tmp_path / "quadlet" / "plex.container"
    assert quadlet_file.exists()
    assert ["systemctl", "--user", "daemon-reload"] in calls
    assert ["systemctl", "--user", "start", "plex"] in calls


def test_install_plex_raises_if_service_not_active(tmp_path, monkeypatch):
    def fake_run(cmd, **kwargs):
        class _Result:
            returncode = 1

        return _Result()

    monkeypatch.setattr(plex, "run", fake_run)
    monkeypatch.setattr(plex.time, "sleep", lambda s: None)

    with pytest.raises(plex.PlexStartError):
        plex.install_plex(
            config_dir=tmp_path / "config",
            media_dir=tmp_path / "media",
            quadlet_dir=tmp_path / "quadlet",
        )
