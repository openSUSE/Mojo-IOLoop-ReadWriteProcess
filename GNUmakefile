# Variables
TEST_SHARED ?= 1
TEST_SUBREAPER ?= 1

.PHONY: help
help: ## Display this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

.PHONY: all
all: help

.PHONY: test
test: ## Run the entire test suite with prove
	TEST_SHARED=$(TEST_SHARED) TEST_SUBREAPER=$(TEST_SUBREAPER) prove -l t

.PHONY: test-verbose
test-verbose: ## Run the entire test suite with verbose output
	TEST_SHARED=$(TEST_SHARED) TEST_SUBREAPER=$(TEST_SUBREAPER) prove -lv t

.PHONY: tidy
tidy: ## Format code using perltidy (tools/tidy)
	./tools/tidy

.PHONY: check
check: ## Check code formatting without applying changes
	./tools/tidy --check
