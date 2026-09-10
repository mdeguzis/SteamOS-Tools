from steamostools.tools import game_fixes


def test_apply_ultratron_fix_writes_controls_and_backs_up(tmp_path, monkeypatch):
    config_path = tmp_path / "controls.txt"
    config_path.write_text("old content")

    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        if cmd[:2] == ["sudo", "mv"]:
            # Simulate the real mv side effect so the test can assert on content.
            import shutil

            shutil.move(cmd[2], cmd[3])

    monkeypatch.setattr(game_fixes, "run", fake_run)

    game_fixes.apply_ultratron_xb360_fix(config_path)

    assert ["sudo", "cp", str(config_path), f"{config_path}.bak"] in calls
    assert any(c[:2] == ["sudo", "chmod"] for c in calls)
    assert any(c[:2] == ["sudo", "chown"] for c in calls)
    assert config_path.read_text() == game_fixes.ULTRATRON_CONTROLS


def test_apply_ultratron_fix_skips_backup_if_no_existing_file(tmp_path, monkeypatch):
    config_path = tmp_path / "controls.txt"
    calls = []
    monkeypatch.setattr(game_fixes, "run", lambda cmd, **kw: calls.append(cmd))

    game_fixes.apply_ultratron_xb360_fix(config_path)

    assert not any(c[:2] == ["sudo", "cp"] for c in calls)
