from steamostools.tools import steam_runtime


def test_find_conflicting_libs_matches_patterns(tmp_path):
    (tmp_path / "libgcc_s.so.1").write_text("x")
    (tmp_path / "libstdc++.so.6").write_text("x")
    (tmp_path / "unrelated.so").write_text("x")

    found = steam_runtime.find_conflicting_libs(tmp_path)

    names = {p.name for p in found}
    assert names == {"libgcc_s.so.1", "libstdc++.so.6"}


def test_fix_swrast_libgl_deletes_and_returns_removed(tmp_path):
    lib = tmp_path / "libxcb.so.1"
    lib.write_text("x")

    removed = steam_runtime.fix_swrast_libgl(tmp_path)

    assert removed == [lib]
    assert not lib.exists()


def test_fix_swrast_libgl_returns_empty_when_nothing_to_fix(tmp_path):
    assert steam_runtime.fix_swrast_libgl(tmp_path) == []
