# Development Guide

## Prerequisites

- [uv](https://astral.sh/uv) -- used for all dependency management and running commands
- Python 3.10+

## Setup

```bash
./dev-setup.sh
```

This creates `.venv` and installs the package in editable mode with dev
dependencies (pytest, pytest-cov, responses).

### Manual setup (alternative)

```bash
uv sync --group dev
```

## Running

**Option A -- activate the venv:**
```bash
source .venv/bin/activate
steamos-tools --help
```

**Option B -- run without activating:**
```bash
uv run steamos-tools --help
```

## Testing

```bash
uv run pytest tests/ -v --cov=steamostools --cov-report=term-missing
```

- `tests/unit/` -- pure logic, mocked subprocess/network boundaries, no
  real system state touched.
- `tests/integration/` -- exercises real subprocess/argparse wiring, either
  against fake binaries placed on `PATH` (rclone, systemctl) or a real HTTP
  mock (`responses`) for the full download+extract flow. Nothing here
  requires an actual Steam Deck, SteamOS, or network access.

Some behavior (actually unlocking a read-only SteamOS rootfs, syncing to a
real rclone remote, Steam picking up an installed compat tool) can only be
verified on real hardware -- see the manual testing checklist on the
tracking issue for each conversion batch.

## Adding a new tool

Each tool lives under `steamostools/tools/<name>.py` and exposes:

- Plain functions/classes containing the actual logic (testable in isolation,
  no argparse coupling).
- `register_subparser(subparsers)` -- adds the tool's subcommand(s) and
  wires `set_defaults(func=...)` to a thin `_cmd_*` handler per subcommand.

Register the new module in `steamostools/cli.py`'s `_TOOL_MODULES` tuple.

Reuse the shared libraries before writing new plumbing:

- `steamostools.logging_utils.initialize_logger` -- every subcommand gets
  `-v/--verbose` and `-D/--debug` for free via `cli.py`; don't roll your own.
- `steamostools.process.run` / `require_root` -- subprocess calls and
  privilege checks. Never swallow a failed command into `None`/`[]`; let it
  raise (see the no-silent-failures convention below).
- `steamostools.platform_detect` -- assert `STEAMOS_ARCH` / `BAZZITE_OSTREE`
  / `CHIMERAOS` up front instead of failing deep inside a package-manager call.
- `steamostools.github_releases.GitHubReleaseClient` -- latest-release /
  pick-asset-by-pattern / download, for anything installing from GitHub Releases.
- `steamostools.systemd_units.SystemdUserUnit` / `steamostools.rclone_sync.RcloneSync`
  -- systemd --user lifecycle and rclone remote sync.
- `steamostools.vdf.textvdf` -- brace-delimited KeyValues (config.vdf-style)
  parsing.

## Conventions

- A failed network/subprocess/parse call raises; it never returns an empty
  value as a stand-in for failure. An empty result (`[]`, `{}`) means the
  operation genuinely succeeded and found nothing.
- New tools ship with tests in the same change: unit tests for the logic,
  plus a `register_subparser` entry covered by the CLI smoke test in
  `tests/integration/test_cli_smoke.py`.
