from steamostools.tools import x11_forwarding


def test_missing_lines_returns_all_when_file_absent(tmp_path):
    sshd_config = tmp_path / "sshd_config"
    assert x11_forwarding.missing_lines(sshd_config) == list(x11_forwarding.REQUIRED_LINES)


def test_missing_lines_returns_only_absent_ones(tmp_path):
    sshd_config = tmp_path / "sshd_config"
    sshd_config.write_text("X11Forwarding yes\n")
    assert x11_forwarding.missing_lines(sshd_config) == ["X11DisplayOffset 10"]


def test_missing_lines_empty_when_all_present(tmp_path):
    sshd_config = tmp_path / "sshd_config"
    sshd_config.write_text("X11Forwarding yes\nX11DisplayOffset 10\n")
    assert x11_forwarding.missing_lines(sshd_config) == []


def test_enable_x11_forwarding_adds_missing_lines_and_restarts_sshd(tmp_path, monkeypatch):
    sshd_config = tmp_path / "sshd_config"
    sshd_config.write_text("")
    calls = []
    monkeypatch.setattr(x11_forwarding, "run", lambda cmd, **kw: calls.append(cmd))

    added = x11_forwarding.enable_x11_forwarding(sshd_config)

    assert added == list(x11_forwarding.REQUIRED_LINES)
    assert any("kill -1" in " ".join(c) for c in calls)


def test_enable_x11_forwarding_skips_restart_when_nothing_added(tmp_path, monkeypatch):
    sshd_config = tmp_path / "sshd_config"
    sshd_config.write_text("X11Forwarding yes\nX11DisplayOffset 10\n")
    calls = []
    monkeypatch.setattr(x11_forwarding, "run", lambda cmd, **kw: calls.append(cmd))

    added = x11_forwarding.enable_x11_forwarding(sshd_config)

    assert added == []
    assert calls == []
