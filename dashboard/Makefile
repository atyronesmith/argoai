# AI Workflow Dashboard Makefile
# Dashboard-specific build and deployment operations

#=============================================================================
# CONFIGURATION
#=============================================================================
PROJECT_NAME := ai-workflow-dashboard

# Load registry configuration
SECRETS_DIR := ../secrets
REGISTRY_CONF := $(SECRETS_DIR)/registry.conf

ifneq ("$(wildcard $(REGISTRY_CONF))","")
    include $(REGISTRY_CONF)
    REGISTRY := $(REGISTRY_URL)/$(REGISTRY_ORG)
else
    REGISTRY := quay.io/aasmith
endif

# Git versioning
GIT_VERSION := $(shell git describe --tags --always --dirty 2>/dev/null || echo "latest")
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT := $(shell git rev-parse HEAD 2>/dev/null || echo "unknown")

# Tools
PODMAN := $(shell which podman 2>/dev/null || echo "podman")
KUBECTL := $(shell which kubectl 2>/dev/null || which oc 2>/dev/null || echo "kubectl")
NPM := $(shell which npm 2>/dev/null || echo "npm")

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

#=============================================================================
# HELP
#=============================================================================
.PHONY: help
help:
	@echo "$(BLUE)╔═══════════════════════════════════════════════════════════════╗$(NC)"
	@echo "$(BLUE)║              AI Workflow Dashboard - Makefile                  ║$(NC)"
	@echo "$(BLUE)╚═══════════════════════════════════════════════════════════════╝$(NC)"
	@echo ""
	@echo "$(GREEN)BUILD COMMANDS:$(NC)"
	@echo "  $(YELLOW)make build$(NC)              Build images with git version"
	@echo "  $(YELLOW)make build-latest$(NC)       Build images with :latest tag"
	@echo "  $(YELLOW)make push$(NC)               Push images"
	@echo ""
	@echo "$(BLUE)STANDALONE DEPLOYMENT:$(NC)"
	@echo "  $(YELLOW)make deploy$(NC)             Deploy dashboard standalone"
	@echo "  $(YELLOW)make remove$(NC)             Remove dashboard deployment"
	@echo ""
	@echo "$(BLUE)LOCAL DEVELOPMENT:$(NC)"
	@echo "  $(YELLOW)make install$(NC)            Install npm dependencies"
	@echo "  $(YELLOW)make dev$(NC)                Run local development servers"
	@echo "  $(YELLOW)make test$(NC)               Run tests"
	@echo "  $(YELLOW)make clean$(NC)              Clean build artifacts"
	@echo ""
	@echo "Current Registry: $(REGISTRY)"
	@echo "Current Version: $(GIT_VERSION)"

#=============================================================================
# BUILD COMMANDS
#=============================================================================
.PHONY: build
build: ## Build dashboard images with git version
	@echo "$(GREEN)Building dashboard images (version: $(GIT_VERSION))...$(NC)"
	$(PODMAN) build \
		--build-arg VERSION=$(GIT_VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(REGISTRY)/$(PROJECT_NAME)-backend:$(GIT_VERSION) \
		-f backend/Dockerfile backend
	$(PODMAN) build \
		--build-arg VERSION=$(GIT_VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(REGISTRY)/$(PROJECT_NAME)-frontend:$(GIT_VERSION) \
		-f frontend/Dockerfile frontend
	@echo "$(GREEN)✓ Images built with version $(GIT_VERSION)$(NC)"

.PHONY: build-latest
build-latest: ## Build dashboard images with latest tag
	@echo "$(GREEN)Building dashboard images (latest)...$(NC)"
	$(PODMAN) build \
		--build-arg VERSION=latest \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(REGISTRY)/$(PROJECT_NAME)-backend:latest \
		-f backend/Dockerfile backend
	$(PODMAN) build \
		--build-arg VERSION=latest \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		-t $(REGISTRY)/$(PROJECT_NAME)-frontend:latest \
		-f frontend/Dockerfile frontend
	@echo "$(GREEN)✓ Images built with latest tag$(NC)"

.PHONY: push
push: ## Push dashboard images
	@echo "$(GREEN)Pushing dashboard images...$(NC)"
	# Push git version
	$(PODMAN) push $(REGISTRY)/$(PROJECT_NAME)-backend:$(GIT_VERSION)
	$(PODMAN) push $(REGISTRY)/$(PROJECT_NAME)-frontend:$(GIT_VERSION)
	# Also push as latest if on main branch
ifeq ($(shell git rev-parse --abbrev-ref HEAD),main)
	$(PODMAN) tag $(REGISTRY)/$(PROJECT_NAME)-backend:$(GIT_VERSION) $(REGISTRY)/$(PROJECT_NAME)-backend:latest
	$(PODMAN) tag $(REGISTRY)/$(PROJECT_NAME)-frontend:$(GIT_VERSION) $(REGISTRY)/$(PROJECT_NAME)-frontend:latest
	$(PODMAN) push $(REGISTRY)/$(PROJECT_NAME)-backend:latest
	$(PODMAN) push $(REGISTRY)/$(PROJECT_NAME)-frontend:latest
endif
	@echo "$(GREEN)✓ Images pushed$(NC)"

#=============================================================================
# STANDALONE DEPLOYMENT (when not using Helm)
#=============================================================================
.PHONY: deploy
deploy: ## Deploy dashboard standalone to current namespace
	@echo "$(BLUE)Deploying dashboard standalone...$(NC)"
	$(KUBECTL) apply -f k8s/
	@echo "$(GREEN)✓ Dashboard deployed$(NC)"

.PHONY: remove
remove: ## Remove dashboard deployment
	@echo "$(YELLOW)Removing dashboard deployment...$(NC)"
	$(KUBECTL) delete -f k8s/ || true
	@echo "$(GREEN)✓ Dashboard removed$(NC)"

#=============================================================================
# LOCAL DEVELOPMENT
#=============================================================================
.PHONY: install
install: ## Install npm dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	cd backend && $(NPM) ci
	cd frontend && $(NPM) ci
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

.PHONY: dev
dev: ## Run local development servers
	@echo "$(BLUE)Starting development servers...$(NC)"
	@echo "Backend: http://localhost:3001"
	@echo "Frontend: http://localhost:3000"
	@trap 'kill %1' INT; \
	(cd backend && $(NPM) run dev) & \
	(cd frontend && $(NPM) start) & \
	wait

.PHONY: test
test: ## Run tests
	@echo "$(BLUE)Running tests...$(NC)"
	cd backend && $(NPM) test
	cd frontend && $(NPM) test -- --watchAll=false

.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	rm -rf backend/dist backend/node_modules
	rm -rf frontend/build frontend/node_modules
	@echo "$(GREEN)✓ Clean complete$(NC)"

# Default target
.DEFAULT_GOAL := help
