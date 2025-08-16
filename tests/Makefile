# AI Pipeline Test Suite Makefile

.PHONY: all quick full clean setup help check-env

# Default namespace
NAMESPACE ?= argo-ai-demo

# Check if environment is properly set up
check-env:
	@if ! command -v oc >/dev/null 2>&1; then \
		echo ""; \
		echo "❌ ERROR: OpenShift CLI (oc) is not available!"; \
		echo ""; \
		echo "Please run the following commands from the project root:"; \
		echo ""; \
		echo "  cd .."; \
		echo "  source ./setup-env.sh"; \
		echo "  cd tests"; \
		echo ""; \
		echo "Then try running the tests again."; \
		echo ""; \
		exit 1; \
	fi
	@if ! oc whoami >/dev/null 2>&1; then \
		echo ""; \
		echo "❌ ERROR: Not logged into OpenShift!"; \
		echo ""; \
		echo "Please run the following commands from the project root:"; \
		echo ""; \
		echo "  cd .."; \
		echo "  source ./setup-env.sh"; \
		echo "  cd tests"; \
		echo ""; \
		echo "The setup script will log you in automatically."; \
		echo ""; \
		exit 1; \
	fi

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

check-env-detailed: ## Run detailed environment check
	@./check-environment.sh

all: check-env quick ## Run all tests (default: quick tests)

setup: check-env ## Deploy test resources
	@echo "Setting up test resources..."
	oc apply -f workflows/quick-test-job.yaml
	oc apply -f workflows/test-suite-template.yaml
	@echo "Test resources deployed"

quick: check-env ## Run quick connectivity tests
	@echo "Running quick tests..."
	@oc delete job ai-pipeline-quick-test -n $(NAMESPACE) --ignore-not-found=true
	@oc apply -f workflows/quick-test-job.yaml
	@echo "Waiting for job to complete..."
	@oc wait --for=condition=complete job/ai-pipeline-quick-test -n $(NAMESPACE) --timeout=60s
	@echo ""
	@echo "Test Results:"
	@echo "============="
	@oc logs job/ai-pipeline-quick-test -n $(NAMESPACE)

full: check-env ## Run full test suite with all document types
	@echo "Running full test suite..."
	@echo "Note: Since argo CLI is not installed, using alternative test method..."
	@./run-test-oc.sh

test-invoice: check-env ## Test invoice processing only
	@echo "Testing invoice processing..."
	@./run-single-test.sh invoice normal
	@./run-single-test.sh invoice urgent

test-contract: check-env ## Test contract processing only
	@echo "Testing contract processing..."
	@./run-single-test.sh contract normal
	@./run-single-test.sh contract urgent

test-techdoc: check-env ## Test technical doc processing only
	@echo "Testing technical documentation processing..."
	@./run-single-test.sh techdoc normal
	@./run-single-test.sh techdoc urgent

test-correspondence: check-env ## Test correspondence processing only
	@echo "Testing correspondence processing..."
	@./run-single-test.sh correspondence normal
	@./run-single-test.sh correspondence urgent

validate: check-env ## Validate test environment
	@echo "Validating test environment..."
	@echo -n "Checking namespace... "
	@oc get namespace $(NAMESPACE) > /dev/null && echo "✓" || echo "✗"
	@echo -n "Checking Argo... "
	@oc get deployment workflow-controller -n $(NAMESPACE) > /dev/null && echo "✓" || echo "✗"
	@echo -n "Checking Ollama... "
	@oc get deployment ollama -n $(NAMESPACE) > /dev/null && echo "✓" || echo "✗"
	@echo -n "Checking MinIO... "
	@oc get deployment minio -n $(NAMESPACE) > /dev/null && echo "✓" || echo "✗"

clean: check-env ## Clean up test resources
	@echo "Cleaning up test resources..."
	@oc delete job ai-pipeline-quick-test -n $(NAMESPACE) --ignore-not-found=true
	@oc delete workflows -l test=ai-pipeline -n $(NAMESPACE) --ignore-not-found=true
	@echo "Cleanup complete"

report: check-env ## Generate test report
	@echo "Generating test report..."
	@echo "AI Pipeline Test Report" > test-report.txt
	@echo "======================" >> test-report.txt
	@echo "Date: $$(date)" >> test-report.txt
	@echo "" >> test-report.txt
	@echo "Recent test workflows:" >> test-report.txt
	@oc get workflows -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp | tail -10 >> test-report.txt
	@echo "" >> test-report.txt
	@echo "Test report saved to test-report.txt"

watch: check-env ## Watch test workflow progress
	@watch -n 2 "oc get workflows -n $(NAMESPACE) --sort-by=.metadata.creationTimestamp | tail -10"
