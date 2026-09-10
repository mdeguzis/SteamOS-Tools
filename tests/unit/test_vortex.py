import pytest

from steamostools.tools import vortex


def test_wineprefix_and_target_app_dir_paths(tmp_path):
    assert vortex.wineprefix_for(tmp_path) == tmp_path / "pfx"
    assert vortex.target_app_dir_for(tmp_path) == (
        tmp_path / "pfx" / "drive_c" / "Program Files" / "Black Tree Gaming Ltd" / "Vortex"
    )


def test_check_reinstall_guard_raises_when_prefix_exists(tmp_path):
    (tmp_path / "pfx").mkdir()
    with pytest.raises(vortex.VortexAlreadyInstalledError):
        vortex.check_reinstall_guard(tmp_path, reinstall=False)


def test_check_reinstall_guard_passes_when_reinstall_true(tmp_path):
    (tmp_path / "pfx").mkdir()
    vortex.check_reinstall_guard(tmp_path, reinstall=True)  # should not raise


def test_check_reinstall_guard_passes_when_no_existing_prefix(tmp_path):
    vortex.check_reinstall_guard(tmp_path, reinstall=False)  # should not raise


class _FakeClient:
    def __init__(self, releases=None, latest=None):
        self._releases = releases or []
        self._latest = latest

    def list_releases(self, repo):
        return self._releases

    def latest_release(self, repo):
        return self._latest

    def download(self, url, dest, progress=True):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(b"x" * 200_000)
        return dest


def test_fetch_release_uses_first_when_including_prerelease():
    client = _FakeClient(releases=[{"tag_name": "v2-beta"}, {"tag_name": "v1"}])
    assert vortex.fetch_release(client=client)["tag_name"] == "v2-beta"


def test_fetch_release_raises_when_no_releases():
    client = _FakeClient(releases=[])
    with pytest.raises(vortex.VortexDownloadError):
        vortex.fetch_release(client=client)


def test_fetch_release_uses_latest_when_prerelease_excluded():
    client = _FakeClient(latest={"tag_name": "v1"})
    assert vortex.fetch_release(client=client, include_prerelease=False)["tag_name"] == "v1"


def test_find_exe_asset_returns_exe():
    release = {"assets": [{"name": "readme.txt"}, {"name": "Vortex-Setup.exe"}]}
    assert vortex.find_exe_asset(release)["name"] == "Vortex-Setup.exe"


def test_find_exe_asset_raises_when_missing():
    with pytest.raises(vortex.VortexDownloadError):
        vortex.find_exe_asset({"assets": [{"name": "readme.txt"}]})


def test_download_installer_reuses_existing_file(tmp_path):
    release = {"assets": [{"name": "Vortex-Setup.exe", "browser_download_url": "https://x/y.exe"}]}
    existing = tmp_path / "Vortex-Setup.exe"
    existing.write_bytes(b"already here")

    class _NoDownloadClient(_FakeClient):
        def download(self, url, dest, progress=True):
            raise AssertionError("should not re-download when file already exists")

    dest = vortex.download_installer(release, client=_NoDownloadClient(), download_dir=tmp_path)
    assert dest == existing
    assert dest.read_bytes() == b"already here"


def test_extract_installer_payload_uses_nested_archive_when_present(tmp_path, monkeypatch):
    install_dir = tmp_path / "install"
    tmp_dir = install_dir / "tmp"
    nested = tmp_dir / "$PLUGINSDIR" / "app-64.7z"
    nested.parent.mkdir(parents=True)
    nested.write_text("fake 7z")

    target_app_dir = vortex.target_app_dir_for(install_dir)

    def fake_run(cmd, **kwargs):
        # Simulate the second 7z call actually producing Vortex.exe
        if str(nested) in cmd:
            target_app_dir.mkdir(parents=True, exist_ok=True)
            (target_app_dir / "Vortex.exe").write_text("exe")
        return None

    monkeypatch.setattr(vortex, "run", fake_run)

    result = vortex.extract_installer_payload(tmp_path / "installer.exe", install_dir)

    assert result == target_app_dir / "Vortex.exe"
    assert not tmp_dir.exists()


