import pytest
import responses

from steamostools.github_releases import GitHubReleaseClient, NoMatchingAssetError


@responses.activate
def test_latest_release_returns_json():
    responses.add(
        responses.GET,
        "https://api.github.com/repos/owner/repo/releases/latest",
        json={"tag_name": "v1.2.3", "assets": []},
        status=200,
    )
    client = GitHubReleaseClient()
    release = client.latest_release("owner/repo")
    assert release["tag_name"] == "v1.2.3"


@responses.activate
def test_latest_release_raises_on_http_error():
    responses.add(
        responses.GET,
        "https://api.github.com/repos/owner/repo/releases/latest",
        json={"message": "Not Found"},
        status=404,
    )
    client = GitHubReleaseClient()
    with pytest.raises(Exception):
        client.latest_release("owner/repo")


@responses.activate
def test_list_releases_returns_all_including_prereleases():
    responses.add(
        responses.GET,
        "https://api.github.com/repos/owner/repo/releases",
        json=[{"tag_name": "v2.0.0-beta", "prerelease": True}, {"tag_name": "v1.0.0", "prerelease": False}],
        status=200,
    )
    client = GitHubReleaseClient()
    releases = client.list_releases("owner/repo")
    assert releases[0]["tag_name"] == "v2.0.0-beta"
    assert len(releases) == 2


@responses.activate
def test_list_releases_raises_on_http_error():
    responses.add(
        responses.GET, "https://api.github.com/repos/owner/repo/releases", status=404
    )
    client = GitHubReleaseClient()
    with pytest.raises(Exception):
        client.list_releases("owner/repo")


def test_pick_asset_matches_pattern():
    client = GitHubReleaseClient()
    assets = [{"name": "foo-linux-x86_64.tar.gz"}, {"name": "foo-windows.zip"}]
    picked = client.pick_asset(assets, [r"linux.*\.tar\.gz$"])
    assert picked["name"] == "foo-linux-x86_64.tar.gz"


def test_pick_asset_raises_when_no_match():
    client = GitHubReleaseClient()
    assets = [{"name": "foo-windows.zip"}]
    with pytest.raises(NoMatchingAssetError):
        client.pick_asset(assets, [r"linux.*\.tar\.gz$"])


@responses.activate
def test_download_writes_file(tmp_path):
    responses.add(
        responses.GET,
        "https://example.com/file.tar.gz",
        body=b"fake archive bytes",
        status=200,
    )
    client = GitHubReleaseClient()
    dest = tmp_path / "out" / "file.tar.gz"
    result = client.download("https://example.com/file.tar.gz", dest, progress=False)
    assert result == dest
    assert dest.read_bytes() == b"fake archive bytes"


@responses.activate
def test_download_raises_on_http_error(tmp_path):
    responses.add(responses.GET, "https://example.com/missing.tar.gz", status=404)
    client = GitHubReleaseClient()
    with pytest.raises(Exception):
        client.download("https://example.com/missing.tar.gz", tmp_path / "missing.tar.gz", progress=False)
