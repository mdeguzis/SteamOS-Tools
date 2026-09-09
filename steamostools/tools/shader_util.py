"""Inspect and clean up Steam's per-title Vulkan (Fossilize) shader caches.

Refactored from the original standalone utilities/vulkan-shader-util.py:
same CLI shape and safety pattern (preview-before-delete, "is a game
running" guard checked both before and after confirmation), now backed by
steamostools.vdf.textvdf instead of a private module-level parser, and with
a real test suite.

Steam keeps a separate crowd-sourced shader cache bucket
(steamapprun_pipeline_cache.<hash>) per Steam Play compatibility tool a
game has ever been launched with, and keeps re-syncing all of them from
Valve's SteamSwarm servers forever -- even for tools a game is no longer
configured to use. That, plus "moving target" tools like Proton
Experimental whose bucket hash itself changes over time as Valve's
crowd data grows, is why some titles seem to reprocess shaders on
almost every launch.
"""

from __future__ import annotations

import datetime
import re
import shutil
import subprocess
import textwrap
from pathlib import Path

from steamostools.vdf.textvdf import read_braced_section

WRAP_COL_WIDTH = 42
EVENTS_WRAP_COL_WIDTH = 90
DEFAULT_MAX_BUCKET_AGE_DAYS = 7

DEFAULT_STEAM_ROOT = Path.home() / ".local/share/Steam"
BUCKET_DIR_RE = re.compile(r"^steamapprun_pipeline_cache\.([0-9a-f]+)$")
FOUND_BUCKETS_RE = re.compile(
    r"^\[([\d\- :]+)\] Found \d+ buckets for AppId (\d+) CompatTool: (\S+):$"
)
BUCKET_HASH_RE = re.compile(r"VulkanPipelinesV6(?:_([0-9a-f]+))?$")
GOT_BUCKET_RE = re.compile(
    r"Got saved compat bucket for (\S+): SteamSwarm / G7:VulkanPipelinesV6_([0-9a-f]+)"
)
REPLAY_START_RE = re.compile(
    r"^\[([\d\- :]+)\] Starting replay of FOZ databases for AppID (\d+) "
)
COMMIT_HASHED_RE = re.compile(
    r"^\[([\d\- :]+)\] Committed bucket \d+ \(AppID (\d+)\) contains file "
    r"'fozpipelinesv6\\steamapprun_pipeline_cache\.([0-9a-f]+)\\steam_pipeline_cache\.foz'"
)
COMMIT_DEFAULT_RE = re.compile(
    r"^\[([\d\- :]+)\] Committed bucket \d+ \(AppID (\d+)\) contains file "
    r"'fozpipelinesv6\\steam_pipeline_cache\.foz'"
)
API_LANE_RE = re.compile(
    r"shader_cache_temp_dir_([^/]+)/fozpipelinesv6/steamapprun_pipeline_cache\.([0-9a-f]+)"
)


def get_compat_tool_names(steam_root: Path) -> dict[str, str]:
    """Map appid -> configured compat tool name ('' = Steam default)."""
    config_path = steam_root / "config" / "config.vdf"
    text = config_path.read_text(errors="replace")
    body = read_braced_section(text, "CompatToolMapping")
    if body is None:
        return {}
    names = {}
    for entry_m in re.finditer(r'"(\d+)"\s*\n\s*{', body):
        appid = entry_m.group(1)
        depth = 1
        j = entry_m.end()
        start = j
        while depth and j < len(body):
            if body[j] == "{":
                depth += 1
            elif body[j] == "}":
                depth -= 1
            j += 1
        entry_body = body[start : j - 1]
        name_m = re.search(r'"name"\s*\n?\s*"([^"]*)"', entry_body)
        names[appid] = name_m.group(1) if name_m else ""
    return names


def get_library_paths(steam_root: Path) -> list[Path]:
    lf = steam_root / "steamapps" / "libraryfolders.vdf"
    if not lf.exists():
        return [steam_root]
    text = lf.read_text(errors="replace")
    paths = [Path(p) for p in re.findall(r'"path"\s*\n?\s*"([^"]+)"', text)]
    return paths or [steam_root]


