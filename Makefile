# AI Document Processing Pipeline - Main Makefile
# Helm-based deployment for complete pipeline including dashboard

#=============================================================================
# CONFIGURATION
#=============================================================================
PROJECT_NAME := ai-document-pipeline
HELM_CHART := helm/ai-document-pipeline
HELM_RELEASE_DEV := ai-pipeline-dev
HELM_RELEASE_PROD := ai-pipeline-prod

# Namespaces
DEV_NAMESPACE := argo-ai-dev
PROD_NAMESPACE := argo-ai-prod

# Git versioning
GIT_VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "latest")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')

# Tools
HELM := $(shell which helm 2>/dev/null || echo "helm")
# Check for kubectl, then oc in PATH, then CRC's oc
KUBECTL := $(shell if which kubectl >/dev/null 2>&1; then echo kubectl; elif which oc >/dev/null 2>&1; then echo oc; elif test -x /Users/aasmith/.crc/bin/oc/oc; then echo /Users/aasmith/.crc/bin/oc/oc; else echo kubectl; fi)

# Colors
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
NC := \033[0m

#=============================================================================
# DEFAULT HELP
#=============================================================================
.PHONY: help
help:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║        AI Document Processing Pipeline - Deployment           ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)DEVELOPMENT COMMANDS:$(NC)"
	@echo "  $(YELLOW)make dev-deploy$(NC)         Deploy complete pipeline to dev"
	@echo "  $(YELLOW)make dev-upgrade$(NC)        Upgrade dev deployment"
	@echo "  $(YELLOW)make dev-remove$(NC)         Remove dev deployment"
	@echo "  $(YELLOW)make dev-status$(NC)         Show dev deployment status"
	@echo ""
	@echo "$(PURPLE)PRODUCTION COMMANDS:$(NC)"
	@echo "  $(YELLOW)make prod-deploy$(NC)        Deploy complete pipeline to prod"
	@echo "  $(YELLOW)make prod-upgrade$(NC)       Upgrade prod deployment"
	@echo "  $(YELLOW)make prod-remove$(NC)        Remove prod deployment (confirms)"
	@echo "  $(YELLOW)make prod-status$(NC)        Show prod deployment status"
	@echo ""
	@echo "$(BLUE)HELM COMMANDS:$(NC)"
	@echo "  $(YELLOW)make helm-lint$(NC)          Lint Helm charts"
	@echo "  $(YELLOW)make helm-deps$(NC)          Update Helm dependencies"
	@echo "  $(YELLOW)make helm-package$(NC)       Package Helm chart"
	@echo ""
	@echo "$(BLUE)IMAGE BUILD COMMANDS:$(NC)"
	@echo "  $(YELLOW)make dashboard-build$(NC)    Build dashboard images"
	@echo "  $(YELLOW)make dashboard-push$(NC)     Push dashboard images"
	@echo "  $(YELLOW)make model-loader-build$(NC) Build model loader image"
	@echo "  $(YELLOW)make model-loader-push$(NC)  Push model loader image"
	@echo "  $(YELLOW)make all-images-build$(NC)   Build all images"
	@echo "  $(YELLOW)make all-images-push$(NC)    Push all images"
	@echo ""
	@echo "$(RED)Current Configuration:$(NC)"
	@echo "  Git Version: $(GIT_VERSION)"
	@echo "  Git Branch: $(GIT_BRANCH)"

