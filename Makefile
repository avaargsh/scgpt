# PerturbScope-GPT — development shortcuts
# All targets run through uv so the virtual environment is handled automatically.

.PHONY: help test lint typecheck format ci doctor snapshot pitch showcase demo notebooks \
       results synthetic validate-artifacts clean

UV := UV_PROJECT_ENVIRONMENT=.venv UV_CACHE_DIR=.uv-cache uv run
PYTHON := $(UV) python

help:  ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

# ── Quality ──────────────────────────────────────────────────────────────────

test:  ## Run the full pytest suite
	$(UV) pytest tests/ -v

lint:  ## Run ruff linter (auto-fix safe issues)
	$(UV) ruff check src/ scripts/ app/ tests/ --fix

format:  ## Run ruff formatter
	$(UV) ruff format src/ scripts/ app/ tests/

typecheck:  ## Run mypy static type checker on src/
	$(UV) mypy src/

ci:  ## Run full local CI check (test + lint + typecheck)
	@echo "=== tests ===" && $(UV) pytest tests/ -v \
		&& echo "=== lint ===" && $(UV) ruff check src/ scripts/ app/ tests/ \
		&& echo "=== typecheck ===" && $(UV) mypy src/ \
		&& echo "=== CI passed ==="

# ── Demo & data ───────────────────────────────────────────────────────────────
doctor:  ## Inspect local project/demo readiness
	./scripts/run_doctor.sh
snapshot:  ## Print an interview-friendly project snapshot
	./scripts/run_snapshot.sh
pitch:  ## Export an interview/demo speaking script
	./scripts/run_pitch.sh
showcase:  ## Prepare and print the recommended live demo flow
	./scripts/run_showcase.sh

demo:  ## Launch the Streamlit app
	./scripts/run_app.sh

notebooks:  ## Launch JupyterLab with the project notebooks
	$(UV) jupyter lab notebooks/

# ── Pipeline (Norman2019) ─────────────────────────────────────────────────────

preprocess:  ## Preprocess the Norman2019 dataset into a bundle
	./scripts/run_norman2019_demo.sh

train-transformer:  ## Train the Transformer on the Norman2019 bundle
	./scripts/run_train_transformer.sh \
		--bundle-dir data/processed/norman2019_demo_bundle \
		--output-dir artifacts/transformer_seen_norman2019_demo

train-mlp:  ## Train the MLP baseline on the Norman2019 bundle
	./scripts/run_train_baselines.sh \
		--bundle-dir data/processed/norman2019_demo_bundle \
		--output-dir artifacts/mlp_seen_norman2019_demo \
		--baseline mlp

train-xgboost:  ## Train the XGBoost baseline on the Norman2019 bundle
	./scripts/run_train_baselines.sh \
		--bundle-dir data/processed/norman2019_demo_bundle \
		--output-dir artifacts/xgboost_seen_norman2019_demo \
		--baseline xgboost

eval:  ## Evaluate all trained models (requires trained artifacts)
	./scripts/run_full_evaluation.sh

deg:  ## Generate DEG artifact from the Norman2019 dataset
	./scripts/run_generate_deg_artifact.sh \
		--input-path data/raw/NormanWeissman2019_filtered.h5ad \
		--bundle-dir data/processed/norman2019_demo_bundle \
		--output-dir artifacts/transformer_seen_norman2019_demo

results:  ## Regenerate real Norman2019 result figures for README/docs
	./scripts/run_generate_results_assets.sh

synthetic:  ## Generate full offline synthetic showcase (all 3 models + figures)
	./scripts/run_generate_synthetic_showcase.sh

validate-artifacts:  ## Check that expected demo artifacts exist
	@echo "=== Validating demo artifacts ===" && \
	ok=true && \
	for f in \
	  data/processed/norman2019_demo_bundle/arrays.npz \
	  data/processed/norman2019_demo_bundle/splits.npz \
	  data/processed/norman2019_demo_bundle/metadata.json \
	  artifacts/transformer_seen_norman2019_demo/best_model.pt \
	  artifacts/transformer_seen_norman2019_demo/run_summary.json \
	  artifacts/transformer_seen_norman2019_demo/seen_test_metrics.json \
	  artifacts/transformer_seen_norman2019_demo/unseen_test_metrics.json \
	  artifacts/mlp_seen_norman2019_demo/best_model.pt \
	  artifacts/xgboost_seen_norman2019_demo/xgboost_run_summary.json \
	; do \
	  if [ -f "$$f" ]; then \
	    printf "  \033[32m[OK]\033[0m %s\n" "$$f"; \
	  else \
	    printf "  \033[31m[MISSING]\033[0m %s\n" "$$f"; ok=false; \
	  fi; \
	done && \
	if $$ok; then echo "=== All artifacts present ==="; else echo "=== Some artifacts missing ==="; fi

# ── Housekeeping ──────────────────────────────────────────────────────────────

clean:  ## Remove pytest cache and compiled Python files
	find . -type d -name __pycache__ -not -path './.venv/*' | xargs rm -rf
	find . -type d -name .pytest_cache -not -path './.venv/*' | xargs rm -rf
	find . -name '*.pyc' -not -path './.venv/*' | xargs rm -f
