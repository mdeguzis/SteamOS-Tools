"""AppImage/archive package manager for GitHub releases.

Port of utilities/app-image-manager.sh. All apps live at a constant
~/Applications/<name>.AppImage path so non-Steam game shortcuts never need
updating after an upgrade.
"""

from __future__ import annotations

import logging
import platform as _platform
import re
import shutil
import tarfile
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

from steamostools.github_releases import GitHubReleaseClient
from steamostools.process import run
from steamostools.vdf import shortcuts as steam_shortcuts

logger = logging.getLogger("steamostools.app_image_manager")

APPS_DIR = Path.home() / "Applications"
BACKUP_DIR = APPS_DIR / "backup"
LIB_DIR = Path.home() / ".local" / "share" / "app-image-manager"
CONFIG_DIR = Path.home() / ".config" / "app-image-manager"
DESKTOP_DIR = Path.home() / ".local" / "share" / "applications"
ICON_DIR = Path.home() / ".local" / "share" / "icons" / "hicolor"

ARCH_PATTERNS = {
    "x86_64": ["x86_64", "linux-x64", "linux_x64", "amd64", "x64"],
    "aarch64": ["aarch64", "linux-arm64", "linux_arm64", "arm64"],
    "armv7l": ["armv7l", "arm"],
}
ASSET_EXTENSIONS = [(r"\.AppImage$", "appimage"), (r"\.tar\.gz$", "targz"), (r"\.zip$", "zip")]
NON_BINARY_EXTENSIONS = (".so", ".json", ".xml", ".txt", ".md")


class AppNotFoundError(LookupError):
    pass


class AlreadyInstalledError(RuntimeError):
    pass


class NotInstalledError(RuntimeError):
    pass


class NoSupportedAssetError(RuntimeError):
    pass


class NoExecutableFoundError(RuntimeError):
    pass


def run_optional(cmd: list[str]) -> None:
    """Run a best-effort desktop-integration command (icon cache refresh,
    desktop database update) that may not be installed on a minimal
    system -- mirrors the original script's `|| true` on these calls.
    Unlike steamostools.process.run(check=False), which only tolerates a
    non-zero exit, this also tolerates the binary being entirely absent."""
    if shutil.which(cmd[0]) is None:
        logger.debug("%s not available, skipping", cmd[0])
        return
    run(cmd, check=False)


def arch_patterns(machine: str | None = None) -> list[str]:
    machine = machine or _platform.machine()
    return ARCH_PATTERNS.get(machine, [machine])


def parse_repo_input(text: str) -> str:
    text = text.removeprefix("https://github.com/").removeprefix("http://github.com/")
    return text.removesuffix(".git")


def derive_name(repo: str) -> str:
    return repo.rsplit("/", 1)[-1].lower()


def select_asset(assets: list[dict], *, machine: str | None = None) -> tuple[str, str] | None:
    """Pick the best release asset: prefer AppImage > tar.gz > zip, and
    within each, an arch-specific match over a generic one. Returns
    (url, type), or None if nothing matched (a legitimate "no supported
    asset" outcome the caller decides how to handle)."""
    patterns = arch_patterns(machine)
    named = [(a["name"], a["browser_download_url"]) for a in assets]

    for ext_pattern, ext_type in ASSET_EXTENSIONS:
        ext_re = re.compile(ext_pattern, re.IGNORECASE)
        for arch in patterns:
            arch_re = re.compile(re.escape(arch), re.IGNORECASE)
            for name, url in named:
                if arch_re.search(name) and ext_re.search(name):
                    return url, ext_type
        for name, url in named:
            if ext_re.search(name):
                return url, ext_type
    return None


# ---------------------------------------------------------------------------
# App registry (apps.conf: flat name=repo mapping)
# ---------------------------------------------------------------------------


