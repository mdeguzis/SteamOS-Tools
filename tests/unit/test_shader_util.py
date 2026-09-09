import datetime
from pathlib import Path

from steamostools.tools import shader_util

CONFIG_VDF = """
"InstallConfigStore"
{
	"Software"
	{
		"Valve"
		{
			"Steam"
			{
				"CompatToolMapping"
				{
					"123"
					{
						"name"		"proton_experimental"
					}
					"456"
					{
						"name"		""
					}
				}
			}
		}
	}
}
"""

LIBRARYFOLDERS_VDF = """
"libraryfolders"
{
	"0"
	{
		"path"		"/home/deck/.local/share/Steam"
	}
	"1"
	{
		"path"		"/run/media/mmcblk0p1/steamlibrary"
	}
}
"""


def _make_steam_root(tmp_path: Path) -> Path:
    root = tmp_path / "Steam"
    (root / "config").mkdir(parents=True)
    (root / "config" / "config.vdf").write_text(CONFIG_VDF)
    (root / "steamapps").mkdir(parents=True)
    (root / "steamapps" / "libraryfolders.vdf").write_text(LIBRARYFOLDERS_VDF)
    return root


def test_get_compat_tool_names_parses_mapping(tmp_path):
    root = _make_steam_root(tmp_path)
    names = shader_util.get_compat_tool_names(root)
    assert names == {"123": "proton_experimental", "456": ""}


def test_get_library_paths_parses_libraryfolders(tmp_path):
    root = _make_steam_root(tmp_path)
    paths = shader_util.get_library_paths(root)
    assert paths == [Path("/home/deck/.local/share/Steam"), Path("/run/media/mmcblk0p1/steamlibrary")]


def test_get_library_paths_falls_back_to_steam_root_if_missing(tmp_path):
    root = tmp_path / "Steam"
    root.mkdir()
    assert shader_util.get_library_paths(root) == [root]


def test_get_installed_appids_reads_manifests(tmp_path):
    root = _make_steam_root(tmp_path)
    steamapps = root / "steamapps"
    (steamapps / "appmanifest_123.acf").write_text('"AppState"\n{\n\t"name"\t\t"Half-Life"\n}\n')

    appids, names = shader_util.get_installed_appids([root])

    assert appids["123"] == root
    assert names["123"] == "Half-Life"


def test_get_present_buckets_finds_bucket_dirs(tmp_path):
    root = _make_steam_root(tmp_path)
    shadercache = root / "steamapps" / "shadercache" / "123" / "fozpipelinesv6"
    (shadercache / "steamapprun_pipeline_cache.deadbeef").mkdir(parents=True)
    (shadercache / "not_a_bucket_dir").mkdir()

    present = shader_util.get_present_buckets(root, "123")

    assert set(present.keys()) == {"deadbeef"}


def test_human_formats_bytes():
    assert shader_util.human(500) == "500.0B"
    assert shader_util.human(2048) == "2.0KB"
    assert shader_util.human(1024 * 1024 * 3) == "3.0MB"


def test_lane_label_parses_api_and_bitness():
    assert shader_util.lane_label("d3d11_64") == "D3D11 (64-bit)"
    assert shader_util.lane_label(None) == "unknown API"
    assert shader_util.lane_label("garbage") == "unknown API"


def test_tools_text_merges_extra_tool():
    hash_to_tools = {"abc": ["proton_experimental"]}
    assert shader_util.tools_text("abc", hash_to_tools) == "proton_experimental"
    assert shader_util.tools_text("abc", hash_to_tools, extra_tool="GE-Proton9-1") == (
        "GE-Proton9-1, proton_experimental"
    )
    assert shader_util.tools_text("missing", {}) == "unknown tool"


