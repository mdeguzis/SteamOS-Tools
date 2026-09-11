import pytest
import responses

from steamostools.tools import flatpaks


# ---------------------------------------------------------------------------
# Install/update
# ---------------------------------------------------------------------------


def test_install_or_update_flatpak_updates_when_already_installed(monkeypatch):
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)

        class _R:
            returncode = 0

        return _R()

    monkeypatch.setattr(flatpaks, "run", fake_run)
    monkeypatch.setattr(flatpaks, "steam_add_flatpak_shortcut", lambda *a: None)

    flatpaks.install_or_update_flatpak("Kodi", "tv.kodi.Kodi")

    assert ["flatpak", "--user", "update", "tv.kodi.Kodi", "-y"] in calls
    assert not any(c[0] == "flatpak" and c[1] == "install" for c in calls)


def test_install_or_update_flatpak_installs_when_update_fails(monkeypatch):
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)

        class _R:
            returncode = 1 if cmd[2] == "update" else 0

        return _R()

    monkeypatch.setattr(flatpaks, "run", fake_run)
    monkeypatch.setattr(flatpaks, "steam_add_flatpak_shortcut", lambda *a: None)

    flatpaks.install_or_update_flatpak("Kodi", "tv.kodi.Kodi")

    assert any(c[:3] == ["flatpak", "install", "--user"] for c in calls)


def test_install_or_update_flatpak_raises_when_both_fail(monkeypatch):
    monkeypatch.setattr(flatpaks, "run", lambda cmd, **kw: type("R", (), {"returncode": 1})())
    with pytest.raises(flatpaks.FlatpakInstallError):
        flatpaks.install_or_update_flatpak("Kodi", "tv.kodi.Kodi")


def test_list_installed_parses_tsv_output(monkeypatch):
    class _R:
        stdout = "org.a.App\tApp A\tDesc A\t1.0\norg.b.App\tApp B\tDesc B\t2.0\n"

    monkeypatch.setattr(flatpaks, "run", lambda cmd, **kw: _R())
    apps = flatpaks.list_installed()
    assert apps == [
        {"id": "org.a.App", "name": "App A", "description": "Desc A", "version": "1.0"},
        {"id": "org.b.App", "name": "App B", "description": "Desc B", "version": "2.0"},
    ]


def test_remove_deprecated_flatpaks_only_removes_eol_marked(monkeypatch):
    class _ListR:
        stdout = "org.a.App\tApp A\teol=unmaintained\norg.b.App\tApp B\t\n"

    calls = []

    def fake_run(cmd, **kwargs):
        if cmd[:2] == ["flatpak", "list"]:
            return _ListR()
        calls.append(cmd)

        class _R:
            returncode = 0

        return _R()

    monkeypatch.setattr(flatpaks, "run", fake_run)
    removed = flatpaks.remove_deprecated_flatpaks()

    assert removed == ["org.a.App"]
    assert ["flatpak", "uninstall", "--user", "-y", "org.a.App"] in calls


def test_remove_deprecated_flatpaks_empty_when_none_marked(monkeypatch):
    class _R:
        stdout = "org.a.App\tApp A\t\n"

    monkeypatch.setattr(flatpaks, "run", lambda cmd, **kw: _R())
    assert flatpaks.remove_deprecated_flatpaks() == []


# ---------------------------------------------------------------------------
# Flathub client
# ---------------------------------------------------------------------------


@responses.activate
def test_flathub_search_returns_hits():
    responses.add(
        responses.POST, f"{flatpaks.FLATHUB_API}/search",
        json={"hits": [{"app_id": "org.a.App", "name": "App A"}]}, status=200,
    )
    hits = flatpaks.FlathubClient().search("app a")
    assert hits == [{"app_id": "org.a.App", "name": "App A"}]


@responses.activate
def test_flathub_app_info_returns_json():
    responses.add(
        responses.GET, f"{flatpaks.FLATHUB_API}/appstream/org.a.App",
        json={"name": "App A", "developer_name": "Someone"}, status=200,
    )
    info = flatpaks.FlathubClient().app_info("org.a.App")
    assert info["developer_name"] == "Someone"


