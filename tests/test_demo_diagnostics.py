from __future__ import annotations

from pathlib import Path

import pandas as pd

from src.utils.demo_diagnostics import (
    available_diagnostic_splits,
    get_split_diagnostic_artifacts,
    resolve_active_diagnostic_split,
    resolve_error_analysis_preview_path,
)


def test_resolve_error_analysis_preview_path_prefers_docs_asset(tmp_path: Path) -> None:
    asset_path = tmp_path / "docs/assets/transformer_error_analysis_preview.png"
    asset_path.parent.mkdir(parents=True, exist_ok=True)
    asset_path.write_text("placeholder", encoding="utf-8")

    resolved = resolve_error_analysis_preview_path(tmp_path, demo_mode="real")

    assert resolved == asset_path


def test_resolve_error_analysis_preview_path_returns_none_when_missing(tmp_path: Path) -> None:
    resolved = resolve_error_analysis_preview_path(tmp_path, demo_mode="synthetic")

    assert resolved is None


def test_available_and_active_diagnostic_split_prefer_unseen_when_present() -> None:
    seen_summary = {"split_name": "seen_test"}
    unseen_summary = {"split_name": "unseen_test"}

    assert available_diagnostic_splits(
        seen_error_summary=seen_summary,
        unseen_error_summary=unseen_summary,
    ) == ["seen_test", "unseen_test"]
    assert (
        resolve_active_diagnostic_split(
            None,
            seen_error_summary=seen_summary,
            unseen_error_summary=unseen_summary,
        )
        == "unseen_test"
    )


def test_get_split_diagnostic_artifacts_returns_matching_pair() -> None:
    seen_summary = {"split_name": "seen_test"}
    unseen_summary = {"split_name": "unseen_test"}
    seen_table = pd.DataFrame([{"perturbation": "CEBPA"}])
    unseen_table = pd.DataFrame([{"perturbation": "FOXO4"}])

    summary, table = get_split_diagnostic_artifacts(
        "seen_test",
        seen_error_summary=seen_summary,
        unseen_error_summary=unseen_summary,
        seen_error_table=seen_table,
        unseen_error_table=unseen_table,
    )

    assert summary == seen_summary
    assert list(table["perturbation"]) == ["CEBPA"]
