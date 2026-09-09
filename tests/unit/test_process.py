import subprocess

import pytest

from steamostools.process import PrivilegeError, is_root, require_root, run


def test_run_returns_completed_process_on_success():
    result = run(["true"])
    assert result.returncode == 0


def test_run_raises_on_failure():
    with pytest.raises(subprocess.CalledProcessError):
        run(["false"])


def test_run_raises_on_missing_binary():
    with pytest.raises(FileNotFoundError):
        run(["definitely-not-a-real-command-xyz"])


def test_run_does_not_raise_when_check_false():
    result = run(["false"], check=False)
    assert result.returncode != 0


def test_is_root_matches_geteuid(monkeypatch):
    monkeypatch.setattr("os.geteuid", lambda: 0)
    assert is_root() is True
    monkeypatch.setattr("os.geteuid", lambda: 1000)
    assert is_root() is False


def test_require_root_passes_when_root(monkeypatch):
    monkeypatch.setattr("os.geteuid", lambda: 0)
    require_root("testing")  # should not raise


def test_require_root_passes_when_sudo_available(monkeypatch):
    monkeypatch.setattr("os.geteuid", lambda: 1000)
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/sudo")
    require_root("testing")  # should not raise


def test_require_root_raises_when_no_root_and_no_sudo(monkeypatch):
    monkeypatch.setattr("os.geteuid", lambda: 1000)
    monkeypatch.setattr("shutil.which", lambda name: None)
    with pytest.raises(PrivilegeError, match="testing"):
        require_root("testing")
