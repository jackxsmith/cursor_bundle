# Top-level Makefile providing common targets

.PHONY: lint test release

lint:
	@echo "Running linters..."
	@shellcheck $(shell find . -type f -name '*.sh')

# Placeholder test target
 test:
	@echo "Running tests..."
	@echo "(no tests defined)"

release: lint test
	@echo "Running release build..."
	@bash scripts/build_release.sh
