from steamostools.tools import app_launcher


def test_slugify_replaces_spaces():
    assert app_launcher.slugify("My Cool Game") == "My-Cool-Game"


def test_render_desktop_file_fills_placeholders():
    content = app_launcher.render_desktop_file("Game", "A game", "/icon.png", "/usr/bin/game")
    assert "Name=Game" in content
    assert "GenericName=A game" in content
    assert "Icon=/icon.png" in content
    assert "Exec=/usr/bin/game" in content


def test_install_launcher_writes_file(tmp_path):
    dest = app_launcher.install_launcher(
        "My Game", "A game", "/icon.png", "/usr/bin/game", applications_dir=tmp_path
    )

    assert dest == tmp_path / "My-Game.desktop"
    assert dest.exists()
    assert "Name=My Game" in dest.read_text()
