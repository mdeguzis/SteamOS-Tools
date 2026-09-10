import pytest

from steamostools.platform_detect import Platform
from steamostools.tools import yay


def test_install_yay_skips_if_already_installed(monkeypatch):
    monkeypatch.setattr(yay, "require_platform", lambda *a, **kw: Platform.STEAMOS_ARCH)
    monkeypatch.setattr(yay, "is_yay_installed", lambda: True)
    calls = []
    monkeypatch.setattr(yay, "run", lambda cmd, **kw: calls.append(cmd))

    yay.install_yay()

    assert calls == []


def test_install_yay_builds_from_aur_when_missing(monkeypatch):
    monkeypatch.setattr(yay, "require_platform", lambda *a, **kw: Platform.STEAMOS_ARCH)
    # First check: not installed. After the "build" loop: installed.
    states = iter([False, True])
    monkeypatch.setattr(yay, "is_yay_installed", lambda: next(states))
    calls = []
    monkeypatch.setattr(yay, "run", lambda cmd, **kw: calls.append(cmd))

    yay.install_yay()

    assert ["sudo", "pacman", "-S", *yay.BASE_PACKAGES, "--noconfirm", "--needed"] in calls
    assert any(cmd[:2] == ["git", "clone"] and "auracle-git" in cmd[2] for cmd in calls)
    assert any(cmd[:2] == ["git", "clone"] and "/yay.git" in cmd[2] for cmd in calls)
    assert any(cmd[0] == "makepkg" for cmd in calls)


def test_install_yay_raises_if_still_missing_after_build(monkeypatch):
    monkeypatch.setattr(yay, "require_platform", lambda *a, **kw: Platform.STEAMOS_ARCH)
    monkeypatch.setattr(yay, "is_yay_installed", lambda: False)
    monkeypatch.setattr(yay, "run", lambda cmd, **kw: None)

    with pytest.raises(yay.YayInstallError):
        yay.install_yay()