@dataclass
class AppRegistry:
    conf_path: Path = CONFIG_DIR / "apps.conf"

    def _read_entries(self) -> dict[str, str]:
        if not self.conf_path.exists():
            return {}
        entries = {}
        for line in self.conf_path.read_text().splitlines():
            if "=" in line:
                name, _, repo = line.partition("=")
                entries[name] = repo
        return entries

    def _write_entries(self, entries: dict[str, str]) -> None:
        self.conf_path.parent.mkdir(parents=True, exist_ok=True)
        self.conf_path.write_text("".join(f"{n}={r}\n" for n, r in sorted(entries.items())))

    def register(self, name: str, repo: str) -> None:
        entries = self._read_entries()
        if name in entries:
            return
        entries[name] = repo
        self._write_entries(entries)

    def unregister(self, name: str) -> None:
        entries = self._read_entries()
        entries.pop(name, None)
        self._write_entries(entries)

    def get_repo(self, name: str) -> str | None:
        return self._read_entries().get(name)

    def all_entries(self) -> dict[str, str]:
        return self._read_entries()

    def resolve(self, input_str: str) -> tuple[str, str]:
        """Resolve a bare name, org/repo, or GitHub URL into (name, repo).
        Raises AppNotFoundError if a bare name isn't in the registry."""
        if "/" in input_str or "github.com" in input_str:
            repo = parse_repo_input(input_str)
            return derive_name(repo), repo
        repo = self.get_repo(input_str)
        if repo is None:
            raise AppNotFoundError(f"'{input_str}' not found in registry. Install it first.")
        return input_str, repo


# ---------------------------------------------------------------------------
# Per-app metadata (.version / .type files)
# ---------------------------------------------------------------------------


@dataclass
class AppMetadata:
    config_dir: Path = CONFIG_DIR
    apps_dir: Path = APPS_DIR
    lib_dir: Path = LIB_DIR
    desktop_dir: Path = DESKTOP_DIR
    icon_dir: Path = ICON_DIR

    def get_version(self, name: str) -> str | None:
        f = self.config_dir / f"{name}.version"
        return f.read_text().strip() if f.exists() else None

    def set_version(self, name: str, version: str) -> None:
        self.config_dir.mkdir(parents=True, exist_ok=True)
        (self.config_dir / f"{name}.version").write_text(version)

    def get_install_type(self, name: str) -> str:
        f = self.config_dir / f"{name}.type"
        if f.exists():
            return f.read_text().strip()
        if (self.lib_dir / name).is_dir():
            return "archive"
        if (self.apps_dir / f"{name}.AppImage").exists():
            return "appimage"
        return "unknown"

    def set_install_type(self, name: str, install_type: str) -> None:
        self.config_dir.mkdir(parents=True, exist_ok=True)
        (self.config_dir / f"{name}.type").write_text(install_type)

    def clear(self, name: str) -> None:
        (self.config_dir / f"{name}.version").unlink(missing_ok=True)
        (self.config_dir / f"{name}.type").unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# Desktop integration
# ---------------------------------------------------------------------------


def generate_minimal_desktop_entry(name: str, launcher_path: Path) -> str:
    display_name = name.replace("-", " ").title()
    return (
        "[Desktop Entry]\nType=Application\n"
        f"Name={display_name}\nExec={launcher_path}\nIcon={name}\n"
        "Categories=Utility;\nTerminal=false\n"
    )


def find_desktop_source(search_dir: Path) -> Path | None:
    matches = sorted(p for p in search_dir.glob("**/*.desktop") if len(p.relative_to(search_dir).parts) <= 4)
    return matches[0] if matches else None


def find_icon_source(search_dir: Path, icon_name: str | None) -> Path | None:
    if icon_name:
        for ext in ("png", "svg"):
            matches = list(search_dir.glob(f"**/{icon_name}.{ext}"))
            if matches:
                return matches[0]
    for ext in ("png", "svg"):
        matches = list(search_dir.glob(f"**/*.{ext}"))
        if matches:
            return matches[0]
    return None


