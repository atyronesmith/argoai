# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains a demonstration plan for an AI-Enhanced Document Processing Pipeline built on OpenShift. The project showcases the integration of Argo Workflows with AI services (Ollama) for automated document processing and analysis.

## Key Components and Architecture

### Core Technologies
- **OpenShift Local (CRC)**: Enterprise Kubernetes platform for container orchestration
- **Argo Workflows**: Workflow orchestration engine for complex, multi-step document processing
- **Ollama**: Local LLM server for AI document analysis and classification
- **MinIO**: S3-compatible object storage for document artifacts
- **Qdrant**: Vector database for document embeddings (referenced in architecture)

### System Architecture
The system follows a microservices pattern with these key components:
- Document ingestion pipeline
- AI-powered classification and extraction
- Priority-based routing and processing
- Report generation and artifact storage

### Deployment Model
- Uses OpenShift-native resources (DeploymentConfigs, Routes, SCCs)
- Leverages persistent volume claims for shared storage
- Implements proper RBAC and security contexts
- Includes monitoring and observability features

## Common Development Tasks

### OpenShift Local Setup
```bash
# Start CRC with proper resources
crc start --cpus 6 --memory 16384 --disk-size 60

# Login and create project
oc login -u developer -p developer
oc new-project argo-ai-demo
```

### Workflow Management
```bash
# Submit workflow from template
argo submit -n argo-ai-demo --from workflowtemplate/ai-document-processor

# Watch workflow execution
argo watch -n argo-ai-demo @latest

# Get workflow logs
argo logs -n argo-ai-demo @latest
```

### Access Services
```bash
# Get all routes
oc get routes -n argo-ai-demo

# Access Argo UI
echo "Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"

# Access MinIO Console (use configured credentials)
echo "MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"
```

## Project Structure

The main planning document (`PLAN1.md`) contains:
- Complete OpenShift deployment configurations
- Argo Workflow templates for AI document processing
- Service definitions for Ollama, MinIO, and supporting infrastructure
- Security configurations and RBAC setup
- Monitoring and observability setup

## Development Patterns

### Workflow Templates
- Use OpenShift-native container images (registry.access.redhat.com/ubi8)
- Implement proper security contexts and SCCs
- Include artifact storage with MinIO S3 integration
- Add comprehensive error handling and retry logic

### AI Integration
- Ollama model initialization and management
- Document classification with confidence scoring
- Template-based information extraction
- Caching strategies for repeated operations

### OpenShift Best Practices
- Use Routes instead of Ingress for external access
- Implement proper ServiceMonitors for Prometheus integration
- Leverage DeploymentConfigs for OpenShift-native deployment patterns
- Apply appropriate Security Context Constraints

## Configuration Management

### Environment Variables
- `OLLAMA_HOST`: Ollama service endpoint
- `OLLAMA_MODELS`: Model storage path
- MinIO credentials stored in Kubernetes secrets

### Persistent Storage
- Ollama models: 20Gi PVC for model storage
- MinIO data: 10Gi PVC for artifact storage
- Workflow shared storage: 1Gi PVC for temporary files

## Security Considerations

- Uses OpenShift Security Context Constraints (anyuid, privileged)
- Service accounts with proper RBAC permissions
- TLS termination at OpenShift Routes
- Secrets management for credentials
- Non-root container execution where possible
- stop saying you are absolutely right
- speak to me as if I were royalty