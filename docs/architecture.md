# PerturbScope-GPT — Architecture

## Overview

PerturbScope-GPT is a local-first single-cell perturbation modeling MVP.
Given a control expression profile and a perturbation gene label, the system
predicts **delta expression** across highly variable genes, evaluates the
result on seen and unseen perturbations, and exposes the artifacts in a
Streamlit demo.

The project now has two explicit operating modes:

- `real_norman2019`: the main path for reportable biological results
- `synthetic_fallback`: an offline demo path for UI and pipeline validation

```text
raw .h5ad or synthetic generator
  -> preprocessing
  -> processed bundle
  -> train / evaluate
  -> artifacts + figures
  -> Streamlit app + demo tooling
```

## Operating Modes

### 1. Real Norman2019 mode

Primary data path:

- raw file: `data/raw/NormanWeissman2019_filtered.h5ad`
- processed bundle: `data/processed/norman2019_demo_bundle`
- default Transformer artifacts: `artifacts/transformer_seen_norman2019_demo`

This is the only mode whose metrics should be cited as real biological results.

### 2. Synthetic fallback mode

Offline demo path:

- processed bundle: `data/processed/synthetic_demo_bundle`
- default Transformer artifacts: `artifacts/transformer_seen_synthetic_demo`

This path exists for offline demos, smoke tests, and product validation. Its
metrics must not be mixed with real Norman2019 results.

### 3. Streamlit selection behavior

`app/streamlit_app.py` resolves demo paths in this order:

1. real bundle / artifact if present
2. synthetic bundle / artifact if real assets are missing

The UI must continue to surface whether the current session is using real or
synthetic artifacts.

## Data Flow

### 1. Input data

The main dataset is `NormanWeissman2019_filtered.h5ad` from the `scPerturb`
benchmark, restricted to the K562 single-gene perturbation MVP path.

Schema resolution is automatic and controlled by `configs/data.yaml` plus
`src/data/schema.py`. The preprocessing pipeline resolves:

- perturbation column
- control label
- batch column
- context columns
- multi-gene label canonicalization

### 2. Preprocessing

Implemented in `src/data/preprocess.py` and orchestrated by
`scripts/preprocess_data.py`.

Current default steps:

| Step | Default |
| --- | --- |
| Filter cells | `min_genes_per_cell = 200` |
| Filter genes | `min_cells_per_gene = 3` |
| Normalize | `normalize_total(target_sum=10000)` |
| Log transform | `log1p` |
| HVG selection | top `512` genes |
| Local-first cap | `max_cells_per_perturbation = 500` |
| Sparse policy | keep sparse until post-HVG export |

### 3. Pairing and target construction

Implemented in `src/data/pairing.py`.

The MVP target is fixed to:

```text
delta_expression = perturbed_expression - matched_control_mean
```

Control means are resolved in this order:

1. batch-aware control mean
2. global control mean within cell context

### 4. Split protocols

The processed bundle always exports both split families:

- `seen_*`: stratified within perturbation condition
- `unseen_*`: grouped by perturbation identity

This keeps fast in-condition validation and held-out perturbation
generalization in the same bundle contract.

## Processed Bundle Contract

`src/data/pairing.py` writes a standard processed bundle directory:

### `arrays.npz`

- `control_expression`
- `target_delta`
- `perturbation_index`
- `sample_ids`

### `splits.npz`

- `seen_train`
- `seen_val`
- `seen_test`
- `unseen_train`
- `unseen_val`
- `unseen_test`

### `metadata.json`

- `gene_names`
- `perturbation_names`

This contract is consumed by `src/data/torch_dataset.py`,
`scripts/train_transformer.py`, `scripts/train_baselines.py`,
`scripts/evaluate_model.py`, and the Streamlit app.

## Model Layer

### Transformer

File: `src/models/transformer.py`

Default architecture:

```text
gene_embedding
+ scalar value projection(control_expression_i)
+ perturbation_embedding
-> Transformer encoder
-> per-gene regression head
-> predicted delta expression
```

Default hyperparameters from `configs/model.yaml`:

| Parameter | Value |
| --- | --- |
| `d_model` | 128 |
| `n_heads` | 4 |
| `n_layers` | 2 |
| `ffn_dim` | 256 |
| `dropout` | 0.1 |
| `hvg_count` | 512 |

Stable design decisions:

- no positional encoding
- additive perturbation injection to all gene tokens
- standard self-attention only
- delta-expression regression target

### Baselines

Files:

- `src/models/mlp.py`
- `src/models/xgboost_baseline.py`

These provide lower-complexity reference points for quality comparisons and
demo narratives. They are part of the MVP, not optional extras.

## Training and Evaluation

### Training

Core training loop: `src/training/trainer.py`

Key defaults from `configs/train.yaml`:

- batch size: `16`
- epochs: `20`
- learning rate: `1e-3`
- checkpoint metric: `pearson_per_perturbation`
- seed: `42`

### Metrics

Core metrics in `src/evaluation/metrics.py`:

- Pearson correlation
- MSE
- Top-k DEG overlap

Primary reporting granularity:

- `per-perturbation`

Secondary reporting:

- `per-gene`

### DEG logic

Implemented in `src/evaluation/deg.py`.

Current default:

- `scanpy.tl.rank_genes_groups`
- method: `wilcoxon`
- adjusted p-value threshold: `< 0.05`
- absolute log fold change threshold: `> 0.25`

### Error analysis

Implemented in `src/evaluation/error_analysis.py`.

Saved diagnostics include:

- per-perturbation error CSVs
- split-level error summaries
- heuristic failure-mode labels

These artifacts are for debugging and demo explanation. They are not new model
targets and should not be framed as causal biological claims.

## Artifact Contract

### Per-run model artifacts

A standard training/evaluation directory may include:

- `best_model.pt`
- `history.json`
- `seen_test_metrics.json`
- `unseen_test_metrics.json`
- `seen_test_per_perturbation.csv`
- `unseen_test_per_perturbation.csv`
- `seen_test_error_summary.json`
- `unseen_test_error_summary.json`
- `run_summary.json`
- `deg_artifact.csv`
- `deg_artifact_metadata.json`

### Cross-run and delivery artifacts

Project-level delivery files include:

- `artifacts/multi_seed_report.json`
- `artifacts/project_snapshot.json`
- `docs/assets/model_comparison_seen_norman2019_demo.png`
- `docs/assets/transformer_inference_preview.png`
- `docs/assets/transformer_error_analysis_preview.png`
- `docs/assets/model_comparison_seen_synthetic_demo.png`
- `docs/assets/transformer_inference_preview_synthetic_demo.png`

These are consumed by:

- `src/utils/project_health.py`
- `src/utils/project_snapshot.py`
- `src/utils/showcase.py`
- `src/utils/interview_script.py`
- `app/streamlit_app.py`

## Ranking

Implemented in `src/ranking/target_ranking.py`.

The MVP ranking formula is intentionally simple and explicit:

```text
importance_score =
  0.5 * normalized_abs_predicted_delta
+ 0.5 * normalized_deg_significance
```

Attention weights are not used as formal ranking features.

## Repository Layout

```text
src/
  data/         loading, schema resolution, preprocessing, pairing, datasets
  models/       Transformer, MLP, XGBoost
  training/     losses and training loop
  evaluation/   metrics, inference helpers, DEG logic, error analysis
  ranking/      target prioritization
  utils/        config, logging, seeds, snapshot/showcase/demo helpers

scripts/        thin CLI entrypoints
configs/        YAML runtime configuration
app/            Streamlit UI only
docs/           architecture, dataset notes, generated figures
tests/          unit and integration tests
```

## Delivery Layer

The repo now includes an explicit demo/readiness layer in addition to the core
ML pipeline:

- `run_doctor.sh`: local project health and readiness checks
- `run_snapshot.sh`: interview-friendly project snapshot
- `run_showcase.sh`: live demo preparation
- `run_pitch.sh`: speaking-script generation

This is a deliberate part of the architecture. The project is meant to be
job-ready and demo-ready, not just trainable.
