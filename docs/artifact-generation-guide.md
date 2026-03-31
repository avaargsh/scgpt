# Artifact Generation Guide

This document describes the recommended order for generating all project
artifacts, the dependencies between scripts, and how to recover from
partial runs.

## Dependency Graph

```text
bootstrap_env.sh
  |
  v
download_norman2019.sh -------> run_generate_synthetic_demo.sh
  |                                |
  v                                v
run_norman2019_demo.sh       synthetic_demo_bundle + transformer artifacts
  |                                |
  v                                v
norman2019_demo_bundle       run_generate_synthetic_showcase.sh
  |                            (adds MLP, XGBoost, figures)
  |
  +---> run_train_transformer.sh ---> transformer artifacts
  |
  +---> run_train_baselines.sh (mlp) ---> MLP artifacts
  |
  +---> run_train_baselines.sh (xgboost) ---> XGBoost artifacts
  |
  +---> run_generate_deg_artifact.sh ---> deg_artifact.csv
  |        (requires raw h5ad + bundle)
  |
  v
run_full_evaluation.sh
  (requires trained checkpoints + bundle)
  |
  v
run_summarize_run.sh (per model)
  |
  v
run_multi_seed_report.sh (optional, requires multiple seed runs)
  |
  v
run_generate_results_assets.sh
  (requires trained artifacts + bundle)
  |
  v
run_doctor.sh / run_snapshot.sh / run_showcase.sh / run_pitch.sh
  |
  v
run_app.sh
```

## Real Norman2019 — Full Sequence

Prerequisites: `uv` installed, internet access for dataset download.

```bash
# 0. Bootstrap environment
./scripts/bootstrap_env.sh && source .venv/bin/activate

# 1. Download raw data (~200 MB)
./scripts/download_norman2019.sh

# 2. Preprocess into bundle (inspect schema + build bundle)
./scripts/run_norman2019_demo.sh
#    Produces: data/processed/norman2019_demo_bundle/

# 3. Train models (independent — can run in any order)
./scripts/run_train_transformer.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/transformer_seen_norman2019_demo

./scripts/run_train_baselines.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/mlp_seen_norman2019_demo \
  --baseline mlp

./scripts/run_train_baselines.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/xgboost_seen_norman2019_demo \
  --baseline xgboost

# 4. Generate DEG artifact (requires raw h5ad + bundle)
./scripts/run_generate_deg_artifact.sh \
  --input-path data/raw/NormanWeissman2019_filtered.h5ad \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/transformer_seen_norman2019_demo

# 5. Evaluate all models (uses trained checkpoints)
./scripts/run_full_evaluation.sh

# 6. Write run summaries
./scripts/run_summarize_run.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/transformer_seen_norman2019_demo \
  --checkpoint-path artifacts/transformer_seen_norman2019_demo/best_model.pt \
  --model-type transformer --split-prefix seen \
  --seen-metrics-path artifacts/transformer_seen_norman2019_demo/seen_test_metrics.json \
  --unseen-metrics-path artifacts/transformer_seen_norman2019_demo/unseen_test_metrics.json

# 7. Generate result figures for README / docs
./scripts/run_generate_results_assets.sh

# 8. Verify project health
./scripts/run_doctor.sh

# 9. Launch the app
./scripts/run_app.sh
```

## Synthetic Offline — Full Sequence

No dataset download or internet access required.

```bash
# 0. Bootstrap environment
./scripts/bootstrap_env.sh && source .venv/bin/activate

# 1. Generate full synthetic showcase (all three models + figures)
./scripts/run_generate_synthetic_showcase.sh
#    Produces:
#      data/processed/synthetic_demo_bundle/
#      artifacts/transformer_seen_synthetic_demo/
#      artifacts/mlp_seen_synthetic_demo/
#      artifacts/xgboost_seen_synthetic_demo/
#      docs/assets/model_comparison_seen_synthetic_demo.png
#      docs/assets/transformer_inference_preview_synthetic_demo.png

# 2. Launch the app (auto-detects synthetic artifacts)
./scripts/run_app.sh
```

## Multi-Seed Runs (Optional)

After training the default seed, add extra seeds to measure stability:

```bash
# Train with additional seeds
./scripts/run_train_transformer.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/transformer_seen_norman2019_seed7 \
  --seed 7

./scripts/run_train_transformer.sh \
  --bundle-dir data/processed/norman2019_demo_bundle \
  --output-dir artifacts/transformer_seen_norman2019_seed21 \
  --seed 21

# Summarize each seed run, then aggregate
./scripts/run_multi_seed_report.sh --artifact-root artifacts --json \
  --output-path artifacts/multi_seed_report.json
```

## Which Steps Can Be Skipped?

| Situation | Safe to skip |
| --- | --- |
| Only need the app demo | Steps 5-7 (evaluate/summarize/figures) — the app works with just the trained checkpoint |
| No DEG analysis needed | Step 4 (DEG artifact) — ranking falls back to prediction-only mode |
| Only need one model | Skip the other two baseline training commands in step 3 |
| Synthetic demo only | Skip steps 1-7 entirely — use `run_generate_synthetic_showcase.sh` |
| Already have trained artifacts | Resume from step 5 (evaluation) onward |

## Common Recovery Scenarios

**Bundle generation fails mid-run:**
Delete the partial output and re-run step 2.
```bash
rm -rf data/processed/norman2019_demo_bundle
./scripts/run_norman2019_demo.sh
```

**Training interrupted:**
Training writes `best_model.pt` at each best checkpoint, so a partial run
may already have a usable model. Check for `best_model.pt` before re-running.

**Evaluation reports missing models:**
`run_full_evaluation.sh` prints `[SKIP]` for any model whose checkpoint is
absent. Train the missing model and re-run evaluation.

**Figures look outdated:**
Re-run `./scripts/run_generate_results_assets.sh` after any new training or
evaluation run.