def install_desktop_entry(
    name: str,
    launcher_path: Path,
    search_dir: Path | None = None,
    *,
    desktop_dir: Path = DESKTOP_DIR,
    icon_dir: Path = ICON_DIR,
) -> Path | None:
    """Install a .desktop entry (and icon, if found) for an app. If
    search_dir isn't given, extracts the AppImage to a temp dir first.
    Returns the installed .desktop path, or None if extraction failed
    (a soft failure -- the app is still usable without a launcher menu
    entry, matching the original script's behavior)."""
    cleanup_dir: Path | None = None
    if search_dir is None:
        tmp_dir = Path(tempfile.mkdtemp())
        try:
            result = run([str(launcher_path), "--appimage-extract"], cwd=str(tmp_dir), check=False)
            extraction_failed = result.returncode != 0
        except OSError:
            # Not a real AppImage (e.g. exec format error) -- same soft
            # failure as a non-zero exit, not a crash.
            extraction_failed = True
        if extraction_failed:
            logger.warning("AppImage extraction failed; skipping desktop integration.")
            shutil.rmtree(tmp_dir, ignore_errors=True)
            return None
        search_dir = tmp_dir / "squashfs-root"
        cleanup_dir = tmp_dir

    try:
        desktop_src = find_desktop_source(search_dir)
        if desktop_src is not None:
            content = desktop_src.read_text(errors="replace")
        else:
            logger.warning("No .desktop file found; generating minimal entry.")
            content = generate_minimal_desktop_entry(name, launcher_path)

        icon_match = re.search(r"^Icon=(.*)$", content, re.MULTILINE)
        icon_name = icon_match.group(1).strip() if icon_match else None
        icon_src = find_icon_source(search_dir, icon_name)
        if icon_src is not None:
            ext = icon_src.suffix.lstrip(".")
            icon_dest_dir = icon_dir / "256x256" / "apps"
            icon_dest_dir.mkdir(parents=True, exist_ok=True)
            shutil.copy(icon_src, icon_dest_dir / f"{name}.{ext}")
            run_optional(["gtk-update-icon-cache", "-f", "-t", str(icon_dir)])
            logger.info("Icon installed: %s/%s.%s", icon_dest_dir, name, ext)

        content = re.sub(r"^Exec=.*$", f"Exec={launcher_path}", content, flags=re.MULTILINE)
        content = re.sub(r"^Icon=.*$", f"Icon={name}", content, flags=re.MULTILINE)

        desktop_dir.mkdir(parents=True, exist_ok=True)
        desktop_dest = desktop_dir / f"{name}.desktop"
        desktop_dest.write_text(content)
        desktop_dest.chmod(desktop_dest.stat().st_mode | 0o111)
        run_optional(["update-desktop-database", str(desktop_dir)])
        logger.info("Desktop entry installed: %s", desktop_dest)
        return desktop_dest
    finally:
        if cleanup_dir is not None:
            shutil.rmtree(cleanup_dir, ignore_errors=True)


def remove_desktop_entry(name: str, *, desktop_dir: Path = DESKTOP_DIR, icon_dir: Path = ICON_DIR) -> None:
    (desktop_dir / f"{name}.desktop").unlink(missing_ok=True)
    for icon in icon_dir.glob(f"**/{name}.*"):
        icon.unlink(missing_ok=True)
    run_optional(["update-desktop-database", str(desktop_dir)])


# ---------------------------------------------------------------------------
# Steam shortcut integration (thin wrapper over steamostools.vdf.shortcuts)
# ---------------------------------------------------------------------------


def is_gaming_mode() -> bool:
    if run(["systemctl", "--user", "is-active", "gamescope-session.service"], check=False).returncode == 0:
        return True
    if (
        run(["systemctl", "--user", "is-active", "gamescope-session-plus@steamos.service"], check=False).returncode
        == 0
    ):
        return True
    return False


