import pytest

from steamostools.tools.rom_tools import (
    find_prefixed_files,
    load_rom_list,
    migrate_roms,
    resolve_src_dest,
    strip_leading_numbers,
)


def test_resolve_src_dest_archive(tmp_path):
    working = tmp_path / "work"
    archive = tmp_path / "archive"
    src, dest = resolve_src_dest("archive", working, archive)
    assert src == working
    assert dest == archive


def test_resolve_src_dest_unarchive(tmp_path):
    working = tmp_path / "work"
    archive = tmp_path / "archive"
    src, dest = resolve_src_dest("unarchive", working, archive)
    assert src == archive
    assert dest == working


def test_resolve_src_dest_rejects_invalid_operation(tmp_path):
    with pytest.raises(ValueError):
        resolve_src_dest("bogus", tmp_path, tmp_path)


def test_load_rom_list_strips_blank_lines(tmp_path):
    romlist = tmp_path / "list.txt"
    romlist.write_text("game1.zip\n\ngame2.zip\n  \n")
    assert load_rom_list(romlist) == ["game1.zip", "game2.zip"]


def test_migrate_roms_moves_found_files(tmp_path):
    src = tmp_path / "src"
    dest = tmp_path / "dest"
    src.mkdir()
    (src / "game1.zip").write_text("data")

    result = migrate_roms("psp", ["game1.zip"], src, dest)

    assert result.moved == ["game1.zip"]
    assert result.skipped == []
    assert (dest / "game1.zip").exists()
    assert not (src / "game1.zip").exists()


def test_migrate_roms_skips_missing_files_without_raising(tmp_path):
    src = tmp_path / "src"
    dest = tmp_path / "dest"
    src.mkdir()

    result = migrate_roms("psp", ["missing.zip"], src, dest)

    assert result.moved == []
    assert result.skipped == ["missing.zip"]


def test_migrate_roms_mame_moves_matching_chd_folder(tmp_path):
    src = tmp_path / "src"
    dest = tmp_path / "dest"
    src.mkdir()
    (src / "somegame.zip").write_text("data")
    chd_dir = src / "somegame"
    chd_dir.mkdir()
    (chd_dir / "somegame.chd").write_text("chd-data")

    result = migrate_roms("mame", ["somegame.zip"], src, dest)

    assert result.moved == ["somegame.zip"]
    assert (dest / "somegame.zip").exists()
    assert (dest / "somegame" / "somegame.chd").exists()


def test_find_prefixed_files_matches_three_digit_prefix(tmp_path):
    (tmp_path / "042 Some Game.zip").write_text("x")
    (tmp_path / "Some Other Game.zip").write_text("x")
    found = find_prefixed_files(tmp_path)
    assert [p.name for p in found] == ["042 Some Game.zip"]


def test_strip_leading_numbers_renames_files(tmp_path):
    original = tmp_path / "042 Some Game.zip"
    original.write_text("x")

    renamed = strip_leading_numbers(tmp_path)

    assert len(renamed) == 1
    assert not original.exists()
    assert (tmp_path / "Some Game.zip").exists()


def test_strip_leading_numbers_dry_run_does_not_rename(tmp_path):
    original = tmp_path / "042 Some Game.zip"
    original.write_text("x")

    renamed = strip_leading_numbers(tmp_path, dry_run=True)

    assert len(renamed) == 1
    assert original.exists()
    assert not (tmp_path / "Some Game.zip").exists()
