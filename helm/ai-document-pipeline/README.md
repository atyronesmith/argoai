# AI Document Processing Pipeline Helm Chart

This Helm chart deploys an AI-Enhanced Document Processing Pipeline on OpenShift, featuring:
- Argo Workflows for orchestration
- Ollama for AI model serving
- MinIO for object storage
- Pre-configured workflow templates
- Smart Inbox with AI document classification
- Argo Events for event-driven automation

## Prerequisites

- OpenShift cluster (or CRC for local development)
- Helm 3.x installed
- `oc` CLI configured and logged in
- Cluster admin privileges (for CRD installation)

## Installation

### CRD Installation

This Helm chart automatically installs the required Argo Workflows and Argo Events CRDs by default. The CRDs are installed using a pre-install hook that runs before the main chart resources.

**Note**: CRD installation requires cluster-admin privileges. If you don't have these privileges, you can disable automatic CRD installation and ask your cluster administrator to install them manually:

```bash
# Install without CRDs (if already installed or no cluster-admin access)
helm install ai-pipeline ./helm/ai-document-pipeline \
  --set crds.install=false
```

For manual CRD installation, see the [CRD README](./crds/README.md).

### Quick Start

1. **Add environment-specific values**:
   ```bash
   # Copy the example environment file
   cp ../.env.example ../.env
   # Edit with your MinIO credentials
   ```

2. **Install the chart**:
   ```bash
   # Install with default values
   helm install ai-pipeline ./helm/ai-document-pipeline

   # Install with custom namespace
   helm install ai-pipeline ./helm/ai-document-pipeline \
     --create-namespace \
     --namespace ai-demo

   # Install with development values
   helm install ai-pipeline ./helm/ai-document-pipeline \
     -f ./helm/ai-document-pipeline/values-dev.yaml
   ```

### Production Installation

1. **Create a values override file**:
   ```yaml
   # values-prod-override.yaml
   global:
     domain: apps.your-cluster.com

   minio:
     auth:
       existingSecret: minio-prod-secret
     persistence:
       size: 100Gi

   ollama:
     persistence:
       size: 200Gi
     resources:
       limits:
         memory: 16Gi
   ```

2. **Create secrets**:
   ```bash
   # Create MinIO secret
   kubectl create secret generic minio-prod-secret \
     --from-literal=root-user=your-admin-user \
     --from-literal=root-password=your-secure-password \
     -n argo-ai-demo
   ```

3. **Install**:
   ```bash
   helm install ai-pipeline ./helm/ai-document-pipeline \
     -f ./helm/ai-document-pipeline/values-prod.yaml \
     -f values-prod-override.yaml
   ```

## Smart Inbox Feature

The Smart Inbox provides an intelligent document intake system powered by AI:

### How It Works

1. **Single Drop Point**: Users drop ALL documents into `documents/inbox/`
2. **AI Classification**: Ollama analyzes and categorizes each document
3. **Smart Filing**: Documents are automatically moved to organized folders
4. **Automated Processing**: Type-specific workflows trigger automatically

### Document Types

| Type | Description | Example Keywords |
|------|-------------|------------------|
| Invoice | Bills, payment requests | invoice, bill, payment, due date |
| Contract | Legal agreements | agreement, contract, terms, parties |
| Technical | Documentation, specs | API, documentation, specification |
| Correspondence | Letters, emails | memo, meeting, email, notice |

### Priority Detection

Documents are analyzed for urgency indicators:
- **Urgent**: overdue, immediate, critical, deadline, urgent
- **Normal**: standard processing time

### Usage Example

```bash
# 1. Configure MinIO client
mc alias set myminio http://minio-route admin <password>

# 2. Create inbox (one-time setup)
mc mb myminio/documents/inbox

# 3. Drop any document
mc cp important-doc.pdf myminio/documents/inbox/

# 4. Watch it get processed
kubectl get workflows -l source=inbox-sensor -w

# 5. Check organized location
mc ls myminio/documents/invoices/urgent/
# Shows: 20240115_143022_important-doc.pdf
```

### Configuration

Enable the Smart Inbox in your values:

```yaml
argoEvents:
  enabled: true
  inbox:
    enabled: true
    bucket: "documents"
    prefix: "inbox/"
    folders:
      invoices: "invoices"
      contracts: "contracts"
      technical: "technical"
      correspondence: "correspondence"
```