def steam_add_shortcut(name: str, launcher: Path, icon: str = "", *, icon_dir: Path = ICON_DIR) -> int:
    """Add a Steam shortcut for `name` across every shortcuts.vdf found.
    Returns the number of shortcuts.vdf files updated (0 means Steam
    isn't installed/has never been launched, a warning-worthy but
    non-fatal outcome)."""
    display_name = name.replace("-", " ").title()
    start_dir = str(launcher.parent)

    if not icon:
        matches = list(icon_dir.glob(f"**/{name}.*"))
        icon = str(matches[0]) if matches else ""

    vdf_files = steam_shortcuts.find_shortcuts_vdf_files()
    if not vdf_files:
        logger.warning("No shortcuts.vdf found -- Steam may not be installed or never launched.")
        return 0

    for vdf in vdf_files:
        logger.info("Adding Steam shortcut in: %s", vdf)
        steam_shortcuts.add_shortcut(vdf, display_name, str(launcher), start_dir, icon)

    if is_gaming_mode():
        logger.warning(
            "You are in Gaming Mode. Switch to Desktop Mode, restart Steam, "
            "then switch back for the shortcut to appear in your library."
        )
    else:
        logger.warning("Restart Steam for the shortcut to appear in your library.")
    return len(vdf_files)


def steam_remove_shortcut(name: str) -> None:
    display_name = name.replace("-", " ").title()
    vdf_files = steam_shortcuts.find_shortcuts_vdf_files()
    for vdf in vdf_files:
        try:
            steam_shortcuts.remove_shortcut(vdf, display_name)
            logger.info("Removed Steam shortcut from: %s", vdf)
        except steam_shortcuts.ShortcutNotFoundError:
            logger.debug("'%s' not found in %s, skipping", display_name, vdf)


# ---------------------------------------------------------------------------
# Install helpers
# ---------------------------------------------------------------------------


def install_appimage(
    name: str,
    url: str,
    tag: str,
    *,
    client: GitHubReleaseClient,
    apps_dir: Path = APPS_DIR,
    desktop_dir: Path = DESKTOP_DIR,
    icon_dir: Path = ICON_DIR,
    metadata: AppMetadata,
) -> Path:
    apps_dir.mkdir(parents=True, exist_ok=True)
    appimage_path = apps_dir / f"{name}.AppImage"

    fd, tmp_name = tempfile.mkstemp(dir=apps_dir, prefix=f".{name}-", suffix=".AppImage")
    import os

    os.close(fd)
    tmp_path = Path(tmp_name)

    client.download(url, tmp_path, progress=False)
    tmp_path.chmod(tmp_path.stat().st_mode | 0o111)
    tmp_path.replace(appimage_path)

    metadata.set_version(name, tag)
    metadata.set_install_type(name, "appimage")
    logger.info("%s %s -> %s", name, tag, appimage_path)

    install_desktop_entry(name, appimage_path, desktop_dir=desktop_dir, icon_dir=icon_dir)
    return appimage_path


def find_main_binary(extract_dir: Path, name: str) -> Path | None:
    """Locate the main executable in an extracted archive: name match
    first, then an already-executable file, then the largest plausible
    candidate file (the binary is usually the biggest file)."""
    search_pat = re.sub(r"[^a-z0-9]", "", name.lower())

    def candidates() -> list[Path]:
        return [
            p
            for p in extract_dir.iterdir()
            if p.is_file() and p.suffix not in NON_BINARY_EXTENSIONS and not p.name.endswith(".so")
        ] + [
            p
            for sub in extract_dir.iterdir()
            if sub.is_dir()
            for p in sub.iterdir()
            if p.is_file() and p.suffix not in NON_BINARY_EXTENSIONS and not p.name.endswith(".so")
        ]

    all_candidates = candidates()

    name_matches = [p for p in all_candidates if search_pat in p.name.lower()]
    if name_matches:
        return name_matches[0]

    executable_matches = [p for p in all_candidates if p.stat().st_mode & 0o111]
    if executable_matches:
        return executable_matches[0]

    if all_candidates:
        return max(all_candidates, key=lambda p: p.stat().st_size)

    return None


