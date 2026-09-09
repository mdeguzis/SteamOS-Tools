import pytest

from steamostools.platform_detect import Platform, UnsupportedPlatformError
from steamostools.tools import unlock


def test_unlock_and_prepare_runs_expected_commands(monkeypatch):
    monkeypatch.setattr(unlock, "require_platform", lambda *a, **kw: Platform.STEAMOS_ARCH)
    calls = []
    monkeypatch.setattr(unlock, "run", lambda cmd, **kw: calls.append(cmd))

    unlock.unlock_and_prepare()

    assert ["sudo", "steamos-readonly", "disable"] in calls
    assert ["sudo", "pacman-key", "--init"] in calls
    assert ["sudo", "pacman-key", "--populate", "holo"] in calls
    assert ["sudo", "pacman", "-Syy"] in calls
    assert ["sudo", "pacman", "-S", "--noconfirm", "base-devel"] in calls


def test_unlock_and_prepare_raises_on_unsupported_platform(monkeypatch):
    def _raise(*a, **kw):
        raise UnsupportedPlatformError("nope")

    monkeypatch.setattr(unlock, "require_platform", _raise)
    with pytest.raises(UnsupportedPlatformError):
        unlock.unlock_and_prepare()
