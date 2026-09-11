import pytest

from steamostools.vdf import shortcuts


def test_generate_appid_is_deterministic():
    a = shortcuts.generate_appid("/path/to/exe", "My App")
    b = shortcuts.generate_appid("/path/to/exe", "My App")
    assert a == b
    assert a > 0


def test_generate_appid_differs_for_different_inputs():
    a = shortcuts.generate_appid("/path/to/exe", "My App")
    b = shortcuts.generate_appid("/path/to/other-exe", "My App")
    assert a != b


def test_load_or_init_creates_skeleton_for_missing_file(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    data = shortcuts.load_or_init(vdf_path)
    assert data == shortcuts.HEADER + shortcuts.FOOTER


def test_load_or_init_reads_existing_file(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    vdf_path.write_bytes(b"some existing content here")
    assert shortcuts.load_or_init(vdf_path) == b"some existing content here"


def test_add_shortcut_creates_new_file(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    added = shortcuts.add_shortcut(vdf_path, "My App", "/apps/myapp", "/apps")

    assert added is True
    assert vdf_path.exists()
    data = vdf_path.read_bytes()
    assert data.startswith(shortcuts.HEADER)
    assert data.endswith(shortcuts.FOOTER)
    assert b"My App" in data
    assert b"/apps/myapp" in data


def test_add_shortcut_is_idempotent(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "My App", "/apps/myapp", "/apps")
    before = vdf_path.read_bytes()

    added_again = shortcuts.add_shortcut(vdf_path, "My App", "/apps/myapp", "/apps")

    assert added_again is False
    assert vdf_path.read_bytes() == before


def test_add_shortcut_appends_multiple_entries(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "App One", "/apps/one", "/apps")
    shortcuts.add_shortcut(vdf_path, "App Two", "/apps/two", "/apps")

    data = vdf_path.read_bytes()
    assert b"App One" in data
    assert b"App Two" in data
    assert shortcuts.count_entries(data) == 2


def test_add_shortcut_backs_up_existing_file(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "App One", "/apps/one", "/apps")
    shortcuts.add_shortcut(vdf_path, "App Two", "/apps/two", "/apps")

    backup = tmp_path / "shortcuts.vdf.bak"
    assert backup.exists()
    assert b"App One" in backup.read_bytes()
    assert b"App Two" not in backup.read_bytes()


def test_remove_shortcut_raises_when_file_missing(tmp_path):
    with pytest.raises(shortcuts.ShortcutNotFoundError):
        shortcuts.remove_shortcut(tmp_path / "shortcuts.vdf", "My App")


def test_remove_shortcut_raises_on_bad_header(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    vdf_path.write_bytes(b"not a valid vdf file")
    with pytest.raises(shortcuts.ShortcutsVdfFormatError):
        shortcuts.remove_shortcut(vdf_path, "My App")


def test_remove_shortcut_raises_when_app_not_present(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "App One", "/apps/one", "/apps")
    with pytest.raises(shortcuts.ShortcutNotFoundError):
        shortcuts.remove_shortcut(vdf_path, "Nonexistent App")


def test_remove_shortcut_removes_only_target_entry(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "App One", "/apps/one", "/apps")
    shortcuts.add_shortcut(vdf_path, "App Two", "/apps/two", "/apps")

    shortcuts.remove_shortcut(vdf_path, "App One")

    data = vdf_path.read_bytes()
    assert b"App One" not in data
    assert b"App Two" in data
    assert data.startswith(shortcuts.HEADER)
    assert data.endswith(shortcuts.FOOTER)


def test_remove_shortcut_backs_up_before_removal(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "App One", "/apps/one", "/apps")
    shortcuts.remove_shortcut(vdf_path, "App One")

    backup = tmp_path / "shortcuts.vdf.bak"
    assert backup.exists()
    assert b"App One" in backup.read_bytes()


def test_add_then_remove_all_leaves_empty_skeleton(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "Solo App", "/apps/solo", "/apps")
    shortcuts.remove_shortcut(vdf_path, "Solo App")

    data = vdf_path.read_bytes()
    assert data == shortcuts.HEADER + shortcuts.FOOTER


def test_add_or_update_flatpak_shortcut_adds_new_entry(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    status = shortcuts.add_or_update_flatpak_shortcut(
        vdf_path, "org.mozilla.firefox", "Firefox", "/icons/firefox.png"
    )

    assert status == "added"
    data = vdf_path.read_bytes()
    assert b"org.mozilla.firefox" in data
    assert b"/usr/bin/flatpak" in data
    assert b"run org.mozilla.firefox" in data


def test_add_or_update_flatpak_shortcut_updates_icon_in_place(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_or_update_flatpak_shortcut(vdf_path, "org.mozilla.firefox", "Firefox", "/icons/old.png")

    status = shortcuts.add_or_update_flatpak_shortcut(
        vdf_path, "org.mozilla.firefox", "Firefox", "/icons/new.png"
    )

    assert status == "icon_updated"
    data = vdf_path.read_bytes()
    assert b"/icons/new.png" in data
    assert b"/icons/old.png" not in data


def test_add_or_update_flatpak_shortcut_unchanged_when_icon_same(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_or_update_flatpak_shortcut(vdf_path, "org.mozilla.firefox", "Firefox", "/icons/same.png")

    status = shortcuts.add_or_update_flatpak_shortcut(
        vdf_path, "org.mozilla.firefox", "Firefox", "/icons/same.png"
    )

    assert status == "unchanged"


def test_add_or_update_flatpak_shortcut_preserves_other_entries(tmp_path):
    vdf_path = tmp_path / "shortcuts.vdf"
    shortcuts.add_shortcut(vdf_path, "Regular App", "/apps/regular", "/apps")
    shortcuts.add_or_update_flatpak_shortcut(vdf_path, "org.mozilla.firefox", "Firefox", "/icons/a.png")
    shortcuts.add_or_update_flatpak_shortcut(vdf_path, "org.mozilla.firefox", "Firefox", "/icons/b.png")

    data = vdf_path.read_bytes()
    assert b"Regular App" in data
    assert b"/icons/b.png" in data


def test_find_shortcuts_vdf_files_matches_userdata_layout(tmp_path):
    userdata = tmp_path / "userdata"
    vdf1 = userdata / "12345" / "config" / "shortcuts.vdf"
    vdf1.parent.mkdir(parents=True)
    vdf1.write_bytes(shortcuts.HEADER + shortcuts.FOOTER)

    found = shortcuts.find_shortcuts_vdf_files((userdata,))

    assert found == [vdf1.resolve()]


def test_find_shortcuts_vdf_files_returns_empty_when_no_userdata(tmp_path):
    assert shortcuts.find_shortcuts_vdf_files((tmp_path / "nonexistent",)) == []


def test_find_shortcuts_vdf_files_dedupes_across_multiple_roots(tmp_path):
    userdata = tmp_path / "userdata"
    vdf1 = userdata / "1" / "config" / "shortcuts.vdf"
    vdf1.parent.mkdir(parents=True)
    vdf1.write_bytes(b"x")

    # A second "root" that's actually a symlink to the same tree should
    # dedupe via resolve().
    alt_root = tmp_path / "alt_userdata"
    alt_root.symlink_to(userdata)

    found = shortcuts.find_shortcuts_vdf_files((userdata, alt_root))
    assert found == [vdf1.resolve()]
