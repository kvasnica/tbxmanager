MATLAB ?= /Applications/MATLAB_R2025b.app/bin/matlab

.PHONY: help install dev docs docs-build lint validate migrate test test-matlab test-matlab-verbose matlab-repl clean

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

install: ## Install dependencies
	uv sync

dev: ## Install dev dependencies
	uv sync --group dev

matlab-cli: ## Open interactive MATLAB CLI with tbxmanager on path
	$(MATLAB) -nodesktop -nosplash -r "addpath(genpath('.')); disp('tbxmanager ready. Try: tbxmanager help');"

# ── Docs ──────────────────────────────────────────────

docs: ## Serve docs locally (http://127.0.0.1:8000)
	uv run mkdocs serve

docs-build: ## Build docs to site/
	cp tbxmanager.m docs/tbxmanager.m
	uv run mkdocs build --strict
	rm -f docs/tbxmanager.m

# ── Lint & Validate ───────────────────────────────────

lint: ## Lint Python scripts
	uv run python -m py_compile scripts/migrate_registry.py
	uv run python -m py_compile scripts/build_index.py
	uv run python -m py_compile scripts/validate_package.py
	uv run python -m py_compile scripts/build_packages_data.py
	@echo "All Python scripts OK"

validate: ## Validate JSON fixtures against schemas
	uv run check-jsonschema --schemafile scripts/schemas/tbxmanager-package.schema.json tests/fixtures/valid_package.json
	uv run check-jsonschema --schemafile scripts/schemas/registry-package.schema.json tests/fixtures/valid_registry_entry.json
	uv run check-jsonschema --schemafile scripts/schemas/lockfile.schema.json tests/fixtures/valid_lockfile.json
	@echo "All schemas OK"

# ── Migration ─────────────────────────────────────────

migrate: ## Run migration from SQLite (dry-run)
	uv run python scripts/migrate_registry.py --db tbxmanager/databases/storage.sqlite --output /tmp/tbx-migration --dry-run

migrate-run: ## Run migration for real → output/
	uv run python scripts/migrate_registry.py --db tbxmanager/databases/storage.sqlite --output output

# ── Index ─────────────────────────────────────────────

index: ## Build index.json from packages/ (run migrate-run first)
	@test -d output/packages || (echo "Error: run 'make migrate-run' first" && exit 1)
	uv run python scripts/build_index.py --packages-dir output/packages --output output/index.json

# ── Test ──────────────────────────────────────────────

test: lint validate ## Run non-MATLAB checks (lint + validate)
	@echo "All checks passed"

test-matlab: ## Run MATLAB tests locally
	$(MATLAB) -batch "addpath(genpath('.')); run_tests;"

test-matlab-verbose: ## Run MATLAB tests with verbose output
	$(MATLAB) -batch "addpath(genpath('.')); run_tests('-v');"

test-matlab-single: ## Run a single test class: make test-matlab-single CLASS=TestVersionConstraints
	$(MATLAB) -batch "addpath(genpath('.')); run_tests('$(CLASS)');"

test-matlab-debug: ## Dump sources.json bytes for debugging install tests
	$(MATLAB) -batch "setenv('TBXMANAGER_HOME', fullfile(tempdir,'tbx_debug')); tbxmanager help; sf=fullfile(getenv('TBXMANAGER_HOME'),'state','sources.json'); raw=fileread(sf); fprintf('len=%d bytes: ',numel(raw)); fprintf('%d ',uint8(raw(1:min(80,numel(raw))))); fprintf('\ncontent: >>%s<<\n',raw); jsondecode(raw); disp('jsondecode OK'); rmdir(fullfile(tempdir,'tbx_debug'),'s');"

test-all: test test-matlab ## Run everything (lint + validate + MATLAB)

# ── Clean ─────────────────────────────────────────────

clean: ## Remove build artifacts
	rm -rf site/ output/ /tmp/tbx-migration
	rm -f docs/tbxmanager.m
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
