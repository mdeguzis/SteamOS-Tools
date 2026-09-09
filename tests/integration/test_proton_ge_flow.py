"""Full download+extract flow for `steamos-tools proton get-ge`, against a
mocked GitHub API (not a mocked GitHubReleaseClient) and a real tmp
filesystem -- this is the integration-level counterpart to
tests/unit/test_proton_ge.py, which mocks the client directly."""

import tarfile

import responses

from steamostools.github_releases import GitHubReleaseClient
from steamostools.tools import proton_ge


def _fake_release_response(tag: str):
    return {
        "tag_name": tag,
        "assets": [
            {
                "name": f"{tag}.tar.gz",
                "browser_download_url": f"https://github.com/example/releases/download/{tag}/{tag}.tar.gz",
            }
        ],
    }


def _fake_tarball_bytes(tmp_path, folder_name: str) -> bytes:
    src_dir = tmp_path / "fixture" / folder_name
    src_dir.mkdir(parents=True)
    (src_dir / "proton").write_text("#!/bin/sh\necho fake proton\n")
    tar_path = tmp_path / f"{folder_name}-fixture.tar.gz"
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(src_dir, arcname=folder_name)
    return tar_path.read_bytes()


@responses.activate
def test_install_latest_end_to_end_native(monkeypatch, tmp_path):
    tag = "GE-Proton9-99"
    responses.add(
        responses.GET,
        f"https://api.github.com/repos/{proton_ge.GITHUB_REPO}/releases/latest",
        json=_fake_release_response(tag),
        status=200,
    )
    responses.add(
        responses.GET,
        f"https://github.com/example/releases/download/{tag}/{tag}.tar.gz",
        body=_fake_tarball_bytes(tmp_path, f"Proton-{tag}"),
        status=200,
    )

    target_dir = tmp_path / "compatibilitytools.d"
    monkeypatch.setattr(proton_ge, "NATIVE_COMPAT_DIR", target_dir)

    download_dir = tmp_path / "downloads"
    download_dir.mkdir()

    result = proton_ge.install_latest(
        "native", client=GitHubReleaseClient(), download_dir=download_dir
    )

    assert result == target_dir / f"Proton-{tag}"
    assert (result / "proton").read_text() == "#!/bin/sh\necho fake proton\n"
    assert (download_dir / f"{tag}.tar.gz").exists()


@responses.activate
def test_install_latest_raises_cleanly_on_404(monkeypatch, tmp_path):
    responses.add(
        responses.GET,
        f"https://api.github.com/repos/{proton_ge.GITHUB_REPO}/releases/latest",
        json={"message": "Not Found"},
        status=404,
    )
    monkeypatch.setattr(proton_ge, "NATIVE_COMPAT_DIR", tmp_path / "compat")

    import pytest
    import requests

    with pytest.raises(requests.HTTPError):
        proton_ge.install_latest("native", client=GitHubReleaseClient(), download_dir=tmp_path)
