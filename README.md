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

# Run the complete setup
./setup-crc-openshift.sh
```

The script will:
- Guide you through CRC installation if needed
- Prompt for your Red Hat pull secret (hidden input)
- Set up OpenShift Local with proper resources
- Deploy all required services (Argo, Ollama, MinIO)
- Configure integrations and security
- Display access URLs and credentials

### 3. Set Up Your Environment
```bash
# Source the environment setup (do this once per terminal session)
source ./setup-env.sh
```

### 4. Load AI Models
```bash
# Load the recommended model for document processing
./ollama-load-model.sh -m llama3.2:3b

# Or use the convenience function after sourcing setup-env.sh
load-model llama3.2:3b
```

## 📁 Scripts and Tools

### Core Setup Scripts

| Script | Purpose | Usage |
|--------|---------|-------|
| `setup-crc-openshift.sh` | Main setup script - installs and configures everything | `./setup-crc-openshift.sh` |
| `setup-env.sh` | Environment setup with aliases and functions | `source ./setup-env.sh` |
| `ollama-load-model.sh` | Load AI models into Ollama (wrapper) | `./ollama-load-model.sh -m MODEL` |
| `load-ollama-models.sh` | Advanced model management with interactive menu | `./load-ollama-models.sh [options]` |
| `ollama-api-helper.sh` | Interact with Ollama via API | `./ollama-api-helper.sh` |
| `submit-test-workflow.sh` | Submit and manage test workflows | `./submit-test-workflow.sh [options]` |
| `fix-common-issues.sh` | Fix common issues and check system health | `./fix-common-issues.sh` |
| `deploy-full-workflow.sh` | Deploy the complete AI workflow template | `./deploy-full-workflow.sh` |

### Key Features of Scripts

**setup-crc-openshift.sh**
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

**submit-test-workflow.sh**
- Automated workflow submission with defaults
- Predefined sample documents for testing
- Model availability checking
- Workflow monitoring and management
- Integrated with CRC environment setup

**fix-common-issues.sh**
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
./load-ollama-models.sh -l

# Load a specific model
./ollama-load-model.sh -m mistral:7b

# Check loaded models
./load-ollama-models.sh -s

# Test a model
./ollama-api-helper.sh  # Choose option 3
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
./submit-test-workflow.sh

# Use a predefined sample document
./submit-test-workflow.sh -s argo        # Argo Workflows README
./submit-test-workflow.sh -s openshift   # OpenShift README

# Submit with custom document and model
./submit-test-workflow.sh -d "https://example.com/document.txt" -m mistral:7b

# Submit and watch the workflow progress
./submit-test-workflow.sh -w

# List all workflows
./submit-test-workflow.sh -l

# Get details of a specific workflow
./submit-test-workflow.sh -g <workflow-name>
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

**Quick Fix**: Run `./fix-common-issues.sh` for an interactive troubleshooter that can fix most issues automatically.

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

## 🚦 Next Steps

1. **Load AI Models**: If you haven't already, load at least one model:
   ```bash
   ./ollama-load-model.sh -m llama3.2:3b
   ```

2. **Test the Pipeline**: Submit a test workflow to process a document

3. **Customize Workflows**: Modify the workflow template for your specific use cases

4. **Add Monitoring**: Implement the ServiceMonitor for Prometheus integration

5. **Scale Up**: Consider moving to a production OpenShift cluster for real workloads

## 📚 Documentation

- `IMPLEMENTATION_PLAN.md` - Detailed step-by-step implementation guide
- `PLAN1.md` - Original project plan and architecture
- `CLAUDE.md` - Additional implementation notes
- **`DEMO.md`** - 🆕 **Comprehensive demo walkthrough with tables, diagrams, and real examples**
- `PRODUCTION-DEPLOYMENT-PLAN.md` - Enterprise deployment strategies (Ansible, Python, Helm, GitOps, Terraform)
- `SECURITY-AUDIT.md` - Security considerations and hardening guide

## 🔐 Security Notice

**⚠️ IMPORTANT**: This repository contains example credentials for local development. Before deploying to production or making this repository public:

1. **Review `SECURITY-AUDIT.md`** for a complete security checklist
2. **Run `./prepare-for-public.sh`** to check for hardcoded credentials
3. **Use environment variables** instead of hardcoded passwords
4. **Never commit** pull secrets, tokens, or actual passwords
5. **Update all credentials** from their default values

See `.env.example` for configuration options.

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

[Specify your license here]

---

**Note**: This is a development setup using OpenShift Local. For production deployments, use a full OpenShift cluster with appropriate resources and security configurations.
