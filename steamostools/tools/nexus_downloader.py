"""Search/list/download mods via the Nexus Mods API.

Port of scripts/nexus-downloader.sh. The API key is read from ~/.nexusapi
same as the original; unlike the bash version, the search query is sent as
a properly-encoded JSON request body instead of being interpolated
directly into a GraphQL query string.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

import requests

logger = logging.getLogger("steamostools.nexus_downloader")

TOKEN_FILE = Path.home() / ".nexusapi"
API_V1_BASE = "https://api.nexusmods.com/v1"
API_GRAPHQL = "https://api.nexusmods.com/v2/graphql"
DOWNLOAD_CHUNK_BYTES = 1024 * 64

NEXUS_URL_RE = re.compile(r"nexusmods\.com/([^/]+)/mods/(\d+)")

# Common alphanumeric slugs mapped to Nexus internal GraphQL game IDs.
GAME_SLUG_TO_ID = {
    "residentevil5goldedition": "125",
    "residentevil5": "125",
    "cyberpunk2077": "3333",
    "skyrimspecialedition": "1704",
    "fallout4": "1151",
}


class NexusApiError(RuntimeError):
    pass


class InvalidNexusUrlError(ValueError):
    pass


def load_api_key(token_file: Path = TOKEN_FILE) -> str:
    if not token_file.exists():
        raise NexusApiError(
            f"API token file missing at {token_file}. "
            f"Save your token there first: echo 'YOUR_KEY' > {token_file}"
        )
    key = token_file.read_text().strip()
    if not key:
        raise NexusApiError(f"Token file at {token_file} is empty.")
    return key


def parse_mod_url(url: str) -> tuple[str, str]:
    m = NEXUS_URL_RE.search(url)
    if not m:
        raise InvalidNexusUrlError(
            f"Invalid Nexus URL format: {url!r}. Expected https://www.nexusmods.com/<game>/mods/<id>"
        )
    return m.group(1), m.group(2)


def resolve_game_id(game: str) -> str:
    """Map a known game slug to its Nexus GraphQL game ID. An already-numeric
    input, or an unmapped slug, is passed through as-is (matching the
    original script's fallback behavior)."""
    return GAME_SLUG_TO_ID.get(game, game)


class NexusClient:
    def __init__(self, api_key: str | None = None, session: requests.Session | None = None):
        self.api_key = api_key or load_api_key()
        self.session = session or requests.Session()

    def _headers(self) -> dict:
        return {"apikey": self.api_key, "accept": "application/json"}

    def search(self, game: str, query: str) -> list[dict]:
        game_id = resolve_game_id(game)
        graphql_query = (
            "query { mods(filter: { name: { value: $name, op: WILDCARD }, "
            "gameId: { value: $gameId, op: WILDCARD } }) { nodes { id name summary } } }"
        )
        response = self.session.post(
            API_GRAPHQL,
            json={
                "query": graphql_query,
                "variables": {"name": query, "gameId": game_id},
            },
            headers={"Content-Type": "application/json", "apikey": self.api_key},
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        if "errors" in data:
            raise NexusApiError(data["errors"][0].get("message", "GraphQL error"))
        return data["data"]["mods"]["nodes"]

    def list_files(self, game_domain: str, mod_id: str) -> list[dict]:
        response = self.session.get(
            f"{API_V1_BASE}/games/{game_domain}/mods/{mod_id}/files.json",
            headers=self._headers(),
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        if isinstance(data, dict) and "message" in data:
            raise NexusApiError(data["message"])
        return data["files"]

    def get_download_url(self, game_domain: str, mod_id: str, file_id: str) -> str:
        response = self.session.get(
            f"{API_V1_BASE}/games/{game_domain}/mods/{mod_id}/files/{file_id}/download_link.json",
            headers=self._headers(),
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()
        if not data or not data[0].get("URI"):
            raise NexusApiError(f"Could not resolve download URL for file {file_id}")
        return data[0]["URI"]

    def download(self, url: str, dest_dir: Path = Path(".")) -> Path:
        response = self.session.get(url, stream=True, timeout=30)
        response.raise_for_status()
        filename = url.split("?")[0].rsplit("/", 1)[-1]
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest = dest_dir / filename
        with dest.open("wb") as f:
            for chunk in response.iter_content(chunk_size=DOWNLOAD_CHUNK_BYTES):
                f.write(chunk)
        return dest


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("nexus", help="search/list/download mods via the Nexus Mods API")
    sub = parser.add_subparsers(dest="nexus_command", required=True)

    search = sub.add_parser("search", help="search Nexus for mods matching a term")
    search.add_argument("game")
    search.add_argument("query")
    search.set_defaults(func=_cmd_search)

    list_cmd = sub.add_parser("list", help="list all available files for a mod")
    list_cmd.add_argument("mod_url")
    list_cmd.set_defaults(func=_cmd_list)

    download = sub.add_parser("download", help="download a mod file")
    download.add_argument("mod_url")
    download.add_argument("file_id", nargs="?", default=None)
    download.add_argument("--dest-dir", type=Path, default=Path("."))
    download.set_defaults(func=_cmd_download)


def _cmd_search(args) -> int:
    client = NexusClient()
    results = client.search(args.game, args.query)
    print(f"{'Mod ID':<10} | Mod Name / Summary")
    for mod in results:
        print(f"{mod['id']:<10} | {mod['name']} -- {mod.get('summary', '')}")
    return 0


def _cmd_list(args) -> int:
    client = NexusClient()
    game_domain, mod_id = parse_mod_url(args.mod_url)
    files = client.list_files(game_domain, mod_id)
    print("Available Files:")
    for f in files:
        print(
            f"[{f['file_id']}] {f['name']} (v{f.get('version', '?')}) -- "
            f"{f.get('category_name', '')}, {f.get('size_kb', '?')} KB"
        )
    return 0


def _cmd_download(args) -> int:
    client = NexusClient()
    game_domain, mod_id = parse_mod_url(args.mod_url)
    file_id = args.file_id
    if not file_id:
        files = client.list_files(game_domain, mod_id)
        print("Available Files:")
        for f in files:
            print(f"[{f['file_id']}] {f['name']} ({f.get('category_name', '')})")
        file_id = input("Enter the file_id to download: ").strip()
        if not file_id:
            print("Action aborted.")
            return 0
    url = client.get_download_url(game_domain, mod_id, file_id)
    dest = client.download(url, args.dest_dir)
    print(f"Downloaded to {dest}")
    return 0