#=============================================================================
# DEVELOPMENT DEPLOYMENT
#=============================================================================
.PHONY: dev-deploy
dev-deploy: ## Deploy complete pipeline to development
	@echo "$(GREEN)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(GREEN)Deploying to DEVELOPMENT$(NC)"
	@echo "$(GREEN)════════════════════════════════════════════════════════════════$(NC)"
	@echo "Namespace: $(DEV_NAMESPACE)"
	@echo "Release: $(HELM_RELEASE_DEV)"
	@echo ""
	# Create namespace if needed
	$(KUBECTL) create namespace $(DEV_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	# Deploy with Helm
	$(HELM) upgrade --install $(HELM_RELEASE_DEV) $(HELM_CHART) \
		--namespace $(DEV_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-dev.yaml \
		--set global.namespace=$(DEV_NAMESPACE) \
		--set global.imageTag=latest \
		--set dashboard.image.tag=latest \
		--set crds.install=false \
		--wait
	@echo "$(GREEN)✓ Development deployment complete$(NC)"

.PHONY: dev-upgrade
dev-upgrade: ## Upgrade development deployment
	@echo "$(GREEN)Upgrading development deployment...$(NC)"
	$(HELM) upgrade $(HELM_RELEASE_DEV) $(HELM_CHART) \
		--namespace $(DEV_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-dev.yaml \
		--set global.namespace=$(DEV_NAMESPACE) \
		--set global.imageTag=latest \
		--set dashboard.image.tag=latest \
		--wait
	@echo "$(GREEN)✓ Development upgrade complete$(NC)"

.PHONY: dev-remove
dev-remove: ## Remove development deployment
	@echo "$(YELLOW)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(YELLOW)Removing DEVELOPMENT deployment$(NC)"
	@echo "$(YELLOW)════════════════════════════════════════════════════════════════$(NC)"
	$(HELM) uninstall $(HELM_RELEASE_DEV) --namespace $(DEV_NAMESPACE) || true
	# Clean up any remaining resources
	$(KUBECTL) delete pvc --all -n $(DEV_NAMESPACE) || true
	@echo "$(GREEN)✓ Development deployment removed$(NC)"

.PHONY: dev-status
dev-status: ## Show development deployment status
	@echo "$(GREEN)Development Deployment Status:$(NC)"
	$(HELM) status $(HELM_RELEASE_DEV) --namespace $(DEV_NAMESPACE) || echo "Not deployed"
	@echo ""
	@echo "$(GREEN)Resources:$(NC)"
	$(KUBECTL) get all,pvc -n $(DEV_NAMESPACE)

#=============================================================================
# PRODUCTION DEPLOYMENT
#=============================================================================
.PHONY: prod-deploy
prod-deploy: ## Deploy complete pipeline to production
	@echo "$(PURPLE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(PURPLE)PRODUCTION DEPLOYMENT$(NC)"
	@echo "$(PURPLE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "Namespace: $(PROD_NAMESPACE)"
	@echo "Release: $(HELM_RELEASE_PROD)"
	@echo "Version: $(GIT_VERSION)"
	@echo ""
	@echo "$(RED)Type 'yes' to deploy to PRODUCTION:$(NC)"
	@read confirm && [ "$$confirm" = "yes" ] || (echo "$(RED)Deployment cancelled$(NC)" && exit 1)
	# Create namespace if needed
	$(KUBECTL) create namespace $(PROD_NAMESPACE) --dry-run=client -o yaml | $(KUBECTL) apply -f -
	# Deploy with Helm
	$(HELM) upgrade --install $(HELM_RELEASE_PROD) $(HELM_CHART) \
		--namespace $(PROD_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-prod.yaml \
		--set global.namespace=$(PROD_NAMESPACE) \
		--set global.imageTag=$(GIT_VERSION) \
		--set dashboard.image.tag=$(GIT_VERSION) \
		--wait
	@echo "$(PURPLE)✓ Production deployment complete$(NC)"

.PHONY: prod-upgrade
prod-upgrade: ## Upgrade production deployment
	@echo "$(PURPLE)Upgrading production deployment...$(NC)"
	@echo "Version: $(GIT_VERSION)"
	@echo ""
	@echo "$(RED)Type 'yes' to upgrade PRODUCTION:$(NC)"
	@read confirm && [ "$$confirm" = "yes" ] || (echo "$(RED)Upgrade cancelled$(NC)" && exit 1)
	$(HELM) upgrade $(HELM_RELEASE_PROD) $(HELM_CHART) \
		--namespace $(PROD_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-prod.yaml \
		--set global.namespace=$(PROD_NAMESPACE) \
		--set global.imageTag=$(GIT_VERSION) \
		--set dashboard.image.tag=$(GIT_VERSION) \
		--wait
	@echo "$(PURPLE)✓ Production upgrade complete$(NC)"

.PHONY: prod-remove
prod-remove: ## Remove production deployment
	@echo "$(RED)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(RED)⚠️  PRODUCTION REMOVAL WARNING ⚠️$(NC)"
	@echo "$(RED)════════════════════════════════════════════════════════════════$(NC)"
	@echo ""
	@echo "$(RED)Type 'yes' to remove PRODUCTION deployment:$(NC)"
	@read confirm && [ "$$confirm" = "yes" ] || (echo "$(RED)Removal cancelled$(NC)" && exit 1)
	$(HELM) uninstall $(HELM_RELEASE_PROD) --namespace $(PROD_NAMESPACE) || true
	# Clean up any remaining resources
	$(KUBECTL) delete pvc --all -n $(PROD_NAMESPACE) || true
	@echo "$(RED)✓ Production deployment removed$(NC)"

.PHONY: prod-status
prod-status: ## Show production deployment status
	@echo "$(PURPLE)Production Deployment Status:$(NC)"
	$(HELM) status $(HELM_RELEASE_PROD) --namespace $(PROD_NAMESPACE) || echo "Not deployed"
	@echo ""
	@echo "$(PURPLE)Resources:$(NC)"
	$(KUBECTL) get all,pvc -n $(PROD_NAMESPACE)

#=============================================================================
# HELM MANAGEMENT
#=============================================================================
.PHONY: helm-lint
helm-lint: ## Lint Helm charts
	@echo "$(BLUE)Linting Helm charts...$(NC)"
	$(HELM) lint $(HELM_CHART)
	@echo "$(GREEN)✓ Helm charts are valid$(NC)"

.PHONY: helm-deps
helm-deps: ## Update Helm dependencies
	@echo "$(BLUE)Updating Helm dependencies...$(NC)"
	$(HELM) dependency update $(HELM_CHART)
	@echo "$(GREEN)✓ Dependencies updated$(NC)"

.PHONY: helm-package
helm-package: ## Package Helm chart
	@echo "$(BLUE)Packaging Helm chart...$(NC)"
	$(HELM) package $(HELM_CHART) --version $(GIT_VERSION)
	@echo "$(GREEN)✓ Chart packaged$(NC)"

.PHONY: helm-dry-run-dev
helm-dry-run-dev: ## Dry run dev deployment
	$(HELM) upgrade --install $(HELM_RELEASE_DEV) $(HELM_CHART) \
		--namespace $(DEV_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-dev.yaml \
		--set global.namespace=$(DEV_NAMESPACE) \
		--set global.imageTag=latest \
		--dry-run --debug

.PHONY: helm-dry-run-prod
helm-dry-run-prod: ## Dry run prod deployment
	$(HELM) upgrade --install $(HELM_RELEASE_PROD) $(HELM_CHART) \
		--namespace $(PROD_NAMESPACE) \
		--values $(HELM_CHART)/values.yaml \
		--values $(HELM_CHART)/values-prod.yaml \
		--set global.namespace=$(PROD_NAMESPACE) \
		--set global.imageTag=$(GIT_VERSION) \
		--dry-run --debug

#=============================================================================
# IMAGE BUILD COMMANDS
#=============================================================================
.PHONY: dashboard-build
dashboard-build: ## Build dashboard images
	@echo "$(BLUE)Building dashboard images...$(NC)"
	$(MAKE) -C dashboard build
	@echo "$(GREEN)✓ Dashboard images built$(NC)"

.PHONY: model-loader-build
model-loader-build: ## Build model loader image
	@echo "$(BLUE)Building model loader image...$(NC)"
	podman build -t quay.io/aasmith/ai-model-loader:latest \
		-f $(HELM_CHART)/docker/model-loader/Dockerfile \
		$(HELM_CHART)/docker/model-loader
	@echo "$(GREEN)✓ Model loader image built$(NC)"

.PHONY: model-loader-push
model-loader-push: ## Push model loader image
	@echo "$(BLUE)Pushing model loader image...$(NC)"
	podman push quay.io/aasmith/ai-model-loader:latest
	@echo "$(GREEN)✓ Model loader image pushed$(NC)"

.PHONY: all-images-build
all-images-build: dashboard-build model-loader-build ## Build all images
	@echo "$(GREEN)✓ All images built$(NC)"

.PHONY: all-images-push
all-images-push: dashboard-push model-loader-push ## Push all images
	@echo "$(GREEN)✓ All images pushed$(NC)"

.PHONY: dashboard-push
dashboard-push: ## Push dashboard images
	@echo "$(BLUE)Pushing dashboard images...$(NC)"
	$(MAKE) -C dashboard push
	@echo "$(GREEN)✓ Dashboard images pushed$(NC)"

#=============================================================================
# UTILITY COMMANDS
#=============================================================================
.PHONY: status
status: ## Show all deployments status
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@echo "$(BLUE)All Deployments Status$(NC)"
	@echo "$(BLUE)════════════════════════════════════════════════════════════════$(NC)"
	@$(MAKE) dev-status
	@echo ""
	@$(MAKE) prod-status

.PHONY: clean-all
clean-all: ## Remove all deployments
	@echo "$(RED)This will remove ALL deployments!$(NC)"
	@echo "$(RED)Type 'yes' to continue:$(NC)"
	@read confirm && [ "$$confirm" = "yes" ] || (echo "$(RED)Cancelled$(NC)" && exit 1)
	@$(MAKE) dev-remove
	@$(MAKE) prod-remove

.PHONY: version
version: ## Show version information
	@echo "$(BLUE)Version Information:$(NC)"
	@echo "  Git Version: $(GIT_VERSION)"
	@echo "  Git Branch: $(GIT_BRANCH)"
	@echo "  Build Date: $(BUILD_DATE)"
	@echo "  Helm Version: $(shell $(HELM) version --short)"

# Default target
.DEFAULT_GOAL := help
