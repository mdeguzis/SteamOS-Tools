import pytest
import responses

from steamostools.tools import nexus_downloader
from steamostools.tools.nexus_downloader import InvalidNexusUrlError, NexusApiError, NexusClient


def test_load_api_key_raises_if_missing(tmp_path):
    with pytest.raises(NexusApiError, match="missing"):
        nexus_downloader.load_api_key(tmp_path / "nofile")


def test_load_api_key_raises_if_empty(tmp_path):
    token_file = tmp_path / "token"
    token_file.write_text("   \n")
    with pytest.raises(NexusApiError, match="empty"):
        nexus_downloader.load_api_key(token_file)


def test_load_api_key_strips_whitespace(tmp_path):
    token_file = tmp_path / "token"
    token_file.write_text("  mykey123  \n")
    assert nexus_downloader.load_api_key(token_file) == "mykey123"


def test_parse_mod_url_extracts_domain_and_id():
    domain, mod_id = nexus_downloader.parse_mod_url(
        "https://www.nexusmods.com/residentevil5goldedition/mods/737"
    )
    assert domain == "residentevil5goldedition"
    assert mod_id == "737"


def test_parse_mod_url_raises_on_invalid_format():
    with pytest.raises(InvalidNexusUrlError):
        nexus_downloader.parse_mod_url("https://example.com/not-a-nexus-url")


def test_resolve_game_id_maps_known_slug():
    assert nexus_downloader.resolve_game_id("cyberpunk2077") == "3333"


def test_resolve_game_id_passes_through_unmapped():
    assert nexus_downloader.resolve_game_id("someRandomGame") == "someRandomGame"


@responses.activate
def test_search_raises_on_graphql_error():
    responses.add(
        responses.POST,
        "https://api.nexusmods.com/v2/graphql",
        json={"errors": [{"message": "bad query"}]},
        status=200,
    )
    client = NexusClient(api_key="key")
    with pytest.raises(NexusApiError, match="bad query"):
        client.search("cyberpunk2077", "quality of life")


@responses.activate
def test_search_returns_nodes():
    responses.add(
        responses.POST,
        "https://api.nexusmods.com/v2/graphql",
        json={"data": {"mods": {"nodes": [{"id": 1, "name": "Test Mod", "summary": "desc"}]}}},
        status=200,
    )
    client = NexusClient(api_key="key")
    results = client.search("cyberpunk2077", "test")
    assert results == [{"id": 1, "name": "Test Mod", "summary": "desc"}]


@responses.activate
def test_list_files_raises_on_api_message_error():
    responses.add(
        responses.GET,
        "https://api.nexusmods.com/v1/games/game/mods/1/files.json",
        json={"message": "Mod not found"},
        status=200,
    )
    client = NexusClient(api_key="key")
    with pytest.raises(NexusApiError, match="Mod not found"):
        client.list_files("game", "1")


@responses.activate
def test_list_files_returns_files():
    responses.add(
        responses.GET,
        "https://api.nexusmods.com/v1/games/game/mods/1/files.json",
        json={"files": [{"file_id": 5, "name": "patch.zip"}]},
        status=200,
    )
    client = NexusClient(api_key="key")
    assert client.list_files("game", "1") == [{"file_id": 5, "name": "patch.zip"}]


@responses.activate
def test_get_download_url_raises_when_missing():
    responses.add(
        responses.GET,
        "https://api.nexusmods.com/v1/games/game/mods/1/files/5/download_link.json",
        json=[],
        status=200,
    )
    client = NexusClient(api_key="key")
    with pytest.raises(NexusApiError):
        client.get_download_url("game", "1", "5")


@responses.activate
def test_get_download_url_returns_uri():
    responses.add(
        responses.GET,
        "https://api.nexusmods.com/v1/games/game/mods/1/files/5/download_link.json",
        json=[{"URI": "https://cdn.example.com/patch.zip"}],
        status=200,
    )
    client = NexusClient(api_key="key")
    assert client.get_download_url("game", "1", "5") == "https://cdn.example.com/patch.zip"


@responses.activate
def test_download_writes_file(tmp_path):
    responses.add(
        responses.GET, "https://cdn.example.com/patch.zip", body=b"zipdata", status=200
    )
    client = NexusClient(api_key="key")
    dest = client.download("https://cdn.example.com/patch.zip", tmp_path)
    assert dest == tmp_path / "patch.zip"
    assert dest.read_bytes() == b"zipdata"
