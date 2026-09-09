"""Shared pytest fixtures.

Note: most steamostools functions take explicit path parameters (source_dir,
target_dir, steam_root, etc.) with a Path.home()-derived module constant only
as the *default* value. Tests should pass tmp_path-based paths explicitly
rather than trying to patch Path.home() globally -- module-level constants
are computed once at import time, so patching Path.home() afterwards would
not affect them. Where a test needs to override one of those defaults, it
monkeypatches the specific module attribute instead (see individual tests).
"""
