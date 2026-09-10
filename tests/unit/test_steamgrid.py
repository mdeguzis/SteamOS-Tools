import zipfile

import pytest

from steamostools.tools import steamgrid


class _FakeClient:
    def __init__(self, zip_bytes: bytes):
        self.zip_bytes = zip_bytes

    def latest_release(self, repo):
        return {
            "assets": [
                {"name": "steamgrid_linux.zip", "browser_download_url": "https://example.com/steamgrid_linux.zip"}
            ]
        }

    def pick_asset(self, assets, patterns):
        return assets[0]

    def download(self, url, dest, progress=True):
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(self.zip_bytes)
        return dest


def _make_zip_bytes(tmp_path) -> bytes:
    zip_path = tmp_path / "fixture.zip"
    with zipfile.ZipFile(zip_path, "w") as zf:
        zf.writestr("steamgrid", "#!/bin/sh\necho fake\n")
    return zip_path.read_bytes()


def test_install_steamgrid_extracts_and_symlinks(tmp_path):
    client = _FakeClient(_make_zip_bytes(tmp_path))
    software_root = tmp_path / "software" / "steamgrid"
    bin_link = tmp_path / "bin" / "steamgrid"

    binary = steamgrid.install_steamgrid(
        client=client, software_root=software_root, bin_link=bin_link, download_dir=tmp_path / "dl"
    )

    assert binary == software_root / "steamgrid"
    assert binary.exists()
    assert bin_link.is_symlink()
    assert bin_link.resolve() == binary.resolve()


def test_install_steamgrid_wipes_existing_software_root(tmp_path):
    software_root = tmp_path / "software" / "steamgrid"
    software_root.mkdir(parents=True)
    (software_root / "stale-file").write_text("old")

    client = _FakeClient(_make_zip_bytes(tmp_path))
    steamgrid.install_steamgrid(
        client=client,
        software_root=software_root,
        bin_link=tmp_path / "bin" / "steamgrid",
        download_dir=tmp_path / "dl",
    )

    assert not (software_root / "stale-file").exists()


def test_run_steamgrid_raises_if_not_installed(tmp_path):
    with pytest.raises(FileNotFoundError):
        steamgrid.run_steamgrid(tmp_path / "nowhere")


def test_run_steamgrid_invokes_binary(tmp_path, monkeypatch):
    software_root = tmp_path / "software"
    software_root.mkdir()
    (software_root / "steamgrid").write_text("#!/bin/sh\n")

    calls = []
    monkeypatch.setattr(steamgrid, "run", lambda cmd, **kw: calls.append(cmd))

    steamgrid.run_steamgrid(software_root)

    assert calls == [[str(software_root / "steamgrid")]]
