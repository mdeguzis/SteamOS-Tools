from pathlib import Path

from steamostools.tools import systeminfo

SAMPLE_CPUINFO = """\
processor\t: 0
vendor_id\t: AuthenticAMD
model name\t: AMD Custom APU 0405
cpu family\t: 23
model\t\t: 144
stepping\t: 1
cpu cores\t: 4
flags\t\t: fpu vme de pse ht sse2 sse3 avx avx2 cx16 lahf_lm
"""

SAMPLE_GLXINFO = """\
OpenGL vendor string: AMD
OpenGL renderer string: AMD Custom GPU 0405 (radeonsi, navi10)
OpenGL version string: 4.6 (Compatibility Profile) Mesa 23.0.0
    Dedicated video memory: 8192 MB
"""

SAMPLE_XDPYINFO = """\
name of display:    :0
version number:    11.0
vendor string:    The X.Org Foundation
vendor release number:    12013000
dimensions:    1280x800 pixels (338x211 millimeters)
depth of root window:    24 planes
"""

SAMPLE_XRANDR = """\
Screen 0: minimum 320 x 200, current 1280 x 800, maximum 8192 x 8192
eDP connected primary 1280x800+0+0 (normal left inverted right x axis y) 294mm x 165mm
   1280x800     60.05*+  59.99
"""

SAMPLE_XRANDR_MONITORS = "Monitors: 1\n eDP-1 1280/294x800/165+0+0  eDP\n"

SAMPLE_UDEVADM_TOUCH = """\
P: /devices/touchscreen0
E: NAME="ELAN Touchscreen"
E: ID_INPUT_TOUCHSCREEN=1

P: /devices/mouse0
E: NAME="Some Mouse"
"""

SAMPLE_LSBLK_DEVICES = [
    {"name": "sda", "tran": "usb", "rota": False},
    {"name": "nvme0n1", "tran": None, "rota": True},
    {"name": "nvme1n1", "tran": None, "rota": False},
]


def test_parse_cpuinfo_field_extracts_value():
    assert systeminfo.parse_cpuinfo_field(SAMPLE_CPUINFO, "vendor_id") == "AuthenticAMD"
    assert systeminfo.parse_cpuinfo_field(SAMPLE_CPUINFO, "model name") == "AMD Custom APU 0405"


def test_parse_cpuinfo_field_missing_returns_empty():
    assert systeminfo.parse_cpuinfo_field(SAMPLE_CPUINFO, "nonexistent") == ""


def test_parse_cpu_flags_returns_set():
    flags = systeminfo.parse_cpu_flags(SAMPLE_CPUINFO)
    assert "sse2" in flags
    assert "avx2" in flags
    assert "avx512f" not in flags


def test_cpu_flag_report_marks_supported_and_unsupported():
    report = systeminfo.cpu_flag_report({"sse2", "avx"})
    assert report["SSE2"] is True
    assert report["AVX"] is True
    assert report["AVX2"] is False


def test_hex_field_converts_decimal_to_hex():
    assert systeminfo._hex_field(SAMPLE_CPUINFO, "cpu family") == "0x17"
    assert systeminfo._hex_field(SAMPLE_CPUINFO, "model") == "0x90"


def test_hex_field_unknown_when_not_numeric():
    assert systeminfo._hex_field("vendor_id: AMD\n", "vendor_id") == systeminfo.UNKNOWN


def test_parse_glxinfo_field_extracts_renderer():
    assert "navi10" in systeminfo.parse_glxinfo_field(SAMPLE_GLXINFO, "OpenGL renderer string:")


def test_parse_glxinfo_field_missing_returns_unknown():
    assert systeminfo.parse_glxinfo_field(SAMPLE_GLXINFO, "Nonexistent field:") == systeminfo.UNKNOWN


def test_parse_xdpyinfo_color_depth():
    assert systeminfo.parse_xdpyinfo_color_depth(SAMPLE_XDPYINFO) == "24"


def test_parse_xdpyinfo_color_depth_defaults_when_missing():
    assert systeminfo.parse_xdpyinfo_color_depth("") == "24"


def test_parse_xdpyinfo_resolution():
    assert systeminfo.parse_xdpyinfo_resolution(SAMPLE_XDPYINFO) == "1280 x 800"


def test_parse_refresh_rate_finds_starred_mode():
    assert systeminfo.parse_refresh_rate(SAMPLE_XRANDR) == "60"


def test_parse_refresh_rate_unknown_when_missing():
    assert systeminfo.parse_refresh_rate("no modes here") == systeminfo.UNKNOWN


def test_parse_num_monitors():
    assert systeminfo.parse_num_monitors(SAMPLE_XRANDR_MONITORS) == "1"


def test_parse_primary_display_size_computes_diagonal():
    result = systeminfo.parse_primary_display_size(SAMPLE_XRANDR)
    assert "diag" in result
    assert result.startswith("13.27")  # 294mm x 165mm diagonal