def test_extract_installer_payload_falls_back_to_flat_layout(tmp_path, monkeypatch):
    install_dir = tmp_path / "install"
    tmp_dir = install_dir / "tmp"
    flat_dir = tmp_dir / "some_subdir"
    flat_dir.mkdir(parents=True)
    (flat_dir / "Vortex.exe").write_text("exe")
    (flat_dir / "other.dll").write_text("dll")

    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: None)

    result = vortex.extract_installer_payload(tmp_path / "installer.exe", install_dir)

    target_app_dir = vortex.target_app_dir_for(install_dir)
    assert result == target_app_dir / "Vortex.exe"
    assert (target_app_dir / "other.dll").exists()


def test_extract_installer_payload_raises_when_nothing_found(tmp_path, monkeypatch):
    install_dir = tmp_path / "install"
    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: None)

    with pytest.raises(vortex.VortexExtractionError):
        vortex.extract_installer_payload(tmp_path / "installer.exe", install_dir)


def test_extract_bundled_dotnet_returns_false_when_absent(tmp_path):
    assert vortex.extract_bundled_dotnet(tmp_path) is False


def test_extract_bundled_dotnet_extracts_when_present(tmp_path, monkeypatch):
    install_dir = tmp_path
    bundled = install_dir / "tmp" / "$TEMP" / "windowsdesktop-runtime-win-x64.exe"
    bundled.parent.mkdir(parents=True)
    bundled.write_text("exe")

    calls = []
    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: calls.append(cmd))

    assert vortex.extract_bundled_dotnet(install_dir) is True
    assert any("7z" in c for c in calls)


def test_download_and_extract_dotnet_raises_on_tiny_payload(tmp_path):
    class _TinyClient:
        def download(self, url, dest, progress=True):
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(b"x" * 10)
            return dest

    with pytest.raises(vortex.VortexDownloadError):
        vortex.download_and_extract_dotnet(tmp_path / "install", client=_TinyClient(), download_dir=tmp_path)


def test_download_and_extract_dotnet_succeeds_on_valid_payload(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: calls.append(cmd))

    vortex.download_and_extract_dotnet(tmp_path / "install", client=_FakeClient(), download_dir=tmp_path)

    assert any("7z" in c for c in calls)


def test_map_steam_library_drives_maps_sd_card_when_present(tmp_path, monkeypatch):
    install_dir = tmp_path / "install"
    sd_card = tmp_path / "sdcard"
    sd_card.mkdir()
    calls = []
    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: calls.append(cmd))

    mapped = vortex.map_steam_library_drives(
        install_dir, sd_card_library=sd_card, internal_steam_dir=tmp_path / "nosteam"
    )

    assert mapped == {"m:": sd_card}
    dosdevices = vortex.wineprefix_for(install_dir) / "dosdevices"
    assert (dosdevices / "m:").is_symlink()


def test_map_steam_library_drives_skips_when_no_sd_card(tmp_path, monkeypatch):
    install_dir = tmp_path / "install"
    monkeypatch.setattr(vortex, "run", lambda cmd, **kw: None)

    mapped = vortex.map_steam_library_drives(
        install_dir, sd_card_library=tmp_path / "no-sd", internal_steam_dir=tmp_path / "nosteam"
    )

    assert mapped == {}


def test_write_cli_wrapper_renders_template(tmp_path):
    cli_bin = tmp_path / "vortex"
    vortex.write_cli_wrapper(tmp_path / "install", cli_bin=cli_bin)
    content = cli_bin.read_text()
    assert "umu-run" in content
    assert "GAMEID=\"umu-vortex\"" in content


def test_write_desktop_file_renders_template(tmp_path):
    desktop_file = tmp_path / "vortex.desktop"
    cli_bin = tmp_path / "bin" / "vortex"
    vortex.write_desktop_file(cli_bin=cli_bin, desktop_file=desktop_file)
    content = desktop_file.read_text()
    assert "Name=Vortex Mod Manager" in content
    assert str(cli_bin) in content


def test_cmd_install_returns_zero_when_already_installed(monkeypatch):
    monkeypatch.setattr(
        vortex,
        "install_vortex",
        lambda **kw: (_ for _ in ()).throw(vortex.VortexAlreadyInstalledError("exists")),
    )

    class _Args:
        reinstall = False

    assert vortex._cmd_install(_Args()) == 0
