from steamostools.tools import supertuxkart


def test_default_paths_derives_from_home(tmp_path):
    config_dir, data_dir = supertuxkart.default_paths(tmp_path)
    assert config_dir == tmp_path / ".config" / "supertuxkart"
    assert data_dir == tmp_path / ".local" / "share" / "supertuxkart"


def test_backup_copies_existing_dirs(tmp_path):
    config_dir = tmp_path / "config"
    data_dir = tmp_path / "data"
    config_dir.mkdir()
    (config_dir / "player.cfg").write_text("x")
    # data_dir intentionally left missing to exercise the skip path

    backup_root = tmp_path / "backups"
    backup_dir = supertuxkart.backup_supertuxkart(config_dir=config_dir, data_dir=data_dir, backup_root=backup_root)

    assert (backup_dir / "config" / "player.cfg").exists()
    assert not (backup_dir / "data").exists()


def test_copy_backup_to_alt_location(tmp_path):
    backup_dir = tmp_path / "backups" / "2026-01-01-backup"
    backup_dir.mkdir(parents=True)
    (backup_dir / "file.txt").write_text("x")

    alt = tmp_path / "alt"
    dest = supertuxkart.copy_backup_to(backup_dir, alt)

    assert (dest / "file.txt").exists()