def install_archive(
    name: str,
    url: str,
    tag: str,
    archive_type: str,
    *,
    client: GitHubReleaseClient,
    apps_dir: Path = APPS_DIR,
    lib_dir: Path = LIB_DIR,
    desktop_dir: Path = DESKTOP_DIR,
    icon_dir: Path = ICON_DIR,
    metadata: AppMetadata,
) -> Path:
    extract_dir = lib_dir / name
    launcher = apps_dir / f"{name}.AppImage"

    fd, tmp_name = tempfile.mkstemp()
    import os

    os.close(fd)
    tmp_path = Path(tmp_name)
    client.download(url, tmp_path, progress=False)

    shutil.rmtree(extract_dir, ignore_errors=True)
    extract_dir.mkdir(parents=True)

    if archive_type == "targz":
        with tarfile.open(tmp_path) as tar:
            tar.extractall(extract_dir, filter="data")
    else:
        with zipfile.ZipFile(tmp_path) as zf:
            zf.extractall(extract_dir)
    tmp_path.unlink()

    main_bin = find_main_binary(extract_dir, name)
    if main_bin is None:
        raise NoExecutableFoundError(f"Could not find executable in archive extracted to {extract_dir}")
    main_bin.chmod(main_bin.stat().st_mode | 0o111)
    logger.info("Main binary: %s", main_bin)

    apps_dir.mkdir(parents=True, exist_ok=True)
    launcher.write_text(
        "#!/usr/bin/env bash\n"
        "# Auto-generated by app-image-manager -- do not edit manually\n"
        f'APP_DIR="{main_bin.parent}"\n'
        'export LD_LIBRARY_PATH="${APP_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"\n'
        'cd "${APP_DIR}"\n'
        f'exec "${{APP_DIR}}/{main_bin.name}" "$@"\n'
    )
    launcher.chmod(launcher.stat().st_mode | 0o111)

    metadata.set_version(name, tag)
    metadata.set_install_type(name, f"archive-{archive_type}")
    logger.info("%s %s -> %s (wraps %s)", name, tag, launcher, main_bin)

    install_desktop_entry(name, launcher, extract_dir, desktop_dir=desktop_dir, icon_dir=icon_dir)
    return launcher


def backup_existing(name: str, *, apps_dir: Path = APPS_DIR, lib_dir: Path = LIB_DIR, backup_dir: Path = BACKUP_DIR) -> None:
    launcher = apps_dir / f"{name}.AppImage"
    extract_dir = lib_dir / name

    if launcher.is_file():
        backup_dir.mkdir(parents=True, exist_ok=True)
        shutil.copy(launcher, backup_dir / f"{name}.AppImage")
    if extract_dir.is_dir():
        shutil.rmtree(backup_dir / name, ignore_errors=True)
        shutil.copytree(extract_dir, backup_dir / name)


def fetch_and_install(
    name: str,
    repo: str,
    *,
    client: GitHubReleaseClient,
    metadata: AppMetadata,
    release: dict | None = None,
) -> Path:
    release = release or client.latest_release(repo)
    tag = release.get("tag_name")
    if not tag:
        raise NoSupportedAssetError(f"Could not determine latest tag for {repo}")

    picked = select_asset(release.get("assets", []))
    if picked is None:
        raise NoSupportedAssetError(
            f"No supported asset found in {repo} release {tag}. Looked for: .AppImage, .tar.gz, .zip"
        )
    url, asset_type = picked
    logger.info("Asset: %s -- %s", asset_type, url)

    if asset_type == "appimage":
        return install_appimage(
            name, url, tag, client=client,
            apps_dir=metadata.apps_dir, desktop_dir=metadata.desktop_dir, icon_dir=metadata.icon_dir,
            metadata=metadata,
        )
    return install_archive(
        name, url, tag, asset_type,
        client=client, apps_dir=metadata.apps_dir, lib_dir=metadata.lib_dir,
        desktop_dir=metadata.desktop_dir, icon_dir=metadata.icon_dir, metadata=metadata,
    )


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_install(input_str: str, *, add_steam: bool = False, registry: AppRegistry | None = None) -> Path:
    registry = registry or AppRegistry()
    metadata = AppMetadata()
    client = GitHubReleaseClient()

    repo = parse_repo_input(input_str)
    name = derive_name(repo)

    launcher = APPS_DIR / f"{name}.AppImage"
    if launcher.exists():
        raise AlreadyInstalledError(
            f"{name} is already installed ({metadata.get_version(name)}). Use reinstall or update."
        )

    logger.info("Installing %s from %s...", name, repo)
    result = fetch_and_install(name, repo, client=client, metadata=metadata)
    registry.register(name, repo)

    if add_steam:
        steam_add_shortcut(name, launcher)
    return result