def test_any_game_running_reflects_pgrep_returncode(monkeypatch):
    class _Result:
        returncode = 0

    monkeypatch.setattr(shader_util.subprocess, "run", lambda *a, **kw: _Result())
    assert shader_util.any_game_running() is True

    class _NotRunning:
        returncode = 1

    monkeypatch.setattr(shader_util.subprocess, "run", lambda *a, **kw: _NotRunning())
    assert shader_util.any_game_running() is False


def test_resolve_bucket_state_none_when_no_record(tmp_path):
    root = _make_steam_root(tmp_path)
    state, hashes, age = shader_util.resolve_bucket_state(root, "123", "proton_experimental", 7)
    assert state == "none"
    assert hashes is None
    assert age is None


def test_context_loads_all_maps(tmp_path):
    root = _make_steam_root(tmp_path)
    (root / "steamapps" / "appmanifest_123.acf").write_text('"AppState"\n{\n\t"name"\t\t"Half-Life"\n}\n')
    # Context resolves library paths via libraryfolders.vdf; point it at our
    # actual tmp root instead of the fixture's illustrative fake paths so the
    # appmanifest above is actually discoverable.
    (root / "steamapps" / "libraryfolders.vdf").write_text(
        f'"libraryfolders"\n{{\n\t"0"\n\t{{\n\t\t"path"\t\t"{root}"\n\t}}\n}}\n'
    )

    ctx = shader_util.Context(root)

    assert ctx.compat_names["123"] == "proton_experimental"
    assert ctx.title("123") == "Half-Life"
    assert ctx.title("999") == "999"


# ---------------------------------------------------------------------------
# shader_log.txt-driven logic: churn stats, active-bucket resolution, events
# ---------------------------------------------------------------------------


def _write_shader_log(root: Path, text: str, filename: str = "shader_log.txt") -> None:
    logs_dir = root / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    (logs_dir / filename).write_text(text)