def get_installed_appids(library_paths: list[Path]) -> tuple[dict[str, Path], dict[str, str]]:
    appids, names = {}, {}
    for lib in library_paths:
        steamapps = lib / "steamapps"
        if not steamapps.is_dir():
            continue
        for manifest in steamapps.glob("appmanifest_*.acf"):
            appid = manifest.stem.replace("appmanifest_", "")
            appids[appid] = lib
            name_m = re.search(r'"name"\s*\n?\s*"([^"]*)"', manifest.read_text(errors="replace"))
            names[appid] = name_m.group(1) if name_m else "(unknown title)"
    return appids, names


def get_hash_to_tools(steam_root: Path) -> dict[str, list[str]]:
    """Map bucket hash -> sorted list of compat tool names Steam has
    ever associated it with. Gives a human-readable Proton version for
    each opaque hash, including hashes reused across tools over time."""
    logs_dir = steam_root / "logs"
    mapping: dict[str, set[str]] = {}
    for log_name in ("shader_log.previous.txt", "shader_log.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            m = GOT_BUCKET_RE.search(line)
            if m:
                mapping.setdefault(m.group(2), set()).add(m.group(1))
    return {h: sorted(tools) for h, tools in mapping.items()}


def find_active_buckets(
    steam_root: Path, appid: str, expected_name: str
) -> tuple[set[str] | None, str | None]:
    """Return (hashes, timestamp) for the bucket set Steam last reported
    as active for this appid under its currently configured compat
    tool, or (None, None) if no matching record is found."""
    if not expected_name:
        return None, None
    logs_dir = steam_root / "logs"
    best_hashes, best_ts = None, ""
    for log_name in ("shader_log.txt", "shader_log.previous.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        lines = p.read_text(errors="replace").splitlines()
        for idx, line in enumerate(lines):
            m = FOUND_BUCKETS_RE.match(line)
            if not m or m.group(2) != appid or m.group(3) != expected_name:
                continue
            ts = m.group(1)
            hashes = set()
            j = idx + 1
            while j < len(lines):
                hm = BUCKET_HASH_RE.search(lines[j])
                if not hm:
                    break
                if hm.group(1):
                    hashes.add(hm.group(1))
                j += 1
            if ts > best_ts:
                best_ts, best_hashes = ts, hashes
    return best_hashes, (best_ts or None)


def resolve_bucket_state(
    steam_root: Path, appid: str, tool_name: str, max_age_days: float
) -> tuple[str, set[str] | None, float | None]:
    """Classify how much we can trust the active-bucket evidence for a
    title: 'none' (no record for the current tool), 'stale_evidence'
    (record found but older than max_age_days -- risky for "moving
    target" tools like Proton Experimental/GE-Proton whose bucket hash
    can shift over time), or 'ok'. Returns (state, hashes, age_days)."""
    hashes, ts = find_active_buckets(steam_root, appid, tool_name)
    if hashes is None:
        return "none", None, None
    age_days = None
    try:
        ts_dt = datetime.datetime.strptime(ts, "%Y-%m-%d %H:%M:%S")
        age_days = (datetime.datetime.now() - ts_dt).total_seconds() / 86400
    except ValueError:
        pass
    if age_days is not None and age_days > max_age_days:
        return "stale_evidence", hashes, age_days
    return "ok", hashes, age_days


def get_present_buckets(lib: Path, appid: str) -> dict[str, Path]:
    shadercache = lib / "steamapps" / "shadercache" / appid / "fozpipelinesv6"
    present = {}
    if shadercache.is_dir():
        for entry in shadercache.iterdir():
            if entry.is_dir():
                m = BUCKET_DIR_RE.match(entry.name)
                if m:
                    present[m.group(1)] = entry
    return present


def churn_stats(steam_root: Path, appid: str) -> dict:
    """Count shader-replay and per-bucket commit events for an appid,
    to show which titles/buckets are actually noisy and why."""
    logs_dir = steam_root / "logs"
    replay_ts = []
    per_bucket_commits: dict[str, int] = {}
    default_commits = 0
    for log_name in ("shader_log.previous.txt", "shader_log.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            m = REPLAY_START_RE.match(line)
            if m and m.group(2) == appid:
                replay_ts.append(m.group(1))
                continue
            m = COMMIT_HASHED_RE.match(line)
            if m and m.group(2) == appid:
                per_bucket_commits[m.group(3)] = per_bucket_commits.get(m.group(3), 0) + 1
                continue
            m = COMMIT_DEFAULT_RE.match(line)
            if m and m.group(2) == appid:
                default_commits += 1
    replay_ts.sort()
    return {
        "replay_count": len(replay_ts),
        "first_replay": replay_ts[0] if replay_ts else None,
        "last_replay": replay_ts[-1] if replay_ts else None,
        "per_bucket_commits": per_bucket_commits,
        "default_commits": default_commits,
    }


def all_bucket_checks(steam_root: Path, appid: str) -> list[tuple[str, str, frozenset]]:
    """Every 'Found N buckets for AppId X CompatTool: Y' record for this
    appid, across both logs, in chronological order -- one entry per
    time Steam evaluated the active bucket set (not deduped)."""
    logs_dir = steam_root / "logs"
    results = []
    for log_name in ("shader_log.previous.txt", "shader_log.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        lines = p.read_text(errors="replace").splitlines()
        for idx, line in enumerate(lines):
            m = FOUND_BUCKETS_RE.match(line)
            if not m or m.group(2) != appid:
                continue
            ts, tool_name = m.group(1), m.group(3)
            hashes = set()
            j = idx + 1
            while j < len(lines):
                hm = BUCKET_HASH_RE.search(lines[j])
                if not hm:
                    break
                if hm.group(1):
                    hashes.add(hm.group(1))
                j += 1
            results.append((ts, tool_name, frozenset(hashes)))
    results.sort(key=lambda r: r[0])
    return results


def collect_events(ctx: "Context", appid: str, cutoff_dt: datetime.datetime) -> list[tuple]:
    """Chronological timeline for one title: shader replays, new
    content synced per bucket, and each time a compat tool's active
    bucket set actually changed (deduped against its full history, not
    just what falls in the window, so a change right at the cutoff
    still reads as a change rather than a false 'first seen')."""
    fmt = "%Y-%m-%d %H:%M:%S"
    logs_dir = ctx.steam_root / "logs"
    events = []

    for log_name in ("shader_log.previous.txt", "shader_log.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            m = REPLAY_START_RE.match(line)
            if m and m.group(2) == appid:
                dt = datetime.datetime.strptime(m.group(1), fmt)
                if dt >= cutoff_dt:
                    events.append((dt, "replay", "shader replay ran"))
                continue
            m = COMMIT_HASHED_RE.match(line)
            if m and m.group(2) == appid:
                dt = datetime.datetime.strptime(m.group(1), fmt)
                if dt >= cutoff_dt:
                    h = m.group(3)
                    lane = lane_label(ctx.hash_to_lane.get(h))
                    events.append(
                        (dt, "commit", f"new content synced -- {h} {lane} ({tools_text(h, ctx.hash_to_tools)})")
                    )
                continue
            m = COMMIT_DEFAULT_RE.match(line)
            if m and m.group(2) == appid:
                dt = datetime.datetime.strptime(m.group(1), fmt)
                if dt >= cutoff_dt:
                    events.append((dt, "commit", "new content synced -- default bucket"))

    last_hashes_by_tool: dict[str, frozenset] = {}
    for ts, tool_name, hashes in all_bucket_checks(ctx.steam_root, appid):
        prev = last_hashes_by_tool.get(tool_name)
        if prev == hashes:
            continue
        dt = datetime.datetime.strptime(ts, fmt)
        if dt >= cutoff_dt:
            shown = ", ".join(sorted(hashes)) or "(none)"
            verb = "first seen as" if prev is None else "CHANGED to"
            events.append((dt, "bucket-check", f"{tool_name}: active bucket set {verb} {shown}"))
        last_hashes_by_tool[tool_name] = hashes

    events.sort(key=lambda e: e[0])
    return events


def any_game_running() -> bool:
    result = subprocess.run(
        ["pgrep", "-f", r"reaper SteamLaunch AppId="],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return result.returncode == 0


def dir_size(path: Path) -> int:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())


def human(n: float) -> str:
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}TB"


def get_hash_to_lane(steam_root: Path) -> dict[str, str]:
    """Map bucket hash -> graphics-API translation lane (e.g. 'd3d11_64',
    'd3d12_64'). Steam keeps a *separate* crowd-sourced shader cache per
    lane for every compat tool -- DXVK (D3D11) and VKD3D-Proton (D3D12)
    pipelines are incompatible, so a title normally shows two buckets
    per tool for this reason alone, regardless of which one it actually
    uses at runtime."""
    logs_dir = steam_root / "logs"
    mapping = {}
    for log_name in ("shader_log.previous.txt", "shader_log.txt"):
        p = logs_dir / log_name
        if not p.exists():
            continue
        for line in p.read_text(errors="replace").splitlines():
            m = API_LANE_RE.search(line)
            if m:
                mapping[m.group(2)] = m.group(1)
    return mapping


def lane_label(lane: str | None) -> str:
    m = re.match(r"^(.+)_(\d+)$", lane or "")
    if not m:
        return "unknown API"
    api, bits = m.groups()
    return f"{api.upper()} ({bits}-bit)"


def tools_text(h: str, hash_to_tools: dict[str, list[str]], extra_tool: str | None = None) -> str:
    """Tool names historically associated with a bucket hash. extra_tool
    lets a caller assert the *currently configured* tool for a bucket
    it just confirmed is active -- some compat tools (third-party ones
    like GE-Proton in particular) don't always show up in the 'Got
    saved compat bucket for <tool>' log lines we mine this from, so
    without it an active bucket can misleadingly look unlabeled."""
    tools = set(hash_to_tools.get(h, ()))
    if extra_tool:
        tools.add(extra_tool)
    return ", ".join(sorted(tools)) if tools else "unknown tool"


def print_row(cols, widths, wrapped_text, indent="    ", wrap_width=WRAP_COL_WIDTH):
    """Print one or more fixed-width columns followed by a final
    column that word-wraps onto its own indented continuation lines
    instead of overflowing the terminal."""
    prefix = indent + "".join(f"{c:<{w}}" for c, w in zip(cols, widths))
    wrapped = textwrap.wrap(wrapped_text, wrap_width) or [""]
    print(prefix + wrapped[0])
    for line in wrapped[1:]:
        print(" " * len(prefix) + line)


def replay_rate_desc(stats: dict) -> str:
    n = stats["replay_count"]
    if n == 0:
        return "no shader-replay activity logged"
    if n == 1 or not stats["first_replay"] or stats["first_replay"] == stats["last_replay"]:
        return f"{n} replay event(s) logged"
    fmt = "%Y-%m-%d %H:%M:%S"
    first = datetime.datetime.strptime(stats["first_replay"], fmt)
    last = datetime.datetime.strptime(stats["last_replay"], fmt)
    days = max((last - first).total_seconds() / 86400, 0.01)
    return (
        f"{n} replay events between {stats['first_replay']} and {stats['last_replay']} "
        f"(~{n / days:.1f}/day)"
    )


class Context:
    def __init__(self, steam_root: Path):
        self.steam_root = steam_root
        self.compat_names = get_compat_tool_names(steam_root)
        self.hash_to_tools = get_hash_to_tools(steam_root)
        self.hash_to_lane = get_hash_to_lane(steam_root)
        self.library_paths = get_library_paths(steam_root)
        self.installed, self.app_names = get_installed_appids(self.library_paths)

    def title(self, appid: str) -> str:
        return self.app_names.get(appid, appid)


def cmd_check(ctx: Context, appids: list[str] | None, max_age_days: float) -> None:
    targets = appids or [a for a in ctx.installed if get_present_buckets(ctx.installed[a], a)]
    targets = sorted(targets, key=lambda a: int(a))

    if not appids:
        rows = []
        for appid in targets:
            lib = ctx.installed[appid]
            present = get_present_buckets(lib, appid)
            if not present:
                continue
            tool_name = ctx.compat_names.get(appid, "")
            _state, active, _age = resolve_bucket_state(ctx.steam_root, appid, tool_name, max_age_days)
            stale = [h for h in present if active is not None and h not in active]
            stale_size = sum(dir_size(present[h]) for h in stale)
            stats = churn_stats(ctx.steam_root, appid)
            rows.append((appid, tool_name, len(present), stale_size, stats))
        rows.sort(key=lambda r: r[4]["replay_count"], reverse=True)
        print(f"{'AppID':<9} {'Title':<32} {'Tool':<20} {'Buckets':<8} {'Stale':<9} Replay churn")
        for appid, tool_name, n_buckets, stale_size, stats in rows:
            print_row(
                [appid, ctx.title(appid)[:31], (tool_name or "(default)")[:19], str(n_buckets), human(stale_size)],
                [10, 33, 21, 9, 10],
                replay_rate_desc(stats),
                indent="",
            )
        return

    for appid in targets:
        if appid not in ctx.installed:
            print(f"[{appid}] not installed, skipping")
            continue
        lib = ctx.installed[appid]
        present = get_present_buckets(lib, appid)
        title = ctx.title(appid)
        tool_name = ctx.compat_names.get(appid, "")
        state, active, age_days = resolve_bucket_state(ctx.steam_root, appid, tool_name, max_age_days)
        stats = churn_stats(ctx.steam_root, appid)

        print(f"[{appid}] {title} -- configured tool: {tool_name or '(Steam default)'}")
        print(f"    {replay_rate_desc(stats)}")
        if not present:
            print("    no shader cache buckets on disk")
            print()
            continue

        print(f"    dir: {next(iter(present.values())).parent}")
        for h, p in sorted(present.items()):
            size = dir_size(p)
            is_active = active is not None and h in active
            label = "?????" if active is None else ("ACTIVE" if is_active else "STALE")
            commits = stats["per_bucket_commits"].get(h, 0)
            extra = tool_name if is_active else None
            lane = lane_label(ctx.hash_to_lane.get(h))
            print_row(
                [label, h], [8, 18], f"{human(size)}  {lane}  {tools_text(h, ctx.hash_to_tools, extra)}  ({commits} commit(s) seen)"
            )

        if state == "none":
            print("    (no 'Found buckets' log record for this tool -- active/stale unknown)")
        elif state == "stale_evidence":
            print(
                f"    (last verified {age_days:.1f}d ago -- older than --max-bucket-age-days={max_age_days}; "
                f"this tool may have moved on, re-launch the game to refresh before trusting this)"
            )
        print()


def cmd_trim(ctx: Context, appids: list[str] | None, max_age_days: float) -> None:
    targets = appids or list(ctx.installed)
    targets = sorted(targets, key=lambda a: int(a))

    to_delete = []
    total_reclaimable = 0

    for appid in targets:
        if appid not in ctx.installed:
            continue
        lib = ctx.installed[appid]
        present = get_present_buckets(lib, appid)
        if not present:
            continue

        title = ctx.title(appid)
        tool_name = ctx.compat_names.get(appid, "")
        state, active, age_days = resolve_bucket_state(ctx.steam_root, appid, tool_name, max_age_days)
        label = f"[{appid}] {title} -- configured tool: {tool_name or '(Steam default)'}"

        if state == "none":
            print(label)
            print("    no 'Found buckets' record for this tool in shader_log -- skipping (can't confirm what's active)")
            continue
        if state == "stale_evidence":
            print(label)
            print(f"    last bucket record for this tool is {age_days:.1f}d old (older than --max-bucket-age-days={max_age_days})")
            print("    this tool may have moved on since -- skipping (re-launch the game to refresh, then re-run)")
            continue

        print(label)
        print(f"    dir: {next(iter(present.values())).parent}")
        for h, p in sorted(present.items()):
            size = dir_size(p)
            is_active = h in active
            label_state = "ACTIVE" if is_active else "STALE"
            extra = tool_name if is_active else None
            lane = lane_label(ctx.hash_to_lane.get(h))
            print_row([label_state, h], [8, 18], f"{human(size)}  {lane}  {tools_text(h, ctx.hash_to_tools, extra)}")
            if h not in active:
                to_delete.append((appid, h, p, size))
                total_reclaimable += size

    print()
    if not to_delete:
        print("Nothing stale found. No changes made.")
        return

    print(f"{len(to_delete)} stale bucket(s) across {len({a for a, *_ in to_delete})} game(s), {human(total_reclaimable)} reclaimable:")
    for appid, h, p, size in to_delete:
        print_row([ctx.title(appid)[:23], h], [24, 18], f"{human(size)}  {tools_text(h, ctx.hash_to_tools)}")

    if any_game_running():
        print("\nA game is currently running -- cancelling. Quit it and re-run.")
        return

    try:
        answer = input(f"\nDelete these {len(to_delete)} bucket(s) and reclaim {human(total_reclaimable)}? [y/N] ").strip().lower()
    except EOFError:
        answer = ""

    if answer not in ("y", "yes"):
        print("Cancelled. No changes made.")
        return

    if any_game_running():
        print("A game started while waiting for confirmation -- cancelling. No changes made.")
        return

    for appid, h, p, size in to_delete:
        shutil.rmtree(p)
        print_row(["removed", ctx.title(appid)[:23], h], [10, 24, 18], f"{human(size)}  {tools_text(h, ctx.hash_to_tools)}")

    print(f"\nReclaimed {human(total_reclaimable)}.")


def cmd_show_events(ctx: Context, appid: str, max_days: float) -> None:
    if appid not in ctx.installed:
        print(f"[{appid}] not installed")
        return
    title = ctx.title(appid)
    tool_name = ctx.compat_names.get(appid, "")
    cutoff_dt = datetime.datetime.now() - datetime.timedelta(days=max_days)
    events = collect_events(ctx, appid, cutoff_dt)

    print(f"[{appid}] {title} -- configured tool: {tool_name or '(Steam default)'}")
    print(f"    last {max_days:g} day(s): {len(events)} event(s)")
    print()
    if not events:
        print("    no events in this window")
        return
    for dt, kind, text in events:
        print_row([dt.strftime("%Y-%m-%d %H:%M:%S"), kind], [21, 14], text, wrap_width=EVENTS_WRAP_COL_WIDTH)


def register_subparser(subparsers) -> None:
    parser = subparsers.add_parser("shader", help="inspect/trim Vulkan (Fossilize) shader caches")
    parser.add_argument("--steam-root", type=Path, default=DEFAULT_STEAM_ROOT)
    parser.add_argument(
        "--max-bucket-age-days",
        type=float,
        default=DEFAULT_MAX_BUCKET_AGE_DAYS,
        help=(
            "how old Steam's last 'active buckets' record for a title's compat "
            f"tool may be before it's treated as unreliable (default {DEFAULT_MAX_BUCKET_AGE_DAYS})."
        ),
    )
    sub = parser.add_subparsers(dest="shader_command", required=True)

    check_p = sub.add_parser("check", help="read-only: show buckets and shader-replay churn")
    check_p.add_argument("--appid", action="append", help="show detail for this appid (repeatable)")
    check_p.set_defaults(func=_cmd_check)

    trim_p = sub.add_parser("trim", help="delete buckets not used by a title's current compat tool")
    trim_p.add_argument("--appid", action="append", help="limit to this appid (repeatable); omit for all")
    trim_p.set_defaults(func=_cmd_trim)

    events_p = sub.add_parser("show-events", help="read-only: chronological shader-cache event timeline")
    events_p.add_argument("--appid", required=True)
    events_p.add_argument("--max-days", type=float, default=30)
    events_p.set_defaults(func=_cmd_show_events)


def _cmd_check(args) -> int:
    ctx = Context(args.steam_root)
    cmd_check(ctx, args.appid, args.max_bucket_age_days)
    return 0


def _cmd_trim(args) -> int:
    appids = args.appid
    if appids and any(a.lower() == "all" for a in appids):
        appids = None
    ctx = Context(args.steam_root)
    cmd_trim(ctx, appids, args.max_bucket_age_days)
    return 0


def _cmd_show_events(args) -> int:
    ctx = Context(args.steam_root)
    cmd_show_events(ctx, args.appid, args.max_days)
    return 0