def cmd_update_one(input_str: str, *, registry: AppRegistry | None = None) -> str:
    registry = registry or AppRegistry()
    metadata = AppMetadata()
    client = GitHubReleaseClient()

    name, repo = registry.resolve(input_str)
    launcher = APPS_DIR / f"{name}.AppImage"
    if not launcher.exists():
        raise NotInstalledError(f"{name} is not installed. Use install first.")

    release = client.latest_release(repo)
    latest_tag = release.get("tag_name")
    installed = metadata.get_version(name)

    if latest_tag == installed:
        return "up_to_date"

    backup_existing(name)
    fetch_and_install(name, repo, client=client, metadata=metadata, release=release)
    return "updated"


@dataclass
class PendingUpdate:
    name: str
    repo: str
    installed: str | None
    latest_tag: str
    release: dict


def check_all_updates(
    *, registry: AppRegistry | None = None, metadata: AppMetadata | None = None, client: GitHubReleaseClient | None = None
) -> list[PendingUpdate]:
    """Check every registered app against its latest GitHub release.
    Returns only the ones with an update available -- apps already up to
    date are not an error, just excluded from the result."""
    registry = registry or AppRegistry()
    metadata = metadata or AppMetadata()
    client = client or GitHubReleaseClient()

    pending = []
    for name, repo in sorted(registry.all_entries().items()):
        release = client.latest_release(repo)
        latest_tag = release.get("tag_name")
        installed = metadata.get_version(name)
        if latest_tag != installed:
            pending.append(PendingUpdate(name, repo, installed, latest_tag, release))
    return pending


def apply_updates(
    pending: list[PendingUpdate],
    *,
    metadata: AppMetadata | None = None,
    client: GitHubReleaseClient | None = None,
) -> None:
    metadata = metadata or AppMetadata()
    client = client or GitHubReleaseClient()
    for update in pending:
        logger.info("Upgrading %s: %s -> %s", update.name, update.installed or "none", update.latest_tag)
        backup_existing(update.name)
        fetch_and_install(update.name, update.repo, client=client, metadata=metadata, release=update.release)


def cmd_update_all(
    *,
    yes: bool = False,
    registry: AppRegistry | None = None,
    metadata: AppMetadata | None = None,
    client: GitHubReleaseClient | None = None,
) -> list[PendingUpdate]:
    """Check every registered app and apply updates. Without `yes`, only
    checks and returns the pending list without applying -- the CLI
    handler prompts for confirmation before calling apply_updates()."""
    registry = registry or AppRegistry()
    metadata = metadata or AppMetadata()
    client = client or GitHubReleaseClient()

    pending = check_all_updates(registry=registry, metadata=metadata, client=client)
    if pending and yes:
        apply_updates(pending, metadata=metadata, client=client)
    return pending


def cmd_reinstall(input_str: str, *, registry: AppRegistry | None = None) -> Path:
    registry = registry or AppRegistry()
    metadata = AppMetadata()
    client = GitHubReleaseClient()

    name, repo = registry.resolve(input_str)
    backup_existing(name)
    (APPS_DIR / f"{name}.AppImage").unlink(missing_ok=True)
    shutil.rmtree(LIB_DIR / name, ignore_errors=True)
    return fetch_and_install(name, repo, client=client, metadata=metadata)


