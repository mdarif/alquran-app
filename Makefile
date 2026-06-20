# Al Quran — developer task runner. Run `make help` to list targets.
.DEFAULT_GOAL := help
.PHONY: help setup get gen watch analyze format format-check test coverage run clean ci hooks

help: ## List available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

setup: get gen hooks ## One-command onboarding (deps + codegen + git hooks)

get: ## Fetch pub dependencies
	flutter pub get

gen: ## Run Drift/build_runner code generation
	dart run build_runner build --delete-conflicting-outputs

watch: ## Watch & regenerate code on change
	dart run build_runner watch --delete-conflicting-outputs

analyze: ## Static analysis (warnings are fatal, as in CI)
	flutter analyze --fatal-warnings

format: ## Format all Dart sources
	dart format lib test

format-check: ## Verify formatting without writing (CI gate)
	dart format --output=none --set-exit-if-changed lib test

test: ## Run unit + widget tests
	flutter test

coverage: ## Run tests with coverage and print the lcov path
	flutter test --coverage
	@echo "coverage written to coverage/lcov.info"

run: ## Run the app (pick a device when prompted)
	flutter run

clean: ## Remove build artifacts
	flutter clean

ci: format-check analyze test ## Mirror the CI pipeline locally

hooks: ## Install the repo git hooks (pre-push runs the CI gate)
	git config core.hooksPath .githooks
	@echo "git hooks installed (core.hooksPath = .githooks)"
