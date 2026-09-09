import pytest

from steamostools.platform_detect import Platform, UnsupportedPlatformError, detect_platform, require_platform


def _write_os_release(path, content):
    path.write_text(content)


def test_detect_platform_arch(tmp_path, monkeypatch):
    os_release = tmp_path / "os-release"
    _write_os_release(os_release, 'ID=arch\nID_LIKE=""\n')
    monkeypatch.setattr("steamostools.platform_detect._read_os_release", lambda path=None: {"ID": "arch"})
    monkeypatch.setattr("pathlib.Path.exists", lambda self: False)
    monkeypatch.setattr("shutil.which", lambda name: None)
    assert detect_platform() == Platform.STEAMOS_ARCH


def test_detect_platform_chimeraos(monkeypatch):
    monkeypatch.setattr("pathlib.Path.exists", lambda self: str(self) == "/usr/bin/frzr-unlock")
    monkeypatch.setattr("steamostools.platform_detect._read_os_release", lambda path=None: {})
    assert detect_platform() == Platform.CHIMERAOS


def test_detect_platform_bazzite_ostree(monkeypatch):
    monkeypatch.setattr("pathlib.Path.exists", lambda self: False)
    monkeypatch.setattr("shutil.which", lambda name: "/usr/bin/rpm-ostree" if name == "rpm-ostree" else None)
    monkeypatch.setattr("steamostools.platform_detect._read_os_release", lambda path=None: {})
    assert detect_platform() == Platform.BAZZITE_OSTREE


def test_detect_platform_unsupported(monkeypatch):
    monkeypatch.setattr("pathlib.Path.exists", lambda self: False)
    monkeypatch.setattr("shutil.which", lambda name: None)
    monkeypatch.setattr("steamostools.platform_detect._read_os_release", lambda path=None: {"ID": "debian"})
    assert detect_platform() == Platform.UNSUPPORTED


def test_require_platform_raises_with_clear_message(monkeypatch):
    monkeypatch.setattr("steamostools.platform_detect.detect_platform", lambda: Platform.UNSUPPORTED)
    with pytest.raises(UnsupportedPlatformError, match="steamos-arch"):
        require_platform(Platform.STEAMOS_ARCH)


def test_require_platform_passes_when_matching(monkeypatch):
    monkeypatch.setattr("steamostools.platform_detect.detect_platform", lambda: Platform.STEAMOS_ARCH)
    assert require_platform(Platform.STEAMOS_ARCH) == Platform.STEAMOS_ARCH
