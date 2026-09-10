from steamostools.tools import xboxdrv


def test_start_xboxdrv_unloads_xpad_then_starts_daemon(monkeypatch):
    calls = []
    monkeypatch.setattr(xboxdrv, "run", lambda cmd, **kw: calls.append((cmd, kw)))

    xboxdrv.start_xboxdrv()

    rmmod_call, rmmod_kwargs = calls[0]
    assert rmmod_call == ["sudo", "rmmod", "xpad"]
    assert rmmod_kwargs.get("check") is False

    daemon_call, _ = calls[1]
    assert daemon_call[0] == "xboxdrv"
    assert "--daemon" in daemon_call


def test_start_xboxdrv_appends_extra_args(monkeypatch):
    calls = []
    monkeypatch.setattr(xboxdrv, "run", lambda cmd, **kw: calls.append(cmd))

    xboxdrv.start_xboxdrv(extra_args=["--verbose"])

    assert calls[1][-1] == "--verbose"