# ---------------------------------------------------------------------------
# Icon resolution
# ---------------------------------------------------------------------------


def _hicolor_dir(home):
    return home / ".local" / "share" / "flatpak" / "exports" / "share" / "icons" / "hicolor"


def test_find_flatpak_icon_prefers_larger_png(tmp_path, monkeypatch):
    hicolor = _hicolor_dir(tmp_path)
    (hicolor / "512x512" / "apps").mkdir(parents=True)
    (hicolor / "512x512" / "apps" / "org.a.App.png").write_text("x")
    (hicolor / "256x256" / "apps").mkdir(parents=True)
    (hicolor / "256x256" / "apps" / "org.a.App.png").write_text("x")

    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    found = flatpaks.find_flatpak_icon("org.a.App")
    assert found == hicolor / "512x512" / "apps" / "org.a.App.png"


def test_find_flatpak_icon_returns_none_when_missing(tmp_path, monkeypatch):
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    assert flatpaks.find_flatpak_icon("org.nonexistent.App") is None


def test_resolve_flatpak_icon_returns_png_directly(tmp_path, monkeypatch):
    hicolor = _hicolor_dir(tmp_path)
    (hicolor / "512x512" / "apps").mkdir(parents=True)
    icon_path = hicolor / "512x512" / "apps" / "org.a.App.png"
    icon_path.write_text("x")
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))

    assert flatpaks.resolve_flatpak_icon("org.a.App") == str(icon_path)


def test_resolve_flatpak_icon_returns_empty_when_no_icon(tmp_path, monkeypatch):
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    assert flatpaks.resolve_flatpak_icon("org.nonexistent.App") == ""


def test_resolve_flatpak_icon_skips_svg_without_imagemagick(tmp_path, monkeypatch):
    hicolor = _hicolor_dir(tmp_path)
    (hicolor / "scalable" / "apps").mkdir(parents=True)
    (hicolor / "scalable" / "apps" / "org.a.App.svg").write_text("<svg/>")
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    monkeypatch.setattr("shutil.which", lambda name: None)

    assert flatpaks.resolve_flatpak_icon("org.a.App") == ""


def test_resolve_flatpak_icon_converts_svg_with_imagemagick(tmp_path, monkeypatch):
    hicolor = _hicolor_dir(tmp_path)
    (hicolor / "scalable" / "apps").mkdir(parents=True)
    (hicolor / "scalable" / "apps" / "org.a.App.svg").write_text("<svg/>")
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/magick")

    cache_dir = tmp_path / "cache"

    def fake_run(cmd, **kwargs):
        # Simulate magick producing the output file.
        (cache_dir / "org.a.App.png").write_bytes(b"png-data")

        class _R:
            returncode = 0

        return _R()

    monkeypatch.setattr(flatpaks, "run", fake_run)

    result = flatpaks.resolve_flatpak_icon("org.a.App", icon_cache_dir=cache_dir)
    assert result == str(cache_dir / "org.a.App.png")


# ---------------------------------------------------------------------------
# SteamGridDB
# ---------------------------------------------------------------------------


def test_steamgriddb_get_api_key_from_env(monkeypatch, tmp_path):
    monkeypatch.setenv("STEAMGRIDDB_API_KEY", "envkey")
    assert flatpaks.steamgriddb_get_api_key(conf_path=tmp_path / "conf") == "envkey"


def test_steamgriddb_get_api_key_from_conf_file(monkeypatch, tmp_path):
    monkeypatch.delenv("STEAMGRIDDB_API_KEY", raising=False)
    conf = tmp_path / "conf"
    conf.write_text("STEAMGRIDDB_API_KEY='filekey'\n")
    assert flatpaks.steamgriddb_get_api_key(conf_path=conf) == "filekey"


def test_steamgriddb_get_api_key_none_when_unconfigured(monkeypatch, tmp_path):
    monkeypatch.delenv("STEAMGRIDDB_API_KEY", raising=False)
    assert flatpaks.steamgriddb_get_api_key(conf_path=tmp_path / "nope") is None