## Configuration

### Important Notes

- **CRD Installation**: The chart installs CRDs by default using a pre-install hook. Set `crds.install=false` if CRDs are already installed or if you lack cluster-admin privileges.
- **Argo Server Authentication**: The chart sets `--auth-mode=server` by default to disable client authentication. This allows the readiness probe to succeed and makes the UI accessible without credentials. For production use, consider implementing proper authentication.

### Key Values

| Parameter | Description | Default |
|-----------|-------------|---------|
| `crds.install` | Install CRDs with the chart | `true` |
| `crds.keep` | Keep CRDs on chart uninstall | `true` |
| `global.namespace` | Target namespace | `argo-ai-demo` |
| `global.domain` | Cluster domain for routes | `apps-crc.testing` |
| `argo.enabled` | Deploy Argo Workflows | `true` |
| `minio.enabled` | Deploy MinIO | `true` |
| `minio.auth.rootUser` | MinIO admin user | `admin` |
| `minio.auth.rootPassword` | MinIO admin password | `changeme` |
| `ollama.enabled` | Deploy Ollama | `true` |
| `ollama.models` | AI models to preload | `["llama3.2:3b", "mistral:7b"]` |

See `values.yaml` for full configuration options.

### Using External Services

To use existing services instead of deploying new ones:

```yaml
# Disable internal MinIO, use external
minio:
  enabled: false

# Configure Argo to use external MinIO
argo:
  config:
    artifactRepository:
      s3:
        endpoint: external-minio.example.com
        bucket: my-bucket
        # ... credentials
```

## Upgrading

```bash
# Upgrade with new values
helm upgrade ai-pipeline ./helm/ai-document-pipeline \
  -f custom-values.yaml

# Upgrade and reload models
helm upgrade ai-pipeline ./helm/ai-document-pipeline \
  --set ollama.models="{llama3.2:3b,mistral:7b,llama2:13b}"
```

## Uninstallation

```bash
# Uninstall but keep persistent data
helm uninstall ai-pipeline

# Complete cleanup including PVCs
helm uninstall ai-pipeline
kubectl delete pvc -l app.kubernetes.io/instance=ai-pipeline -n argo-ai-demo
```

## Accessing Services

After installation, get the service URLs:

```bash
# Get all routes
oc get routes -n argo-ai-demo

# Get specific service URL
oc get route argo-server -n argo-ai-demo -o jsonpath='https://{.spec.host}'
```

## Submitting Workflows

1. **Via Argo CLI**:
   ```bash
   # Port-forward to Argo server
   oc port-forward svc/argo-server 2746:2746 -n argo-ai-demo

   # Submit workflow
   argo submit --from workflowtemplate/ai-document-processor \
     -p doc-url="https://example.com/document.pdf" \
     -p model="llama3.2:3b"
   ```

2. **Via kubectl**:
   ```bash
   kubectl create -n argo-ai-demo -f - <<EOF
   apiVersion: argoproj.io/v1alpha1
   kind: Workflow
   metadata:
     generateName: ai-doc-test-
   spec:
     workflowTemplateRef:
       name: ai-document-processor
     arguments:
       parameters:
       - name: doc-url
         value: "https://example.com/document.pdf"
   EOF
   ```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n argo-ai-demo
kubectl describe pod <pod-name> -n argo-ai-demo
kubectl logs <pod-name> -n argo-ai-demo
```

### Model loading issues
```bash
# Check model loading job
kubectl logs -n argo-ai-demo -l app.kubernetes.io/component=ollama-models

# Manually trigger model loading
kubectl exec -n argo-ai-demo deploy/ollama -- ollama pull llama3.2:3b
```

### Storage issues
```bash
# Check PVC status
kubectl get pvc -n argo-ai-demo

# Check MinIO
kubectl exec -n argo-ai-demo deploy/minio -- df -h /data
```

## Development

### Testing changes
```bash
# Dry run
helm install ai-pipeline ./helm/ai-document-pipeline --dry-run

# Template generation
helm template ai-pipeline ./helm/ai-document-pipeline

# Lint chart
helm lint ./helm/ai-document-pipeline
```

### Adding new components
1. Create templates in appropriate directory
2. Add configuration to `values.yaml`
3. Update `Chart.yaml` version
4. Test with `helm template`

## License

[Your License]
