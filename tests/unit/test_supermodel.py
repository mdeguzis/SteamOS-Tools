import pytest

from steamostools.platform_detect import Platform
from steamostools.tools import supermodel


def test_supermodel_binary_for_chimeraos():
    assert supermodel.supermodel_binary_for(Platform.CHIMERAOS) == "/usr/bin/supermodel"


def test_supermodel_binary_for_other_platforms_uses_flatpak():
    assert supermodel.supermodel_binary_for(Platform.STEAMOS_ARCH) == (
        "/usr/bin/flatpak run com.supermodel3.Supermodel"
    )


def test_install_supermodel_uses_flatpak_on_steamos_arch(monkeypatch):
    calls = []
    monkeypatch.setattr(supermodel, "run", lambda cmd, **kw: calls.append(cmd))

    supermodel.install_supermodel(Platform.STEAMOS_ARCH)

    assert calls == [["flatpak", "install", "--user", "com.supermodel3.Supermodel", "-y"]]


def test_install_supermodel_builds_from_source_on_chimeraos(monkeypatch, tmp_path):
    src_dir = tmp_path / "supermodel"
    monkeypatch.setattr(supermodel, "SUPERMODEL_SRC_DIR", src_dir)
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        if cmd[0] == "make":
            (src_dir / "bin").mkdir(parents=True, exist_ok=True)
            (src_dir / "bin" / "supermodel").write_text("binary")

    monkeypatch.setattr(supermodel, "run", fake_run)

    supermodel.install_supermodel(Platform.CHIMERAOS)

    assert ["sudo", "frzr-unlock"] in calls
    assert any(c[0] == "git" and c[1] == "clone" for c in calls)
    assert any(c[0] == "make" for c in calls)
    assert any(c[:2] == ["sudo", "ln"] for c in calls)


def test_install_supermodel_pulls_existing_checkout(monkeypatch, tmp_path):
    src_dir = tmp_path / "supermodel"
    src_dir.mkdir(parents=True)
    monkeypatch.setattr(supermodel, "SUPERMODEL_SRC_DIR", src_dir)
    calls = []

    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        if cmd[0] == "make":
            (src_dir / "bin").mkdir(parents=True, exist_ok=True)
            (src_dir / "bin" / "supermodel").write_text("binary")

    monkeypatch.setattr(supermodel, "run", fake_run)

    supermodel.install_supermodel(Platform.CHIMERAOS)

    assert ["git", "-C", str(src_dir), "pull"] in calls
    assert not any(c[0] == "git" and c[1] == "clone" for c in calls)


def test_install_supermodel_raises_if_build_produces_no_binary(monkeypatch, tmp_path):
    src_dir = tmp_path / "supermodel"
    monkeypatch.setattr(supermodel, "SUPERMODEL_SRC_DIR", src_dir)
    monkeypatch.setattr(supermodel, "run", lambda cmd, **kw: None)

    with pytest.raises(supermodel.SupermodelInstallError):
        supermodel.install_supermodel(Platform.CHIMERAOS)


def test_get_device_resolution_parses_first_mode(tmp_path):
    drm_dir = tmp_path / "card0-DP-1"
    drm_dir.mkdir(parents=True)
    (drm_dir / "modes").write_text("1920x1080\n1280x720\n")

    assert supermodel.get_device_resolution(tmp_path) == "1920,1080"


def test_get_device_resolution_raises_when_no_modes(tmp_path):
    with pytest.raises(RuntimeError):
        supermodel.get_device_resolution(tmp_path)


def test_add_game_shortcut_raises_if_zip_missing(tmp_path):
    with pytest.raises(FileNotFoundError):
        supermodel.add_game_shortcut("Daytona 2", tmp_path / "missing.zip", device_res="800,1280")


def test_add_game_shortcut_renders_template(tmp_path):
    game_zip = tmp_path / "daytona2.zip"
    game_zip.write_text("fake rom")
    apps_dir = tmp_path / "applications"

    dest = supermodel.add_game_shortcut(
        "Daytona 2",
        game_zip,
        platform=Platform.STEAMOS_ARCH,
        device_res="800,1280",
        applications_dir=apps_dir,
        start_path=tmp_path / "supermodel",
    )

    assert dest == apps_dir / "supermodel-daytona2.desktop"
    content = dest.read_text()
    assert "Name=Daytona 2" in content
    assert str(game_zip) in content
    assert "800,1280" in content
    assert "flatpak run com.supermodel3.Supermodel" in content


def test_remove_game_shortcut_deletes_file(tmp_path):
    apps_dir = tmp_path / "applications"
    apps_dir.mkdir()
    game_zip = tmp_path / "daytona2.zip"
    (apps_dir / "supermodel-daytona2.desktop").write_text("x")

    supermodel.remove_game_shortcut(game_zip, applications_dir=apps_dir)

    assert not (apps_dir / "supermodel-daytona2.desktop").exists()


def test_remove_game_shortcut_is_noop_if_missing(tmp_path):
    apps_dir = tmp_path / "applications"
    apps_dir.mkdir()
    supermodel.remove_game_shortcut(tmp_path / "daytona2.zip", applications_dir=apps_dir)  # should not raise


def test_configure_input_rejects_invalid_profile(tmp_path):
    with pytest.raises(ValueError):
        supermodel.configure_input("bogus", target_dir=tmp_path)


def test_configure_input_writes_ini_for_each_profile(tmp_path):
    for profile in supermodel.INPUT_PROFILES:
        target_dir = tmp_path / profile
        supermodel.configure_input(profile, target_dir=target_dir)
        assert (target_dir / "Supermodel.ini").exists()
        assert (target_dir / "Supermodel.ini").stat().st_size > 0


def test_configure_input_seeds_nvram_when_source_given(tmp_path):
    target_dir = tmp_path / "Config"
    nvram_source = tmp_path / "nvram-src"
    nvram_source.mkdir()
    (nvram_source / "daytona2.nv").write_text("save data")

    supermodel.configure_input("sdl", target_dir=target_dir, nvram_source=nvram_source)

    assert (target_dir.parent / "NVRAM" / "daytona2.nv").exists()


def test_configure_input_skips_nvram_when_not_given(tmp_path):
    target_dir = tmp_path / "Config"
    supermodel.configure_input("sdl", target_dir=target_dir)
    assert not (target_dir.parent / "NVRAM").exists()