def test_save_steamgriddb_api_key_writes_and_restricts_permissions(tmp_path):
    conf = tmp_path / "conf"
    flatpaks.save_steamgriddb_api_key("mykey", conf_path=conf)
    assert "mykey" in conf.read_text()
    assert oct(conf.stat().st_mode)[-3:] == "600"


@responses.activate
def test_sgdb_client_find_game_id():
    responses.add(
        responses.GET, f"{flatpaks.SGDB_API}/search/autocomplete/Kodi",
        json={"data": [{"id": 42}]}, status=200,
    )
    client = flatpaks.SteamGridDBClient("key")
    assert client.find_game_id("Kodi") == 42


@responses.activate
def test_sgdb_client_find_game_id_none_when_no_results():
    responses.add(
        responses.GET, f"{flatpaks.SGDB_API}/search/autocomplete/Unknown",
        json={"data": []}, status=200,
    )
    client = flatpaks.SteamGridDBClient("key")
    assert client.find_game_id("Unknown") is None


@responses.activate
def test_sgdb_client_download_first_asset(tmp_path):
    responses.add(
        responses.GET, f"{flatpaks.SGDB_API}/icons/game/42",
        json={"data": [{"url": "https://cdn.example.com/icon.png"}]}, status=200,
    )
    responses.add(responses.GET, "https://cdn.example.com/icon.png", body=b"icon-bytes", status=200)

    client = flatpaks.SteamGridDBClient("key")
    dest = tmp_path / "icon.png"
    assert client.download_first_asset("/icons/game/42", dest) is True
    assert dest.read_bytes() == b"icon-bytes"


@responses.activate
def test_sgdb_client_download_first_asset_false_when_empty():
    responses.add(
        responses.GET, f"{flatpaks.SGDB_API}/icons/game/42", json={"data": []}, status=200
    )
    client = flatpaks.SteamGridDBClient("key")
    assert client.download_first_asset("/icons/game/42", None) is False


def test_sgdb_client_fetch_artwork_skips_when_icon_cached(tmp_path):
    grid_dir = tmp_path
    (grid_dir / "999_icon.png").write_text("cached")
    client = flatpaks.SteamGridDBClient("key")
    client.fetch_artwork("Kodi", 999, grid_dir)  # should not raise / hit network


# ---------------------------------------------------------------------------
# Steam shortcut integration
# ---------------------------------------------------------------------------


def test_steam_add_flatpak_shortcut_warns_when_no_vdf(tmp_path, monkeypatch):
    monkeypatch.setattr(
        "steamostools.vdf.shortcuts.find_shortcuts_vdf_files", lambda *a, **kw: []
    )
    flatpaks.steam_add_flatpak_shortcut("org.a.App", "App A")  # should not raise


def test_steam_add_flatpak_shortcut_uses_resolved_icon_without_api_key(tmp_path, monkeypatch):
    vdf = tmp_path / "userdata" / "1" / "config" / "shortcuts.vdf"
    monkeypatch.setattr(
        "steamostools.vdf.shortcuts.find_shortcuts_vdf_files", lambda *a, **kw: [vdf]
    )
    monkeypatch.setattr(flatpaks, "steamgriddb_get_api_key", lambda: None)
    monkeypatch.setattr(flatpaks, "resolve_flatpak_icon", lambda app_id: "/icons/app.png")

    flatpaks.steam_add_flatpak_shortcut("org.a.App", "App A")

    data = vdf.read_bytes()
    assert b"org.a.App" in data
    assert b"/icons/app.png" in data


# ---------------------------------------------------------------------------
# Core/emulator/user-flatpak batches
# ---------------------------------------------------------------------------


def test_update_emulator_software_installs_all_and_symlinks_pcsx2(tmp_path, monkeypatch):
    monkeypatch.setattr(flatpaks, "APP_LOC", tmp_path)
    installed = []
    monkeypatch.setattr(flatpaks, "install_or_update_flatpak", lambda name, app_id: installed.append((name, app_id)))

    pcsx2 = tmp_path / "pcsx2-v1-linux-appimage-x64-Qt.AppImage"
    pcsx2.write_text("x")

    flatpaks.update_emulator_software()

    assert len(installed) == len(flatpaks.EMULATOR_FLATPAKS)
    assert (tmp_path / "pcsx2-Qt.AppImage").is_symlink()


