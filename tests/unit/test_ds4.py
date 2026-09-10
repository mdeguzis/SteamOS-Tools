import pytest

from steamostools.tools import ds4


def test_render_udev_rule_substitutes_device_id():
    rule = ds4.render_udev_rule("abc123")
    assert 'ATTRS{uniq}=="abc123"' in rule
    assert "/usr/local/bin/ds4led" in rule


def test_install_udev_rule_writes_file(tmp_path):
    rule_path = tmp_path / "10-local-ds4.rules"
    ds4.install_udev_rule("abc123", rule_path=rule_path)
    assert 'ATTRS{uniq}=="abc123"' in rule_path.read_text()


def test_get_js0_device_id_parses_phys_attribute(monkeypatch):
    class _PathResult:
        stdout = "/devices/foo/input/input0\n"

    class _InfoResult:
        stdout = 'looking at device...\n  ATTRS{phys}=="usb-0000:00:14.0-1/input0"\n'

    results = iter([_PathResult(), _InfoResult()])
    monkeypatch.setattr(ds4, "run", lambda cmd, **kw: next(results))

    assert ds4.get_js0_device_id() == "usb-0000:00:14.0-1/input0"


def test_get_js0_device_id_raises_if_not_found(monkeypatch):
    class _Result:
        stdout = "nothing relevant here\n"

    monkeypatch.setattr(ds4, "run", lambda cmd, **kw: _Result())
    with pytest.raises(ds4.DeviceNotFoundError):
        ds4.get_js0_device_id()


def test_find_led_name_matches_global_led(tmp_path):
    (tmp_path / "0005:054c:09cc.0001:global").mkdir()
    (tmp_path / "input0::numlock").mkdir()

    assert ds4.find_led_name(tmp_path) == "0005:054c:09cc.0001"


def test_find_led_name_returns_none_when_missing(tmp_path):
    assert ds4.find_led_name(tmp_path) is None


def test_set_led_color_writes_rgb_brightness_files(tmp_path):
    led_dir = tmp_path
    for channel in ("red", "green", "blue"):
        (led_dir / f"0005:054c:09cc.0001:{channel}").mkdir()
    (led_dir / "0005:054c:09cc.0001:global").mkdir()

    ds4.set_led_color("ff8000", leds_root=led_dir)

    assert (led_dir / "0005:054c:09cc.0001:red" / "brightness").read_text() == "255"
    assert (led_dir / "0005:054c:09cc.0001:green" / "brightness").read_text() == "128"
    assert (led_dir / "0005:054c:09cc.0001:blue" / "brightness").read_text() == "0"


def test_set_led_color_raises_if_no_device_found(tmp_path):
    with pytest.raises(ds4.DeviceNotFoundError):
        ds4.set_led_color("ff0000", leds_root=tmp_path)
