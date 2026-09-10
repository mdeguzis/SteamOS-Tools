import pytest

from steamostools.platform_detect import Platform
from steamostools.tools import ps4_wake


def test_missing_kargs_detects_absent_args():
    assert ps4_wake.missing_kargs("root=UUID=x") == list(ps4_wake.REQUIRED_KARGS)


def test_missing_kargs_empty_when_all_present():
    current = "root=UUID=x mem_sleep_default=deep pcie_port_pm=off"
    assert ps4_wake.missing_kargs(current) == []


def test_apply_kernel_args_appends_missing_only(monkeypatch):
    class _Result:
        stdout = "root=UUID=x mem_sleep_default=deep"

    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        return _Result()

    monkeypatch.setattr(ps4_wake, "run", fake_run)

    added = ps4_wake.apply_kernel_args()

    assert added == ["pcie_port_pm=off"]
    assert ["sudo", "rpm-ostree", "kargs", "--append=pcie_port_pm=off"] in calls
    assert not any("mem_sleep_default" in " ".join(c) for c in calls if c[0] == "sudo")


def test_install_udev_rule_writes_file_and_reloads(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(ps4_wake, "run", lambda cmd, **kw: calls.append(cmd))
    rule_path = tmp_path / "90-ps4-controller-wake.rules"

    ps4_wake.install_udev_rule(rule_path)

    assert "ATTRS{idVendor}==\"8087\"" in rule_path.read_text()
    assert ["sudo", "udevadm", "control", "--reload-rules"] in calls
    assert ["sudo", "udevadm", "trigger"] in calls


def test_disable_noisy_acpi_triggers_only_disables_enabled_ones(tmp_path, monkeypatch):
    wakeup_file = tmp_path / "wakeup"
    wakeup_file.write_text("XHCI\t\t  S3\t*enabled\nAWAC\t  S3\t*disabled\n")
    calls = []
    monkeypatch.setattr(ps4_wake, "run", lambda cmd, **kw: calls.append(cmd))

    disabled = ps4_wake.disable_noisy_acpi_triggers(wakeup_file)

    assert disabled == ["XHCI"]
    assert any("XHCI" in c[-1] for c in calls)


def test_disable_noisy_acpi_triggers_returns_empty_when_file_missing(tmp_path):
    assert ps4_wake.disable_noisy_acpi_triggers(tmp_path / "missing") == []


def test_enable_bluetooth_fast_connectable_skips_when_conf_missing(tmp_path, monkeypatch):
    calls = []
    monkeypatch.setattr(ps4_wake, "run", lambda cmd, **kw: calls.append(cmd))
    ps4_wake.enable_bluetooth_fast_connectable(tmp_path / "missing.conf")
    assert calls == []


def test_enable_bluetooth_fast_connectable_runs_sed_when_present(tmp_path, monkeypatch):
    conf = tmp_path / "main.conf"
    conf.write_text("#FastConnectable = false\n")
    calls = []
    monkeypatch.setattr(ps4_wake, "run", lambda cmd, **kw: calls.append(cmd))

    ps4_wake.enable_bluetooth_fast_connectable(conf)

    assert len(calls) == 2
    assert all(c[0:2] == ["sudo", "sed"] for c in calls)


def test_apply_ps4_wake_fix_requires_bazzite(monkeypatch):
    from steamostools.platform_detect import UnsupportedPlatformError

    monkeypatch.setattr(ps4_wake, "require_platform", lambda *a, **kw: (_ for _ in ()).throw(
        UnsupportedPlatformError("nope")
    ))
    with pytest.raises(UnsupportedPlatformError):
        ps4_wake.apply_ps4_wake_fix()


def test_apply_ps4_wake_fix_runs_all_steps(monkeypatch, tmp_path):
    monkeypatch.setattr(ps4_wake, "require_platform", lambda *a, **kw: Platform.BAZZITE_OSTREE)
    monkeypatch.setattr(ps4_wake, "apply_kernel_args", lambda: ["pcie_port_pm=off"])
    monkeypatch.setattr(ps4_wake, "install_udev_rule", lambda: None)
    monkeypatch.setattr(ps4_wake, "disable_noisy_acpi_triggers", lambda: ["XHCI"])
    monkeypatch.setattr(ps4_wake, "enable_bluetooth_fast_connectable", lambda: None)

    result = ps4_wake.apply_ps4_wake_fix()

    assert result == {"added_kargs": ["pcie_port_pm=off"], "disabled_triggers": ["XHCI"]}
