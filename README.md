# AI-Enhanced Document Processing Pipeline on OpenShift Local

This repository contains the implementation of an AI-Enhanced Document Processing Pipeline using Argo Workflows on OpenShift Local (CRC), with Ollama for AI/LLM capabilities and MinIO for artifact storage.

## 📋 Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Scripts and Tools](#scripts-and-tools)
- [Services and Access](#services-and-access)
- [Usage Guide](#usage-guide)
- [Troubleshooting](#troubleshooting)
- [Next Steps](#next-steps)

## 🎯 Overview

This project implements an enterprise-grade document processing pipeline that leverages:
- **OpenShift Local (CRC)** - Container platform for running the infrastructure
- **Argo Workflows** - Workflow orchestration for document processing pipelines
- **Ollama** - Local LLM runtime for AI-powered document analysis
- **MinIO** - S3-compatible object storage for artifacts and documents

### Key Features
- Automated setup and deployment scripts
- Idempotent installation process (safe to run multiple times)
- AI-powered document processing workflows
- **NEW: Smart Inbox** - Drop documents in one place, AI organizes them automatically
- Event-driven architecture with Argo Events
- Scalable architecture suitable for production deployment
- Complete local development environment

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   OpenShift Local (CRC)                 │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────┐  ┌───────────────┐ │
│  │ Argo        │  │   Ollama     │  │    MinIO      │ │
│  │ Workflows   │  │   (LLMs)     │  │  (Storage)    │ │
│  └─────────────┘  └──────────────┘  └───────────────┘ │
│         ↓                ↓                    ↓         │
│  ┌──────────────────────────────────────────────────┐  │
│  │          Document Processing Pipeline             │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## ✅ Prerequisites

1. **System Requirements**
   - macOS, Linux, or Windows with WSL2
   - Minimum 16GB RAM (32GB recommended)
   - 60GB+ free disk space
   - 6+ CPU cores

2. **Required Accounts**
   - Red Hat Developer account (free): https://developers.redhat.com/register
   - Pull secret from: https://console.redhat.com/openshift/create/local

3. **Software**
   - OpenShift Local (CRC) - downloaded from Red Hat console
   - Git
   - curl

## 🚀 Quick Start

### 1. Clone the Repository
```bash
git clone <repository-url>
cd argoai
```

### 2. Run the Automated Setup
```bash
# Make scripts executable
chmod +x *.sh

# Option 1: Run the new modular setup (recommended)
./setup.sh                    # Sets up CRC and installs all tools (Helm, Argo CLI, MinIO Client, jq)
./deploy-with-helm.sh         # Deploys services using Helm (includes CRD installation)

# Option 2: Run the legacy all-in-one setup
./scripts/setup-crc-openshift.sh      # Complete setup (deprecated, doesn't install CLI tools)
```

The setup.sh script will:
- Guide you through CRC installation if needed
- Prompt for your Red Hat pull secret (hidden input)
- Set up OpenShift Local with proper resources
- Install required CLI tools:
  - **Helm** - Package manager for Kubernetes
  - **Argo CLI** - Native workflow management commands
  - **MinIO Client (mc)** - Object storage management
  - **jq** - JSON processing utility
- Configure the OpenShift environment
- Display access URLs and credentials

Then deploy-with-helm.sh will:
- Deploy all required services (Argo, Ollama, MinIO)
- Load AI models into Ollama
- Configure integrations and security

> **📚 For detailed Helm deployment options and configurations, see the [Helm Chart README](./helm/ai-document-pipeline/README.md)**

### 3. Set Up Your Environment
```bash
# Source the environment setup (do this once per terminal session)
source ./setup-env.sh
```

### 4. Load AI Models
```bash
# Load the recommended model for document processing
./scripts/ollama-load-model.sh -m llama3.2:3b

# Or use the convenience function after sourcing setup-env.sh
load-model llama3.2:3b
```

## 📁 Scripts and Tools

### Core Setup Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup.sh` | **NEW** - Setup OpenShift Local (CRC) and install all tools (Helm, Argo CLI, MinIO Client, jq) | `./setup.sh` |
| `deploy-with-helm.sh` | **NEW** - Deploy services using Helm charts | `./deploy-with-helm.sh` |
| `setup-crc-openshift.sh` | ⚠️ **Deprecated** - Legacy all-in-one setup script | `./scripts/setup-crc-openshift.sh` |
| `setup-env.sh` | Environment setup with aliases and functions | `source ./setup-env.sh` |
| `ollama-load-model.sh` | Load AI models into Ollama (wrapper) | `./scripts/ollama-load-model.sh -m MODEL` |
| `load-ollama-models.sh` | Advanced model management with interactive menu | `./scripts/load-ollama-models.sh [options]` |
| `ollama-api-helper.sh` | Interact with Ollama via API | `./scripts/ollama-api-helper.sh` |
| `submit-test-workflow.sh` | Submit and manage test workflows | `./scripts/submit-test-workflow.sh [options]` |
| `fix-common-issues.sh` | Fix common issues and check system health | `./scripts/fix-common-issues.sh` |
| `deploy-full-workflow.sh` | Deploy the complete AI workflow template | `./scripts/deploy-full-workflow.sh` |

### Key Features of Scripts

**scripts/setup-crc-openshift.sh** (deprecated - use setup.sh instead)
- Fully idempotent (safe to run multiple times)
- Automatic password extraction from CRC
- Handles pull secret configuration
- Deploys all services with proper configurations
- Fixes common issues automatically

**setup-env.sh**
- Sets up kubectl/oc environment
- Provides convenient aliases
- Exports service URLs as environment variables
- Includes helper functions for common tasks

**Model Loading Scripts**
- Support for multiple models
- Progress tracking
- Model testing capabilities
- Both CLI and interactive modes

**scripts/submit-test-workflow.sh**
- Automated workflow submission with defaults
- Predefined sample documents for testing
- Model availability checking
- Workflow monitoring and management
- Integrated with CRC environment setup

**scripts/fix-common-issues.sh**
- Interactive troubleshooter for known issues
- Fixes Argo UI 502 errors automatically
- Repairs workflow controller configuration
- Checks system health and pod status
- One-click fix for all common problems

## 🌐 Services and Access

After setup, the following services are available:

### Service URLs
- **Argo Workflows UI**: `https://argo-server-argo-ai-demo.apps-crc.testing`
- **MinIO Console**: `https://minio-console-argo-ai-demo.apps-crc.testing`
- **Ollama API**: `https://ollama-argo-ai-demo.apps-crc.testing`
- **OpenShift Console**: `https://console-openshift-console.apps-crc.testing`

### Credentials
- **OpenShift Admin**: kubeadmin / (auto-extracted password)
- **OpenShift Developer**: developer / developer
- **MinIO**: Configured via environment variables (see .env.example)

### Quick Access (after sourcing setup-env.sh)
```bash
argo-ui       # Open Argo UI in browser
minio-ui      # Open MinIO Console
openshift-ui  # Open OpenShift Console
```

## 📖 Usage Guide

### Working with Models

```bash
# List available models
./scripts/load-ollama-models.sh -l

# Load a specific model
./scripts/ollama-load-model.sh -m mistral:7b

# Check loaded models
./scripts/load-ollama-models.sh -s

# Test a model
./scripts/ollama-api-helper.sh  # Choose option 3
```

### Monitoring Services

```bash
# After sourcing setup-env.sh
ollama-logs      # Follow Ollama logs
argo-logs        # Follow Argo server logs
workflow-logs    # Follow workflow controller logs
get-pods         # Show all pods
```

### Submitting Workflows

#### Using the Workflow Submission Script (Recommended)

```bash
# Submit with defaults (Kubernetes README, llama3.2:3b model)
./scripts/submit-test-workflow.sh

# Use a predefined sample document
./scripts/submit-test-workflow.sh -s argo        # Argo Workflows README
./scripts/submit-test-workflow.sh -s openshift   # OpenShift README

# Submit with custom document and model
./scripts/submit-test-workflow.sh -d "https://example.com/document.txt" -m mistral:7b

# Submit and watch the workflow progress
./scripts/submit-test-workflow.sh -w

# List all workflows
./scripts/submit-test-workflow.sh -l

# Get details of a specific workflow
./scripts/submit-test-workflow.sh -g <workflow-name>
```

#### Using Helper Function (after sourcing setup-env.sh)

```bash
submit-workflow "https://example.com/document.pdf" "llama3.2:3b"
```

#### Manual Submission

```bash
oc create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ai-doc-process-
  namespace: argo-ai-demo
spec:
  workflowTemplateRef:
    name: ai-document-processor
  arguments:
    parameters:
    - name: doc-url
      value: "https://example.com/document.txt"
    - name: model
      value: "llama3.2:3b"
EOF
```

## 🔧 Troubleshooting

### Common Issues and Solutions

**Quick Fix**: Run `./scripts/fix-common-issues.sh` for an interactive troubleshooter that can fix most issues automatically.

1. **"oc command not found"**
   ```bash
   eval $(crc oc-env)
   # Or use the wrapper scripts that handle this automatically
   ```

2. **"Failed to get kubeadmin password"**
   - Ensure CRC is running: `crc status`
   - Manually get password: `crc console --credentials`

3. **Workflow Controller CrashLoopBackOff**
   - Fixed automatically by the script
   - Manual fix: Check the workflow-controller-configmap YAML formatting

4. **Argo UI 502 Bad Gateway Error**
   - Cause: Readiness probe mismatch (HTTPS probe with HTTP server)
   - Fixed automatically by the script
   - Manual fix:
     ```bash
     oc patch deployment argo-server -n argo-ai-demo --type='json' \
       -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]'
     ```

5. **Model pulling takes forever**
   - Normal for first-time downloads
   - Monitor progress: `oc logs deployment/ollama -f -n argo-ai-demo`

6. **Cannot access web UIs**
   - Check routes: `oc get routes -n argo-ai-demo`
   - Ensure you're using HTTPS and accepting self-signed certificates
   - Try port-forwarding as alternative: `oc port-forward svc/argo-server 2746:2746 -n argo-ai-demo`

### Useful Debugging Commands

```bash
# Check pod status
oc get pods -n argo-ai-demo

# View pod logs
oc logs <pod-name> -n argo-ai-demo

# Describe a pod for detailed info
oc describe pod <pod-name> -n argo-ai-demo

# Check events
oc get events -n argo-ai-demo --sort-by='.lastTimestamp'
```

## 📈 Current Status

### ✅ Completed
- [x] OpenShift Local (CRC) setup and configuration
- [x] Argo Workflows deployment and configuration
- [x] Ollama AI service deployment
- [x] MinIO object storage deployment
- [x] Service integrations and RBAC
- [x] Automated setup scripts with idempotency
- [x] Model loading utilities
- [x] Environment setup helpers
- [x] Full AI workflow template with complete document processing
- [x] Document classification and priority detection
- [x] Type-specific information extraction
- [x] Intelligent routing and report generation

### 🚧 In Progress / Next Steps
- [ ] Monitoring and observability setup (Prometheus ServiceMonitor)
- [ ] Production deployment guide
- [ ] Performance tuning and optimization
- [ ] Batch processing capabilities
- [ ] API gateway for external integration

## 🔧 Troubleshooting

### Common Issues and Solutions

#### 1. Argo UI Shows "Application is not available"
**Problem**: The Argo Server pod is not ready due to authentication issues.

**Solution**: The Helm chart has been updated to include `--auth-mode=server`. If you still face this issue:
```bash
# Check pod status
oc get pods -n argo-ai-demo | grep argo-server

# If pod is 0/1, upgrade the Helm release
helm upgrade ai-pipeline ./helm/ai-document-pipeline \
  --namespace argo-ai-demo \
  --values ./helm/ai-document-pipeline/values-dev.yaml \
  --no-hooks
```

#### 2. Workflow Controller RBAC Warnings
**Problem**: Logs show warnings about `workflowartifactgctasks` and `workflowtaskresults`.

**Solution**: These are optional CRDs and the warnings don't affect basic functionality. They can be safely ignored for development use.

#### 3. Model Loading Job Fails
**Problem**: The `load-models` job shows `CrashLoopBackOff` due to missing `jq` command.

**Solution**: The models are actually loaded successfully. You can verify and clean up:
```bash
# Check loaded models
curl -s https://ollama-argo-ai-demo.apps-crc.testing/api/tags --insecure | jq -r '.models[].name'

# Delete the failed job
oc delete job -l app.kubernetes.io/component=ollama-models -n argo-ai-demo
```

#### 4. Submit Test Workflow Script Fails
**Problem**: Script can't find Ollama pod due to label mismatch.

**Solution**: The script has been updated to use the correct label. Pull the latest changes or manually update:
```bash
# The correct label is:
app.kubernetes.io/component=ollama
```

#### 5. Helm Installation Times Out
**Problem**: `helm install` fails with timeout waiting for post-install hooks.

**Solution**: Use `--no-hooks` flag or increase timeout:
```bash
# Install without hooks
helm install ai-pipeline ./helm/ai-document-pipeline \
  --create-namespace \
  --namespace argo-ai-demo \
  --values ./helm/ai-document-pipeline/values-dev.yaml \
  --no-hooks
```

### Health Check Commands

```bash
# Check all pods status
oc get pods -n argo-ai-demo

# Check services and routes
oc get svc,route -n argo-ai-demo

# Test Ollama
curl -s https://ollama-argo-ai-demo.apps-crc.testing/api/tags --insecure

# Test Argo UI
curl -s -o /dev/null -w "%{http_code}" https://argo-server-argo-ai-demo.apps-crc.testing --insecure
```

## 🚦 Next Steps

1. **Load AI Models**: If you haven't already, load at least one model:
   ```bash
   ./scripts/ollama-load-model.sh -m llama3.2:3b
   ```

2. **Use the Smart Inbox** (NEW!): Drop documents and let AI organize them:
   ```bash
   # Configure MinIO client
   mc alias set myminio https://minio-argo-ai-demo.apps-crc.testing admin changeme

   # Drop any document into the inbox
   mc cp invoice.pdf myminio/documents/inbox/

   # Document will be automatically:
   # - Classified (invoice/contract/technical/correspondence)
   # - Prioritized (normal/urgent)
   # - Moved to organized folder
   # - Processed with appropriate workflow
   ```

3. **Test the Pipeline**: Submit a test workflow to process a document manually

4. **Customize Workflows**: Modify the workflow template for your specific use cases

5. **Add Monitoring**: Implement the ServiceMonitor for Prometheus integration

6. **Scale Up**: Consider moving to a production OpenShift cluster for real workloads

## 📚 Documentation

All documentation has been organized in the [docs/](./docs/) directory:

- **[docs/STATUS.md](./docs/STATUS.md)** - 🆕 **Current deployment status, known issues, and test results**
- [docs/IMPLEMENTATION_PLAN.md](./docs/IMPLEMENTATION_PLAN.md) - Detailed step-by-step implementation guide
- [docs/PLAN1.md](./docs/PLAN1.md) - Original project plan and architecture
- [docs/CLAUDE.md](./docs/CLAUDE.md) - Additional implementation notes
- **[docs/DEMO.md](./docs/DEMO.md)** - 🆕 **Comprehensive demo walkthrough with tables, diagrams, and real examples**
- [docs/PRODUCTION-DEPLOYMENT-PLAN.md](./docs/PRODUCTION-DEPLOYMENT-PLAN.md) - Enterprise deployment strategies (Ansible, Python, Helm, GitOps, Terraform)
- [docs/SECURITY-AUDIT.md](./docs/SECURITY-AUDIT.md) - Security considerations and hardening guide

See [docs/README.md](./docs/README.md) for the complete documentation index.

## 🔐 Security Notice

**⚠️ IMPORTANT**: This repository contains example credentials for local development. Before deploying to production or making this repository public:

1. **Review [docs/SECURITY-AUDIT.md](./docs/SECURITY-AUDIT.md)** for a complete security checklist
2. **Run `./scripts/prepare-for-public.sh`** to check for hardcoded credentials
3. **Use environment variables** instead of hardcoded passwords
4. **Never commit** pull secrets, tokens, or actual passwords
5. **Update all credentials** from their default values

See `.env.example` for configuration options.

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Note**: This is a development setup using OpenShift Local. For production deployments, use a full OpenShift cluster with appropriate resources and security configurations.
