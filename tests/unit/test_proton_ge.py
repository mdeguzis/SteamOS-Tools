import pytest

from steamostools.tools import proton_ge


def test_compat_tools_dir_flatpak(monkeypatch, tmp_path):
    monkeypatch.setattr(proton_ge, "FLATPAK_COMPAT_DIR", tmp_path / "flatpak")
    assert proton_ge.compat_tools_dir("flatpak") == tmp_path / "flatpak"


def test_compat_tools_dir_native_and_steamos_share_path(monkeypatch, tmp_path):
    monkeypatch.setattr(proton_ge, "NATIVE_COMPAT_DIR", tmp_path / "native")
    assert proton_ge.compat_tools_dir("native") == tmp_path / "native"
    assert proton_ge.compat_tools_dir("steamos") == tmp_path / "native"


def test_compat_tools_dir_rejects_invalid_type():
    with pytest.raises(ValueError):
        proton_ge.compat_tools_dir("bogus")


class _FakeClient:
    def __init__(self, tag="v9.0", asset_bytes=b"fake tarball"):
        self.tag = tag
        self.asset_bytes = asset_bytes

    def latest_release(self, repo):
        return {
            "tag_name": self.tag,
            "assets": [{"name": f"{self.tag}.tar.gz", "browser_download_url": "https://example.com/a.tar.gz"}],
        }

    def pick_asset(self, assets, patterns):
        return assets[0]

    def download(self, url, dest, progress=True):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(self.asset_bytes)
        return dest


def _make_real_tarball(tmp_path, folder_name):
    import tarfile

    src_dir = tmp_path / "src" / folder_name
    src_dir.mkdir(parents=True)
    (src_dir / "proton").write_text("#!/bin/sh\n")
    tar_path = tmp_path / f"{folder_name}.tar.gz"
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(src_dir, arcname=folder_name)
    return tar_path


def test_install_latest_extracts_to_target(monkeypatch, tmp_path):
    target_dir = tmp_path / "compat"
    monkeypatch.setattr(proton_ge, "NATIVE_COMPAT_DIR", target_dir)

    tarball = _make_real_tarball(tmp_path, "Proton-v9.0")
    client = _FakeClient(tag="v9.0", asset_bytes=tarball.read_bytes())

    download_dir = tmp_path / "downloads"
    download_dir.mkdir()

    result = proton_ge.install_latest("native", client=client, download_dir=download_dir)

    assert result == target_dir / "Proton-v9.0"
    assert (result / "proton").exists()


def test_install_latest_raises_if_already_installed(monkeypatch, tmp_path):
    target_dir = tmp_path / "compat"
    (target_dir / "Proton-v9.0").mkdir(parents=True)
    monkeypatch.setattr(proton_ge, "NATIVE_COMPAT_DIR", target_dir)

    client = _FakeClient(tag="v9.0")
    with pytest.raises(proton_ge.AlreadyInstalledError):
        proton_ge.install_latest("native", client=client, download_dir=tmp_path)
