from steamostools.tools import retroarch


def test_launch_normal_mode_uses_config(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(retroarch, "run", lambda cmd, **kw: calls.append(cmd))

    config = tmp_path / "retroarch.cfg"
    retroarch.launch(debug=False, config=config)

    assert calls == [["retroarch", "--config", str(config), "--menu"]]


def test_launch_debug_mode_appends_output_to_log(tmp_path, monkeypatch):
    class _Result:
        stdout = "verbose output line\n"
        stderr = "a warning\n"

    monkeypatch.setattr(retroarch, "run", lambda cmd, **kw: _Result())

    log_file = tmp_path / "retroarch" / "log.txt"
    retroarch.launch(debug=True, log_file=log_file)

    content = log_file.read_text()
    assert "verbose output line" in content
    assert "a warning" in content


def test_launch_debug_mode_uses_verbose_flag(tmp_path, monkeypatch):
    calls = []

    class _Result:
        stdout = ""
        stderr = ""

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return _Result()

    monkeypatch.setattr(retroarch, "run", fake_run)
    retroarch.launch(debug=True, log_file=tmp_path / "log.txt")

    assert calls == [["retroarch", "--menu", "--verbose"]]


def test_launch_debug_mode_appends_across_multiple_runs(tmp_path, monkeypatch):
    class _Result:
        stdout = "run output\n"
        stderr = ""

    monkeypatch.setattr(retroarch, "run", lambda cmd, **kw: _Result())
    log_file = tmp_path / "log.txt"

    retroarch.launch(debug=True, log_file=log_file)
    retroarch.launch(debug=True, log_file=log_file)

    assert log_file.read_text().count("run output") == 2
