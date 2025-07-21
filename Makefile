.PHONY: lint test security release

lint:
	@echo "Running linters..."
	# Add lint commands (shellcheck, ruff, etc.) here

test:
	bash scripts/run_tests.sh

security:
	@echo "Running security scans..."
	# Add security scanning commands here

release:
	bash scripts/build_release.sh

static-analysis:
	bash scripts/static_analysis.sh

dynamic-scan:
	bash scripts/dynamic_security_scan.sh

mutation-test:
	bash scripts/mutation_test.sh

coverage-report:
	bash scripts/generate_coverage.sh

sign-artifacts:
	bash scripts/sign_artifacts.sh

generate-sbom:
	bash scripts/generate_sbom.sh