def _log_line(dt: datetime.datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def test_churn_stats_counts_replays_and_hashed_commits(tmp_path):
    root = tmp_path / "Steam"
    log = (
        "[2026-01-01 10:00:00] Starting replay of FOZ databases for AppID 123 blah\n"
        "[2026-01-02 10:00:00] Starting replay of FOZ databases for AppID 123 blah\n"
        "[2026-01-01 10:05:00] Committed bucket 1 (AppID 123) contains file "
        "'fozpipelinesv6\\steamapprun_pipeline_cache.aaaa1111\\steam_pipeline_cache.foz'\n"
        "[2026-01-01 10:06:00] Committed bucket 2 (AppID 123) contains file "
        "'fozpipelinesv6\\steam_pipeline_cache.foz'\n"
    )
    _write_shader_log(root, log)

    stats = shader_util.churn_stats(root, "123")

    assert stats["replay_count"] == 2
    assert stats["first_replay"] == "2026-01-01 10:00:00"
    assert stats["last_replay"] == "2026-01-02 10:00:00"
    assert stats["per_bucket_commits"] == {"aaaa1111": 1}
    assert stats["default_commits"] == 1


def test_get_hash_to_tools_maps_hash_to_sorted_tool_names(tmp_path):
    root = tmp_path / "Steam"
    log = (
        "Got saved compat bucket for proton_experimental: SteamSwarm / G7:VulkanPipelinesV6_aaaa1111\n"
        "Got saved compat bucket for GE-Proton9-1: SteamSwarm / G7:VulkanPipelinesV6_aaaa1111\n"
    )
    _write_shader_log(root, log)

    mapping = shader_util.get_hash_to_tools(root)

    assert mapping == {"aaaa1111": ["GE-Proton9-1", "proton_experimental"]}


def test_get_hash_to_lane_maps_hash_to_api_lane(tmp_path):
    root = tmp_path / "Steam"
    log = "shader_cache_temp_dir_d3d11_64/fozpipelinesv6/steamapprun_pipeline_cache.aaaa1111\n"
    _write_shader_log(root, log)

    mapping = shader_util.get_hash_to_lane(root)

    assert mapping == {"aaaa1111": "d3d11_64"}


def test_find_active_buckets_returns_latest_matching_record(tmp_path):
    root = tmp_path / "Steam"
    log = (
        "[2026-01-01 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_aaaa1111\n"
        "[2026-01-05 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_bbbb2222\n"
    )
    _write_shader_log(root, log)

    hashes, ts = shader_util.find_active_buckets(root, "123", "proton_experimental")

    assert hashes == {"bbbb2222"}
    assert ts == "2026-01-05 10:00:00"


def test_find_active_buckets_none_for_unmatched_tool(tmp_path):
    root = tmp_path / "Steam"
    log = "[2026-01-01 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\nVulkanPipelinesV6_aaaa1111\n"
    _write_shader_log(root, log)

    hashes, ts = shader_util.find_active_buckets(root, "123", "GE-Proton9-1")

    assert hashes is None
    assert ts is None


def test_resolve_bucket_state_ok_when_recent(tmp_path):
    root = tmp_path / "Steam"
    recent = _log_line(datetime.datetime.now() - datetime.timedelta(hours=1))
    log = f"[{recent}] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\nVulkanPipelinesV6_aaaa1111\n"
    _write_shader_log(root, log)

    state, hashes, age_days = shader_util.resolve_bucket_state(root, "123", "proton_experimental", 7)

    assert state == "ok"
    assert hashes == {"aaaa1111"}
    assert age_days < 1


def test_resolve_bucket_state_stale_when_old(tmp_path):
    root = tmp_path / "Steam"
    log = "[2000-01-01 00:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\nVulkanPipelinesV6_aaaa1111\n"
    _write_shader_log(root, log)

    state, hashes, age_days = shader_util.resolve_bucket_state(root, "123", "proton_experimental", 7)

    assert state == "stale_evidence"
    assert age_days > 7


def test_all_bucket_checks_returns_chronological_order(tmp_path):
    root = tmp_path / "Steam"
    log = (
        "[2026-01-05 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_bbbb2222\n"
        "[2026-01-01 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_aaaa1111\n"
    )
    _write_shader_log(root, log)

    results = shader_util.all_bucket_checks(root, "123")

    assert [ts for ts, _, _ in results] == ["2026-01-01 10:00:00", "2026-01-05 10:00:00"]


def test_collect_events_includes_replay_and_bucket_change(tmp_path):
    root = tmp_path / "Steam"
    (root / "config").mkdir(parents=True)
    (root / "config" / "config.vdf").write_text('"CompatToolMapping"\n{\n}\n')
    log = (
        "[2026-01-01 10:00:00] Starting replay of FOZ databases for AppID 123 blah\n"
        "[2026-01-01 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_aaaa1111\n"
        "[2026-01-02 10:00:00] Found 1 buckets for AppId 123 CompatTool: proton_experimental:\n"
        "VulkanPipelinesV6_bbbb2222\n"
    )
    _write_shader_log(root, log)
    ctx = shader_util.Context(root)

    events = shader_util.collect_events(ctx, "123", datetime.datetime(2020, 1, 1))
    kinds = [kind for _, kind, _ in events]

    assert "replay" in kinds
    assert "bucket-check" in kinds
    # The change from aaaa1111 -> bbbb2222 should show up as a CHANGED event
    assert any("CHANGED" in text for _, _, text in events)


# ---------------------------------------------------------------------------
# CLI-facing commands (output verified via capsys, not exact formatting)
# ---------------------------------------------------------------------------


def _make_installed_game_with_buckets(root: Path, appid: str, active_hash: str, stale_hash: str):
    (root / "config").mkdir(parents=True, exist_ok=True)
    (root / "config" / "config.vdf").write_text(
        f'"CompatToolMapping"\n{{\n\t"{appid}"\n\t{{\n\t\t"name"\t\t"proton_experimental"\n\t}}\n}}\n'
    )
    steamapps = root / "steamapps"
    steamapps.mkdir(parents=True, exist_ok=True)
    (steamapps / "libraryfolders.vdf").write_text(
        f'"libraryfolders"\n{{\n\t"0"\n\t{{\n\t\t"path"\t\t"{root}"\n\t}}\n}}\n'
    )
    (steamapps / f"appmanifest_{appid}.acf").write_text('"AppState"\n{\n\t"name"\t\t"Test Game"\n}\n')
    shadercache = steamapps / "shadercache" / appid / "fozpipelinesv6"
    (shadercache / f"steamapprun_pipeline_cache.{active_hash}").mkdir(parents=True)
    (shadercache / f"steamapprun_pipeline_cache.{stale_hash}").mkdir(parents=True)

    recent = _log_line(datetime.datetime.now() - datetime.timedelta(hours=1))
    log = f"[{recent}] Found 1 buckets for AppId {appid} CompatTool: proton_experimental:\nVulkanPipelinesV6_{active_hash}\n"
    _write_shader_log(root, log)


def test_cmd_check_detail_mode_reports_active_and_stale(tmp_path, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    shader_util.cmd_check(ctx, ["123"], 7)

    out = capsys.readouterr().out
    assert "Test Game" in out
    assert "ACTIVE" in out
    assert "STALE" in out


def test_cmd_check_leaderboard_mode_prints_header(tmp_path, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    shader_util.cmd_check(ctx, None, 7)

    out = capsys.readouterr().out
    assert "AppID" in out
    assert "Replay churn" in out


def test_cmd_trim_deletes_after_confirmation(tmp_path, monkeypatch, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    monkeypatch.setattr("builtins.input", lambda prompt="": "y")
    monkeypatch.setattr(shader_util, "any_game_running", lambda: False)

    shader_util.cmd_trim(ctx, ["123"], 7)

    stale_dir = root / "steamapps" / "shadercache" / "123" / "fozpipelinesv6" / "steamapprun_pipeline_cache.bbbb2222"
    active_dir = root / "steamapps" / "shadercache" / "123" / "fozpipelinesv6" / "steamapprun_pipeline_cache.aaaa1111"
    assert not stale_dir.exists()
    assert active_dir.exists()
    assert "Reclaimed" in capsys.readouterr().out


def test_cmd_trim_cancels_without_confirmation(tmp_path, monkeypatch, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    monkeypatch.setattr("builtins.input", lambda prompt="": "n")
    monkeypatch.setattr(shader_util, "any_game_running", lambda: False)

    shader_util.cmd_trim(ctx, ["123"], 7)

    stale_dir = root / "steamapps" / "shadercache" / "123" / "fozpipelinesv6" / "steamapprun_pipeline_cache.bbbb2222"
    assert stale_dir.exists()
    assert "Cancelled" in capsys.readouterr().out


def test_cmd_trim_skips_when_game_running(tmp_path, monkeypatch, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    monkeypatch.setattr(shader_util, "any_game_running", lambda: True)

    shader_util.cmd_trim(ctx, ["123"], 7)

    stale_dir = root / "steamapps" / "shadercache" / "123" / "fozpipelinesv6" / "steamapprun_pipeline_cache.bbbb2222"
    assert stale_dir.exists()
    assert "cancelling" in capsys.readouterr().out


def test_cmd_show_events_prints_timeline(tmp_path, capsys):
    root = tmp_path / "Steam"
    _make_installed_game_with_buckets(root, "123", "aaaa1111", "bbbb2222")
    ctx = shader_util.Context(root)

    shader_util.cmd_show_events(ctx, "123", 30)

    out = capsys.readouterr().out
    assert "Test Game" in out
    assert "event(s)" in out


def test_cmd_show_events_reports_not_installed(capsys):
    ctx_stub = type("Ctx", (), {"installed": {}})()
    shader_util.cmd_show_events(ctx_stub, "999", 30)
    assert "not installed" in capsys.readouterr().out
