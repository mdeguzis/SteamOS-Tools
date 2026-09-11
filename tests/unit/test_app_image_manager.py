import tarfile
import zipfile

import pytest

from steamostools.tools import app_image_manager as aim


def test_parse_repo_input_strips_url_prefix_and_git_suffix():
    assert aim.parse_repo_input("https://github.com/foo/bar.git") == "foo/bar"
    assert aim.parse_repo_input("http://github.com/foo/bar") == "foo/bar"
    assert aim.parse_repo_input("foo/bar") == "foo/bar"


def test_derive_name_lowercases_repo_part():
    assert aim.derive_name("SomeOrg/CoolApp") == "coolapp"


def test_arch_patterns_known_and_unknown_machine():
    assert "x86_64" in aim.arch_patterns("x86_64")
    assert aim.arch_patterns("riscv64") == ["riscv64"]


def test_select_asset_prefers_appimage_over_targz_and_arch_specific():
    assets = [
        {"name": "app-linux-x86_64.AppImage", "browser_download_url": "https://x/1"},
        {"name": "app.tar.gz", "browser_download_url": "https://x/2"},
        {"name": "app-generic.AppImage", "browser_download_url": "https://x/3"},
    ]
    url, ext_type = aim.select_asset(assets, machine="x86_64")
    assert url == "https://x/1"
    assert ext_type == "appimage"


def test_select_asset_falls_back_to_generic_when_no_arch_match():
    assets = [{"name": "app.AppImage", "browser_download_url": "https://x/1"}]
    url, ext_type = aim.select_asset(assets, machine="x86_64")
    assert url == "https://x/1"
    assert ext_type == "appimage"


def test_select_asset_returns_none_when_nothing_matches():
    assets = [{"name": "app.exe", "browser_download_url": "https://x/1"}]
    assert aim.select_asset(assets) is None


# ---------------------------------------------------------------------------
# AppRegistry
# ---------------------------------------------------------------------------