def test_update_user_flatpaks_installs_all_and_upgrades(monkeypatch):
    installed = []
    calls = []
    monkeypatch.setattr(flatpaks, "install_or_update_flatpak", lambda name, app_id: installed.append(app_id))
    monkeypatch.setattr(flatpaks, "run", lambda cmd, **kw: calls.append(cmd))

    flatpaks.update_user_flatpaks()

    assert len(installed) == len(flatpaks.USER_FLATPAKS)
    assert ["flatpak", "--user", "--noninteractive", "upgrade"] in calls


def test_setup_ludusavi_writes_config_and_units(tmp_path, monkeypatch):
    monkeypatch.setattr(flatpaks, "install_or_update_flatpak", lambda name, app_id: None)
    monkeypatch.setattr(flatpaks.Path, "home", staticmethod(lambda: tmp_path))
    monkeypatch.setattr(flatpaks, "run", lambda cmd, **kw: None)

    flatpaks.setup_ludusavi()

    config = tmp_path / ".var" / "app" / "com.github.mtkennerly.ludusavi" / "config" / "ludusavi" / "config.yaml"
    assert config.exists()
    unit_dir = tmp_path / ".config" / "systemd" / "user"
    assert (unit_dir / "ludusavi-backup.service").exists()
    assert (unit_dir / "ludusavi-backup.timer").exists()


# ---------------------------------------------------------------------------
# Binary downloader URL resolution
# ---------------------------------------------------------------------------


def test_resolve_binary_download_url_direct_zip():
    url = "https://example.com/file.zip"
    assert flatpaks.resolve_binary_download_url("app", url) == url


@responses.activate
def test_resolve_binary_download_url_gitlab_api():
    api_url = "https://gitlab.com/api/v4/projects/1/releases/permalink/latest"
    responses.add(
        responses.GET, api_url,
        json={"assets": {"links": [{"name": "app-x64.AppImage", "direct_asset_url": "https://x/app.AppImage"}]}},
        status=200,
    )
    assert flatpaks.resolve_binary_download_url("app", api_url, r"app.*x64\.AppImage") == "https://x/app.AppImage"


@responses.activate
def test_resolve_binary_download_url_github_releases_latest():
    api_url = "https://api.github.com/repos/org/app/releases/latest"
    responses.add(
        responses.GET, api_url,
        json={"assets": [{"browser_download_url": "https://x/app-linux-x64.AppImage"}]},
        status=200,
    )
    assert flatpaks.resolve_binary_download_url("app", api_url) == "https://x/app-linux-x64.AppImage"


@responses.activate
def test_resolve_binary_download_url_github_releases_prerelease_list():
    api_url = "https://api.github.com/repos/org/app/releases"
    responses.add(
        responses.GET, api_url,
        json=[
            {"prerelease": True, "assets": [{"browser_download_url": "https://x/app-pre.AppImage"}]},
            {"prerelease": False, "assets": [{"browser_download_url": "https://x/app-stable.AppImage"}]},
        ],
        status=200,
    )
    assert flatpaks.resolve_binary_download_url("app", api_url) == "https://x/app-pre.AppImage"


@responses.activate
def test_resolve_binary_download_url_raises_when_no_match():
    api_url = "https://api.github.com/repos/org/app/releases/latest"
    responses.add(responses.GET, api_url, json={"assets": [{"browser_download_url": "https://x/app.exe"}]}, status=200)
    with pytest.raises(flatpaks.FlatpakInstallError):
        flatpaks.resolve_binary_download_url("app", api_url)


def test_resolve_binary_download_url_passthrough_for_direct_url():
    url = "https://example.com/downloads/app-linux.tar.gz"
    assert flatpaks.resolve_binary_download_url("app", url) == url
