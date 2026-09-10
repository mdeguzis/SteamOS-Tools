"""Shared "get the latest GitHub release asset for this arch" client.

Generalizes the get-latest-tag / pick-matching-asset / download pattern that
was duplicated (in bash) across get-proton-ge.sh, app-image-manager.sh, and
install-vortex-steamos.sh.
"""

from __future__ import annotations

import logging
import re
from pathlib import Path

import requests

logger = logging.getLogger("steamostools.github_releases")

GITHUB_API = "https://api.github.com"
DOWNLOAD_CHUNK_BYTES = 1024 * 64


class NoMatchingAssetError(RuntimeError):
    """Raised when no release asset matches any of the given patterns."""


class GitHubReleaseClient:
    def __init__(self, session: requests.Session | None = None):
        self.session = session or requests.Session()

    def latest_release(self, repo: str) -> dict:
        """Fetch the latest release metadata for `owner/repo`.

        Raises requests.HTTPError on a non-2xx response -- a 404/rate-limit
        is a real failure, not "no release," so it is never swallowed into
        an empty dict.
        """
        url = f"{GITHUB_API}/repos/{repo}/releases/latest"
        logger.debug("Fetching latest release: %s", url)
        response = self.session.get(url, timeout=30)
        response.raise_for_status()
        data = response.json()
        logger.debug("Latest release for %s: %s", repo, data.get("tag_name"))
        return data

    def list_releases(self, repo: str) -> list[dict]:
        """Fetch all releases for `owner/repo` (newest first), including
        prereleases -- unlike `latest_release`, which GitHub's API excludes
        prereleases from. Raises requests.HTTPError on a non-2xx response.
        """
        url = f"{GITHUB_API}/repos/{repo}/releases"
        logger.debug("Fetching all releases: %s", url)
        response = self.session.get(url, timeout=30)
        response.raise_for_status()
        return response.json()

    def pick_asset(self, assets: list[dict], patterns: list[str]) -> dict:
        """Return the first asset whose name matches any of `patterns`
        (regexes), in pattern order. Raises NoMatchingAssetError if none
        match, rather than returning None."""
        for pattern in patterns:
            regex = re.compile(pattern)
            for asset in assets:
                if regex.search(asset["name"]):
                    logger.debug("Matched asset %s via pattern %s", asset["name"], pattern)
                    return asset
        available = ", ".join(a["name"] for a in assets)
        raise NoMatchingAssetError(
            f"No asset matched any of {patterns!r}. Available: {available}"
        )

    def download(self, url: str, dest: Path, *, progress: bool = True) -> Path:
        """Stream-download `url` to `dest`. Raises on any HTTP failure."""
        dest.parent.mkdir(parents=True, exist_ok=True)
        logger.debug("Downloading %s -> %s", url, dest)
        response = self.session.get(url, stream=True, timeout=30)
        response.raise_for_status()
        total = int(response.headers.get("content-length", 0))

        progress_bar = None
        if progress:
            from tqdm import tqdm

            progress_bar = tqdm(total=total or None, unit="B", unit_scale=True, desc=dest.name)

        try:
            with dest.open("wb") as f:
                for chunk in response.iter_content(chunk_size=DOWNLOAD_CHUNK_BYTES):
                    f.write(chunk)
                    if progress_bar is not None:
                        progress_bar.update(len(chunk))
        finally:
            if progress_bar is not None:
                progress_bar.close()

        logger.info("Downloaded %s (%d bytes)", dest, dest.stat().st_size)
        return dest