def test_registry_register_and_get_repo(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")
    assert registry.get_repo("myapp") == "org/myapp"


def test_registry_register_is_idempotent(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")
    registry.register("myapp", "org/different-repo")
    assert registry.get_repo("myapp") == "org/myapp"


def test_registry_unregister_removes_entry(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")
    registry.unregister("myapp")
    assert registry.get_repo("myapp") is None


def test_registry_resolve_bare_name_from_registry(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")
    assert registry.resolve("myapp") == ("myapp", "org/myapp")


def test_registry_resolve_raises_for_unknown_bare_name(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    with pytest.raises(aim.AppNotFoundError):
        registry.resolve("unknown")


def test_registry_resolve_repo_or_url_does_not_need_registry(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    assert registry.resolve("org/myapp") == ("myapp", "org/myapp")
    assert registry.resolve("https://github.com/org/myapp") == ("myapp", "org/myapp")


# ---------------------------------------------------------------------------
# AppMetadata
# ---------------------------------------------------------------------------


def test_metadata_version_roundtrip(tmp_path):
    meta = aim.AppMetadata(config_dir=tmp_path)
    assert meta.get_version("myapp") is None
    meta.set_version("myapp", "v1.2.3")
    assert meta.get_version("myapp") == "v1.2.3"


def test_metadata_install_type_explicit_file(tmp_path):
    meta = aim.AppMetadata(config_dir=tmp_path, apps_dir=tmp_path / "apps", lib_dir=tmp_path / "lib")
    meta.set_install_type("myapp", "appimage")
    assert meta.get_install_type("myapp") == "appimage"


def test_metadata_install_type_inferred_from_filesystem(tmp_path):
    apps_dir = tmp_path / "apps"
    apps_dir.mkdir()
    (apps_dir / "myapp.AppImage").write_text("x")
    meta = aim.AppMetadata(config_dir=tmp_path / "cfg", apps_dir=apps_dir, lib_dir=tmp_path / "lib")
    assert meta.get_install_type("myapp") == "appimage"


def test_metadata_install_type_unknown_when_nothing_found(tmp_path):
    meta = aim.AppMetadata(config_dir=tmp_path / "cfg", apps_dir=tmp_path / "apps", lib_dir=tmp_path / "lib")
    assert meta.get_install_type("myapp") == "unknown"


def test_metadata_clear_removes_both_files(tmp_path):
    meta = aim.AppMetadata(config_dir=tmp_path)
    meta.set_version("myapp", "v1")
    meta.set_install_type("myapp", "appimage")
    meta.clear("myapp")
    assert meta.get_version("myapp") is None
    assert not (tmp_path / "myapp.type").exists()


# ---------------------------------------------------------------------------
# find_main_binary
# ---------------------------------------------------------------------------


def test_find_main_binary_matches_by_name(tmp_path):
    (tmp_path / "readme.txt").write_text("x")
    (tmp_path / "coolapp").write_bytes(b"binary")
    assert aim.find_main_binary(tmp_path, "CoolApp") == tmp_path / "coolapp"


def test_find_main_binary_falls_back_to_executable_bit(tmp_path):
    other = tmp_path / "other-binary"
    other.write_bytes(b"data")
    other.chmod(0o755)
    (tmp_path / "notes.txt").write_text("x")
    assert aim.find_main_binary(tmp_path, "totally-different-name") == other


def test_find_main_binary_falls_back_to_largest_file(tmp_path):
    small = tmp_path / "small.bin"
    small.write_bytes(b"x" * 10)
    large = tmp_path / "large.bin"
    large.write_bytes(b"x" * 1000)
    assert aim.find_main_binary(tmp_path, "unrelated") == large


def test_find_main_binary_returns_none_when_nothing_plausible(tmp_path):
    (tmp_path / "readme.md").write_text("x")
    assert aim.find_main_binary(tmp_path, "anything") is None


# ---------------------------------------------------------------------------
# Desktop integration (non-extraction paths)
# ---------------------------------------------------------------------------


def test_generate_minimal_desktop_entry_contains_expected_fields(tmp_path):
    launcher = tmp_path / "myapp.AppImage"
    content = aim.generate_minimal_desktop_entry("cool-app", launcher)
    assert "Name=Cool App" in content
    assert f"Exec={launcher}" in content
    assert "Icon=cool-app" in content


def test_install_desktop_entry_uses_provided_search_dir(tmp_path, monkeypatch):
    search_dir = tmp_path / "extracted"
    search_dir.mkdir()
    (search_dir / "myapp.desktop").write_text(
        "[Desktop Entry]\nName=MyApp\nExec=OLD\nIcon=myapp\n"
    )
    launcher = tmp_path / "myapp.AppImage"
    launcher.write_text("x")

    monkeypatch.setattr(aim, "run", lambda cmd, **kw: type("R", (), {"returncode": 0})())

    dest = aim.install_desktop_entry(
        "myapp", launcher, search_dir, desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons"
    )

    assert dest is not None
    content = dest.read_text()
    assert f"Exec={launcher}" in content
    assert "Icon=myapp" in content


def test_install_desktop_entry_generates_minimal_when_no_desktop_file(tmp_path, monkeypatch):
    search_dir = tmp_path / "extracted"
    search_dir.mkdir()
    launcher = tmp_path / "myapp.AppImage"
    launcher.write_text("x")
    monkeypatch.setattr(aim, "run", lambda cmd, **kw: type("R", (), {"returncode": 0})())

    dest = aim.install_desktop_entry(
        "myapp", launcher, search_dir, desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons"
    )

    assert dest is not None
    assert "Type=Application" in dest.read_text()


def test_install_desktop_entry_returns_none_on_extraction_failure(tmp_path, monkeypatch):
    launcher = tmp_path / "myapp.AppImage"
    launcher.write_text("x")
    monkeypatch.setattr(aim, "run", lambda cmd, **kw: type("R", (), {"returncode": 1})())
    monkeypatch.setattr(aim.tempfile, "mkdtemp", lambda: str(tmp_path / "tmpdir"))
    (tmp_path / "tmpdir").mkdir()

    dest = aim.install_desktop_entry("myapp", launcher, desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons")

    assert dest is None


def test_remove_desktop_entry_deletes_desktop_file_and_icons(tmp_path):
    desktop_dir = tmp_path / "desktop"
    icon_dir = tmp_path / "icons"
    desktop_dir.mkdir()
    (desktop_dir / "myapp.desktop").write_text("x")
    icon_path = icon_dir / "256x256" / "apps"
    icon_path.mkdir(parents=True)
    (icon_path / "myapp.png").write_text("x")

    aim.remove_desktop_entry("myapp", desktop_dir=desktop_dir, icon_dir=icon_dir)

    assert not (desktop_dir / "myapp.desktop").exists()
    assert not (icon_path / "myapp.png").exists()


# ---------------------------------------------------------------------------
# Steam shortcut integration
# ---------------------------------------------------------------------------


def test_steam_add_shortcut_warns_and_returns_zero_when_no_vdf(tmp_path, monkeypatch):
    monkeypatch.setattr(
        "steamostools.vdf.shortcuts.find_shortcuts_vdf_files", lambda *a, **kw: []
    )
    launcher = tmp_path / "myapp.AppImage"
    assert aim.steam_add_shortcut("myapp", launcher, icon_dir=tmp_path / "icons") == 0


def test_steam_add_shortcut_writes_to_all_found_vdf_files(tmp_path, monkeypatch):
    vdf1 = tmp_path / "userdata1" / "config" / "shortcuts.vdf"
    vdf2 = tmp_path / "userdata2" / "config" / "shortcuts.vdf"
    monkeypatch.setattr(
        "steamostools.vdf.shortcuts.find_shortcuts_vdf_files", lambda *a, **kw: [vdf1, vdf2]
    )
    monkeypatch.setattr(aim, "run", lambda cmd, **kw: type("R", (), {"returncode": 1})())

    launcher = tmp_path / "myapp.AppImage"
    count = aim.steam_add_shortcut("myapp", launcher, icon_dir=tmp_path / "icons")

    assert count == 2
    assert b"Myapp" in vdf1.read_bytes()
    assert b"Myapp" in vdf2.read_bytes()


def test_steam_remove_shortcut_ignores_missing_entries(tmp_path, monkeypatch):
    vdf1 = tmp_path / "shortcuts.vdf"
    vdf1.write_bytes(b"\x00shortcuts\x00\x08\x08")
    monkeypatch.setattr(
        "steamostools.vdf.shortcuts.find_shortcuts_vdf_files", lambda *a, **kw: [vdf1]
    )
    aim.steam_remove_shortcut("myapp")  # should not raise


# ---------------------------------------------------------------------------
# Install flows (fake GitHubReleaseClient)
# ---------------------------------------------------------------------------


class _FakeClient:
    def __init__(self, payload: bytes):
        self.payload = payload
        self.downloads = []

    def latest_release(self, repo):
        return {"tag_name": "v1.0.0", "assets": [{"name": "app.AppImage", "browser_download_url": "https://x/app.AppImage"}]}

    def download(self, url, dest, progress=True):
        self.downloads.append(url)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(self.payload)
        return dest


def test_install_appimage_downloads_and_records_metadata(tmp_path):
    apps_dir = tmp_path / "apps"
    metadata = aim.AppMetadata(config_dir=tmp_path / "cfg", apps_dir=apps_dir, lib_dir=tmp_path / "lib")
    client = _FakeClient(b"fake appimage bytes")

    path = aim.install_appimage(
        "myapp", "https://x/app.AppImage", "v1.0.0", client=client, apps_dir=apps_dir,
        desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons", metadata=metadata,
    )

    assert path == apps_dir / "myapp.AppImage"
    assert path.read_bytes() == b"fake appimage bytes"
    assert metadata.get_version("myapp") == "v1.0.0"
    assert metadata.get_install_type("myapp") == "appimage"
    # A fake (non-ELF) AppImage can't actually be extracted for desktop
    # integration -- install_desktop_entry must degrade gracefully (no
    # exception) rather than crash the whole install.
    assert not (tmp_path / "desktop" / "myapp.desktop").exists()


def test_install_archive_targz_extracts_and_wraps_binary(tmp_path):
    src_dir = tmp_path / "src"
    src_dir.mkdir()
    (src_dir / "myapp").write_bytes(b"#!/bin/sh\n")
    tar_path = tmp_path / "payload.tar.gz"
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(src_dir / "myapp", arcname="myapp")

    class _ArchiveClient(_FakeClient):
        def download(self, url, dest, progress=True):
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(tar_path.read_bytes())
            return dest

    apps_dir = tmp_path / "apps"
    lib_dir = tmp_path / "lib"
    desktop_dir = tmp_path / "desktop"
    icon_dir = tmp_path / "icons"
    metadata = aim.AppMetadata(
        config_dir=tmp_path / "cfg", apps_dir=apps_dir, lib_dir=lib_dir, desktop_dir=desktop_dir, icon_dir=icon_dir
    )

    launcher = aim.install_archive(
        "myapp", "https://x/app.tar.gz", "v2.0.0", "targz",
        client=_ArchiveClient(b""), apps_dir=apps_dir, lib_dir=lib_dir,
        desktop_dir=desktop_dir, icon_dir=icon_dir, metadata=metadata,
    )

    assert launcher == apps_dir / "myapp.AppImage"
    assert "myapp" in launcher.read_text()
    assert metadata.get_install_type("myapp") == "archive-targz"
    # install_desktop_entry ran against extract_dir directly (search_dir
    # given), so it must have written into our isolated desktop_dir, not
    # the real one.
    assert (desktop_dir / "myapp.desktop").exists()


def test_install_archive_raises_when_no_binary_found(tmp_path):
    zip_path = tmp_path / "payload.zip"
    with zipfile.ZipFile(zip_path, "w") as zf:
        zf.writestr("readme.md", "just docs")

    class _ZipClient(_FakeClient):
        def download(self, url, dest, progress=True):
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(zip_path.read_bytes())
            return dest

    apps_dir = tmp_path / "apps"
    lib_dir = tmp_path / "lib"
    metadata = aim.AppMetadata(config_dir=tmp_path / "cfg", apps_dir=apps_dir, lib_dir=lib_dir)

    with pytest.raises(aim.NoExecutableFoundError):
        aim.install_archive(
            "myapp", "https://x/app.zip", "v1", "zip",
            client=_ZipClient(b""), apps_dir=apps_dir, lib_dir=lib_dir, metadata=metadata,
        )


def test_fetch_and_install_raises_when_no_supported_asset():
    class _NoAssetClient:
        def latest_release(self, repo):
            return {"tag_name": "v1.0.0", "assets": [{"name": "app.exe", "browser_download_url": "https://x/1"}]}

    with pytest.raises(aim.NoSupportedAssetError):
        aim.fetch_and_install("myapp", "org/myapp", client=_NoAssetClient(), metadata=aim.AppMetadata())


# ---------------------------------------------------------------------------
# Top-level commands
# ---------------------------------------------------------------------------


def test_cmd_install_raises_if_already_installed(tmp_path, monkeypatch):
    apps_dir = tmp_path / "apps"
    apps_dir.mkdir()
    (apps_dir / "myapp.AppImage").write_text("x")
    monkeypatch.setattr(aim, "APPS_DIR", apps_dir)

    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    with pytest.raises(aim.AlreadyInstalledError):
        aim.cmd_install("org/myapp", registry=registry)


def test_cmd_update_one_raises_if_not_installed(tmp_path, monkeypatch):
    monkeypatch.setattr(aim, "APPS_DIR", tmp_path / "apps")
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")

    with pytest.raises(aim.NotInstalledError):
        aim.cmd_update_one("myapp", registry=registry)


class _MultiAppClient:
    """Fake GitHubReleaseClient returning a per-repo canned latest tag."""

    def __init__(self, tags: dict[str, str]):
        self.tags = tags

    def latest_release(self, repo):
        return {"tag_name": self.tags[repo], "assets": [{"name": "app.AppImage", "browser_download_url": "https://x/1"}]}

    def download(self, url, dest, progress=True):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(b"data")
        return dest


def test_check_all_updates_returns_only_apps_with_new_versions(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("appa", "org/appa")
    registry.register("appb", "org/appb")

    metadata = aim.AppMetadata(config_dir=tmp_path / "cfg", apps_dir=tmp_path / "apps", lib_dir=tmp_path / "lib")
    metadata.set_version("appa", "v1.0.0")  # up to date
    metadata.set_version("appb", "v1.0.0")  # will be behind

    client = _MultiAppClient({"org/appa": "v1.0.0", "org/appb": "v2.0.0"})

    pending = aim.check_all_updates(registry=registry, metadata=metadata, client=client)

    assert [p.name for p in pending] == ["appb"]
    assert pending[0].latest_tag == "v2.0.0"


def test_check_all_updates_empty_when_nothing_registered(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    assert aim.check_all_updates(registry=registry, client=_MultiAppClient({})) == []


def test_apply_updates_installs_each_pending_app(tmp_path):
    apps_dir = tmp_path / "apps"
    metadata = aim.AppMetadata(
        config_dir=tmp_path / "cfg", apps_dir=apps_dir, lib_dir=tmp_path / "lib",
        desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons",
    )
    client = _MultiAppClient({"org/appb": "v2.0.0"})

    pending = [
        aim.PendingUpdate(
            "appb", "org/appb", "v1.0.0", "v2.0.0",
            {"tag_name": "v2.0.0", "assets": [{"name": "app.AppImage", "browser_download_url": "https://x/1"}]},
        )
    ]

    aim.apply_updates(pending, metadata=metadata, client=client)

    assert metadata.get_version("appb") == "v2.0.0"
    assert (apps_dir / "appb.AppImage").exists()


def test_cmd_update_all_checks_only_without_yes(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("appb", "org/appb")
    metadata = aim.AppMetadata(
        config_dir=tmp_path / "cfg", apps_dir=tmp_path / "apps", lib_dir=tmp_path / "lib",
        desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons",
    )
    client = _MultiAppClient({"org/appb": "v2.0.0"})

    pending = aim.cmd_update_all(yes=False, registry=registry, metadata=metadata, client=client)

    assert [p.name for p in pending] == ["appb"]
    # Nothing applied without yes=True.
    assert metadata.get_version("appb") is None
    assert not (tmp_path / "apps" / "appb.AppImage").exists()


def test_cmd_update_all_applies_when_yes(tmp_path):
    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("appb", "org/appb")
    metadata = aim.AppMetadata(
        config_dir=tmp_path / "cfg", apps_dir=tmp_path / "apps", lib_dir=tmp_path / "lib",
        desktop_dir=tmp_path / "desktop", icon_dir=tmp_path / "icons",
    )
    client = _MultiAppClient({"org/appb": "v2.0.0"})

    pending = aim.cmd_update_all(yes=True, registry=registry, metadata=metadata, client=client)

    assert [p.name for p in pending] == ["appb"]
    assert metadata.get_version("appb") == "v2.0.0"
    assert (tmp_path / "apps" / "appb.AppImage").exists()


def test_cmd_uninstall_cleans_up_everything(tmp_path, monkeypatch):
    apps_dir = tmp_path / "apps"
    apps_dir.mkdir()
    lib_dir = tmp_path / "lib"
    (apps_dir / "myapp.AppImage").write_text("x")
    monkeypatch.setattr(aim, "APPS_DIR", apps_dir)
    monkeypatch.setattr(aim, "LIB_DIR", lib_dir)
    monkeypatch.setattr(aim, "BACKUP_DIR", tmp_path / "backup")
    monkeypatch.setattr(aim, "remove_desktop_entry", lambda name: None)
    monkeypatch.setattr(aim, "steam_remove_shortcut", lambda name: None)

    registry = aim.AppRegistry(conf_path=tmp_path / "apps.conf")
    registry.register("myapp", "org/myapp")

    aim.cmd_uninstall("myapp", registry=registry)

    assert not (apps_dir / "myapp.AppImage").exists()
    assert registry.get_repo("myapp") is None
