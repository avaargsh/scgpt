from __future__ import annotations

from pathlib import Path
from typing import Any

import pandas as pd

REAL_ERROR_ANALYSIS_PREVIEW = "transformer_error_analysis_preview.png"
SYNTHETIC_ERROR_ANALYSIS_PREVIEW = "transformer_error_analysis_preview_synthetic_demo.png"


def resolve_error_analysis_preview_path(
    project_root: str | Path = ".",
    *,
    demo_mode: str,
    artifact_dir: str | Path | None = None,
) -> Path | None:
    """Resolve the saved error-analysis preview figure for the active demo mode."""
    root = Path(project_root).resolve()
    preview_name = (
        SYNTHETIC_ERROR_ANALYSIS_PREVIEW
        if demo_mode == "synthetic"
        else REAL_ERROR_ANALYSIS_PREVIEW
    )
    candidates: list[Path] = []

    if artifact_dir is not None:
        artifact_root = Path(artifact_dir)
        if not artifact_root.is_absolute():
            artifact_root = root / artifact_root
        candidates.append(artifact_root / preview_name)

    candidates.append(root / "docs" / "assets" / preview_name)

    for candidate in candidates:
        if candidate.exists():
            return candidate
    return None


def available_diagnostic_splits(
    *,
    seen_error_summary: dict[str, Any],
    unseen_error_summary: dict[str, Any],
) -> list[str]:
    """List the saved split diagnostics that are currently available."""
    options: list[str] = []
    if seen_error_summary:
        options.append("seen_test")
    if unseen_error_summary:
        options.append("unseen_test")
    return options


def resolve_active_diagnostic_split(
    requested_split: str | None,
    *,
    seen_error_summary: dict[str, Any],
    unseen_error_summary: dict[str, Any],
) -> str | None:
    """Pick a saved split to display, preferring the requested split when available."""
    options = available_diagnostic_splits(
        seen_error_summary=seen_error_summary,
        unseen_error_summary=unseen_error_summary,
    )
    if not options:
        return None
    if requested_split in options:
        return requested_split
    if "unseen_test" in options:
        return "unseen_test"
    return options[0]


def get_split_diagnostic_artifacts(
    split_name: str | None,
    *,
    seen_error_summary: dict[str, Any],
    unseen_error_summary: dict[str, Any],
    seen_error_table: pd.DataFrame,
    unseen_error_table: pd.DataFrame,
) -> tuple[dict[str, Any], pd.DataFrame]:
    """Return the saved summary/table pair for the requested diagnostic split."""
    if split_name == "seen_test":
        return seen_error_summary, seen_error_table
    if split_name == "unseen_test":
        return unseen_error_summary, unseen_error_table
    return {}, pd.DataFrame()
