from steamostools.systemd_units import SystemdUserUnit


def _fake_run(calls):
    def _run(cmd, **kwargs):
        calls.append(cmd)

        class _Result:
            returncode = 0
            stdout = "active"

        return _Result()

    return _run


def test_install_writes_unit_files_and_reloads(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr("steamostools.systemd_units.run", _fake_run(calls))

    unit = SystemdUserUnit(["thing.service"], unit_dir=tmp_path)
    unit.install({"thing.service": "[Unit]\nDescription=test\n"})

    written = tmp_path / "thing.service"
    assert written.exists()
    assert "Description=test" in written.read_text()
    assert ["systemctl", "--user", "daemon-reload"] in calls


def test_enable_now_calls_systemctl_per_unit(monkeypatch):
    calls = []
    monkeypatch.setattr("steamostools.systemd_units.run", _fake_run(calls))

    unit = SystemdUserUnit(["a.service", "b.timer"])
    unit.enable_now()

    assert ["systemctl", "--user", "enable", "--now", "a.service"] in calls
    assert ["systemctl", "--user", "enable", "--now", "b.timer"] in calls


def test_uninstall_disables_and_removes_files(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr("steamostools.systemd_units.run", _fake_run(calls))

    unit_file = tmp_path / "thing.service"
    unit_file.write_text("[Unit]\n")

    unit = SystemdUserUnit(["thing.service"], unit_dir=tmp_path)
    unit.uninstall()

    assert not unit_file.exists()
    assert ["systemctl", "--user", "disable", "--now", "thing.service"] in calls
    assert ["systemctl", "--user", "daemon-reload"] in calls


def test_status_returns_stdout(monkeypatch):
    monkeypatch.setattr("steamostools.systemd_units.run", _fake_run([]))
    unit = SystemdUserUnit(["thing.service"])
    assert unit.status("thing.service") == "active"