def test_parse_primary_display_size_unknown_when_no_match():
    assert systeminfo.parse_primary_display_size("nothing connected here") == systeminfo.UNKNOWN


def test_detect_touch_input_found():
    result = systeminfo.detect_touch_input(SAMPLE_UDEVADM_TOUCH)
    assert "ELAN Touchscreen" in result


def test_detect_touch_input_not_found():
    assert systeminfo.detect_touch_input("no touch stuff here") == "No Touch Input Detected"


def test_parse_vga_pci_id():
    vendor, device = systeminfo.parse_vga_pci_id("01:00.0 0300: 1002:1636 (rev c1)")
    assert vendor == "0x1002"
    assert device == "0x1636"


def test_parse_vga_pci_id_unknown_when_no_match():
    vendor, device = systeminfo.parse_vga_pci_id("")
    assert vendor == systeminfo.UNKNOWN
    assert device == systeminfo.UNKNOWN


def test_classify_storage_ignores_usb_and_counts_rotational():
    ssd, hdd = systeminfo.classify_storage(SAMPLE_LSBLK_DEVICES)
    assert ssd == 1  # nvme1n1
    assert hdd == 1  # nvme0n1
    # sda (usb) is excluded from both counts


def test_parse_lscpu_max_mhz():
    text = "CPU max MHz:         3500.0000\n"
    assert systeminfo.parse_lscpu_max_mhz(text) == "3500"


def test_parse_lscpu_max_mhz_unknown_when_missing():
    assert systeminfo.parse_lscpu_max_mhz("") == systeminfo.UNKNOWN


def test_parse_pulsemixer_default_sink():
    text = "ID: 1, Name: alsa_output.default, Default\n"
    assert systeminfo.parse_pulsemixer_default_sink(text) == "alsa_output.default"


def test_parse_df_output_strips_header_and_unit():
    text = "SIZE\n512000M\n"
    assert systeminfo.parse_df_output(text) == "512000"


def test_parse_df_output_unknown_when_insufficient_lines():
    assert systeminfo.parse_df_output("") == systeminfo.UNKNOWN


def test_detect_steam_runtime_version_none_when_missing(tmp_path):
    assert systeminfo.detect_steam_runtime_version(tmp_path / "nonexistent") == "None"


def test_detect_steam_runtime_version_parses_build_id(tmp_path):
    common = tmp_path / "common"
    runtime_dir = common / "SteamLinuxRuntime_sniper" / "var" / "tmp-abc123" / "usr" / "lib"
    runtime_dir.mkdir(parents=True)
    (runtime_dir / "os-release").write_text('BUILD_ID="20240101.100"\n')

    assert systeminfo.detect_steam_runtime_version(common) == "steam-runtime_20240101.100"


def test_detect_window_manager_gamescope(monkeypatch):
    def fake_run(cmd, **kwargs):
        class _R:
            returncode = 0 if cmd[-1] == "gamescope" else 1

        return _R()

    monkeypatch.setattr(systeminfo, "run", fake_run)
    assert systeminfo.detect_window_manager() == "Gamescope"


def test_detect_window_manager_unknown_when_neither_running(monkeypatch):
    class _R:
        returncode = 1

    monkeypatch.setattr(systeminfo, "run", lambda cmd, **kw: _R())
    assert systeminfo.detect_window_manager() == systeminfo.UNKNOWN


def test_run_text_returns_empty_when_binary_missing(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: None)
    assert systeminfo.run_text(["nonexistent-binary"]) == ""


def test_read_text_returns_empty_on_missing_file(tmp_path):
    assert systeminfo.read_text(tmp_path / "nope.txt") == ""


def test_systeminfo_to_dict_and_json_roundtrip():
    info = systeminfo.SystemInfo(manufacturer="Valve", model="Jupiter")
    d = info.to_dict()
    assert d["manufacturer"] == "Valve"
    import json

    assert json.loads(info.to_json())["model"] == "Jupiter"


def test_systeminfo_to_report_contains_key_sections():
    info = systeminfo.SystemInfo(manufacturer="Valve", model="Jupiter", cpu_flags={"SSE2": True, "AVX2": False})
    report = info.to_report()
    assert "Computer Information:" in report
    assert "Valve" in report
    assert "SSE2:  Supported" in report
    assert "AVX2:  Unsupported" in report


def test_collect_system_info_degrades_gracefully_when_tools_missing(monkeypatch):
    monkeypatch.setattr("shutil.which", lambda name: None)
    monkeypatch.setattr(systeminfo, "read_text", lambda path: "")

    class _R:
        returncode = 1
        stdout = ""

    monkeypatch.setattr(systeminfo, "run", lambda cmd, **kw: _R())

    info = systeminfo.collect_system_info(steam_common_dir=Path("/nonexistent"))

    assert info.manufacturer == systeminfo.UNKNOWN
    assert info.window_manager == systeminfo.UNKNOWN
    assert info.steam_runtime_version == "None"
    assert info.ram_mb == 0