def cmd_uninstall(input_str: str, *, registry: AppRegistry | None = None) -> None:
    registry = registry or AppRegistry()
    metadata = AppMetadata()
    name, _repo = registry.resolve(input_str)

    (APPS_DIR / f"{name}.AppImage").unlink(missing_ok=True)
    shutil.rmtree(LIB_DIR / name, ignore_errors=True)
    shutil.rmtree(BACKUP_DIR / name, ignore_errors=True)
    (BACKUP_DIR / f"{name}.AppImage").unlink(missing_ok=True)
    metadata.clear(name)
    registry.unregister(name)
    remove_desktop_entry(name)
    steam_remove_shortcut(name)


# ---------------------------------------------------------------------------
# CLI wiring
# ---------------------------------------------------------------------------


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser(
        "appimage", help="AppImage/archive package manager for GitHub releases"
    )
    sub = parser.add_subparsers(dest="appimage_command", required=True)

    install = sub.add_parser("install", help="install an app from a GitHub repo")
    install.add_argument("repo", help="org/repo or https://github.com/org/repo")
    install.add_argument("--steam", action="store_true", help="also add a Steam shortcut")
    install.set_defaults(func=_cmd_install)

    update = sub.add_parser("update", help="check/apply updates (all apps if no name given)")
    update.add_argument("name", nargs="?", default=None, help="app name or org/repo; omit for all")
    update.add_argument("--yes", "-y", action="store_true", help="apply updates without confirming")
    update.set_defaults(func=_cmd_update)

    reinstall = sub.add_parser("reinstall", help="force reinstall the latest version")
    reinstall.add_argument("name")
    reinstall.set_defaults(func=_cmd_reinstall)

    uninstall = sub.add_parser("uninstall", help="remove an app, launcher, desktop entry, icon")
    uninstall.add_argument("name")
    uninstall.set_defaults(func=_cmd_uninstall)

    sub.add_parser("list", help="list all installed apps").set_defaults(func=_cmd_list)

    steam_add = sub.add_parser("steam-add", help="add an already-installed app to Steam")
    steam_add.add_argument("name")
    steam_add.set_defaults(func=_cmd_steam_add)


def _cmd_install(args) -> int:
    try:
        cmd_install(args.repo, add_steam=args.steam)
    except AlreadyInstalledError as exc:
        logger.warning(str(exc))
    return 0


def _cmd_update(args) -> int:
    if args.name:
        status = cmd_update_one(args.name)
        logger.info("%s: %s", args.name, status)
        return 0

    pending = check_all_updates()
    if not pending:
        logger.info("All apps are up to date.")
        return 0

    for update in pending:
        logger.info("%s: %s -> %s", update.name, update.installed or "(none)", update.latest_tag)

    if not args.yes:
        answer = input(f"\n{len(pending)} update(s) available. Apply? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            logger.info("Aborted.")
            return 0

    apply_updates(pending)
    logger.info("Done.")
    return 0


def _cmd_reinstall(args) -> int:
    cmd_reinstall(args.name)
    return 0


def _cmd_uninstall(args) -> int:
    cmd_uninstall(args.name)
    return 0


def _cmd_list(args) -> int:
    registry = AppRegistry()
    metadata = AppMetadata()
    entries = registry.all_entries()
    if not entries:
        print("(no apps installed)")
        return 0
    for name in sorted(entries):
        version = metadata.get_version(name) or "(not installed)"
        install_type = metadata.get_install_type(name)
        print(f"{name}\t{version}\t{install_type}")
    return 0


def _cmd_steam_add(args) -> int:
    registry = AppRegistry()
    name, _repo = registry.resolve(args.name)
    steam_add_shortcut(name, APPS_DIR / f"{name}.AppImage")
    return 0
