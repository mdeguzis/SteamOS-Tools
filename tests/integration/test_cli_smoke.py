"""End-to-end CLI smoke tests: every registered subcommand's --help must
resolve via the real argparse tree wired up in cli.py, exercised the same
way a user invokes it (`python -m steamostools ...`)."""

import subprocess
import sys

import pytest

TOP_LEVEL_GROUPS = ["proton", "screenshots", "rom", "unlock", "shader"]


def _run_help(*args):
    return subprocess.run(
        [sys.executable, "-m", "steamostools", *args, "--help"],
        capture_output=True,
        text=True,
    )


def test_top_level_help():
    result = _run_help()
    assert result.returncode == 0
    for group in TOP_LEVEL_GROUPS:
        assert group in result.stdout


@pytest.mark.parametrize("group", TOP_LEVEL_GROUPS)
def test_group_help_resolves(group):
    result = _run_help(group)
    assert result.returncode == 0, result.stderr


def test_unknown_command_exits_nonzero():
    result = subprocess.run(
        [sys.executable, "-m", "steamostools", "not-a-real-command"],
        capture_output=True,
        text=True,
    )
    assert result.returncode != 0
