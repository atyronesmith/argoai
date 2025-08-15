# Implementation Plan: AI-Enhanced Document Processing Pipeline on OpenShift

## Overview
This plan provides step-by-step instructions to implement the AI-Enhanced Document Processing Pipeline as described in PLAN1.md. Total estimated time: 45-60 minutes.

**Automated Setup Available**: A bash script `setup-crc-openshift.sh` is provided that automates the entire process. Simply run `./setup-crc-openshift.sh` and follow the prompts. The script handles pull secret configuration, service deployment, and all necessary configurations.

## Prerequisites
- Red Hat account (free developer account works) - create at https://developers.redhat.com/register
- Pull secret from Red Hat - obtain from https://console.redhat.com/openshift/create/local after logging in
- Access to download OpenShift Local (CRC) from https://console.redhat.com/openshift/create/local
- Minimum system requirements: 16GB RAM, 6 CPU cores, 60GB disk space
- `oc` CLI tool
- `argo` CLI tool

## Phase 1: OpenShift Local Setup (15 minutes)

### Automated Setup Option
A bash script `setup-crc-openshift.sh` is provided that automates the entire setup process:
```bash
./setup-crc-openshift.sh
```
The script will:
- Check for CRC installation and guide you if needed
- Prompt for your Red Hat pull secret (input is hidden for security)
- Configure CRC with your pull secret automatically
- Capture kubeadmin password from CRC output automatically
- Login as kubeadmin for cluster-admin privileges
- Install Argo Workflows in the argo-ai-demo namespace (skips if already installed)
- Deploy all services and configurations (idempotent - safe to run multiple times)
- Display service URLs and credentials upon completion

The script is idempotent and can be safely run multiple times. It will skip already completed steps.

### 1.1 Install and Start CRC (Manual Steps)
```bash
# 1. Download OpenShift Local (CRC) from https://console.redhat.com/openshift/create/local
#    - Requires Red Hat account login
#    - Select your operating system (Windows, macOS, or Linux)
#    - Download the installer package
#    - Also download your pull secret from the same page (you'll need it during setup)

# 2. Install CRC following platform-specific instructions
#    - macOS: Extract and move crc binary to /usr/local/bin/
#    - Linux: Extract and add to PATH
#    - Windows: Run the installer

# 3. Setup CRC (requires 9GB RAM minimum, recommend 16GB)
#    The automation script will prompt for your pull secret
#    Or manually: crc config set pull-secret-file <path-to-pull-secret-file>
crc setup

# Start CRC with increased resources
crc start --cpus 6 --memory 16384 --disk-size 60

# Get credentials and login
eval $(crc oc-env)
# Login as kubeadmin for cluster-admin privileges
# Get password: crc console --credentials
oc login -u kubeadmin -p <kubeadmin-password> https://api.crc.testing:6443
```

### 1.2 Create Project and Configure Security
```bash
# Create a new project (OpenShift's namespace)
oc new-project argo-ai-demo
oc project argo-ai-demo

# Add necessary permissions
oc adm policy add-scc-to-user anyuid -z default -n argo-ai-demo
oc adm policy add-scc-to-user privileged -z default -n argo-ai-demo
```

**Validation**: Verify project creation and permissions are applied correctly.

## Phase 2: Deploy Core Services (20 minutes)

### 2.1 Install Argo Workflows (5 minutes)
```bash
# Download and apply Argo installation
curl -sL https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/install.yaml -o argo-install.yaml
oc apply -n argo-ai-demo -f argo-install.yaml
```

### 2.2 Configure Argo Server Access (3 minutes)
```bash
# Create OpenShift Route for Argo Server UI
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: argo-server
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: argo-server
  port:
    targetPort: 2746
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Patch for easier access (dev only)
oc patch deployment argo-server -n argo-ai-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server", "--secure=false"]}]'

# Fix readiness probe to match insecure mode
oc patch deployment argo-server -n argo-ai-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]'
```

### 2.3 Configure RBAC for Argo (2 minutes)
```bash
# Grant Argo SA proper permissions
oc create rolebinding default-admin --clusterrole=admin --serviceaccount=argo-ai-demo:default -n argo-ai-demo
oc create rolebinding argo-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo -n argo-ai-demo
oc create rolebinding argo-server-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo-server -n argo-ai-demo
```

### 2.4 Deploy Ollama Service (5 minutes)
Create file: `ollama-deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: argo-ai-demo
  labels:
    app: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      serviceAccountName: default
      containers:
      - name: ollama
        image: docker.io/ollama/ollama:latest
        ports:
        - containerPort: 11434
          protocol: TCP
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: OLLAMA_MODELS
          value: "/models"
        volumeMounts:
        - name: ollama-models
          mountPath: /models
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
        securityContext:
          runAsNonRoot: false
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      volumes:
      - name: ollama-models
        persistentVolumeClaim:
          claimName: ollama-models-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models-pvc
  namespace: argo-ai-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-service
  namespace: argo-ai-demo
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
    protocol: TCP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ollama
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: ollama-service
  port:
    targetPort: 11434
  tls:
    termination: edge
```

```bash
oc apply -f ollama-deployment.yaml
```

### 2.5 Deploy MinIO Service (5 minutes)
Create file: `minio-deployment.yaml`
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: argo-ai-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: minio
  namespace: argo-ai-demo
spec:
  replicas: 1
  selector:
    app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: <your-minio-user>
        - name: MINIO_ROOT_PASSWORD
          value: <your-minio-password>
        - name: MINIO_PROMETHEUS_AUTH_TYPE
          value: public
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: argo-ai-demo
spec:
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: minio
  port:
    targetPort: 9001
  tls:
    termination: edge
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-api
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: minio
  port:
    targetPort: 9000
  tls:
    termination: edge
```

```bash
oc apply -f minio-deployment.yaml
```

### 2.6 Configure Argo-MinIO Integration
```bash
# Create artifact repository config
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: artifact-repositories
  namespace: argo-ai-demo
data:
  default-v1: |
    s3:
      bucket: argo-artifacts
      endpoint: minio.argo-ai-demo.svc.cluster.local:9000
      insecure: true
      accessKeySecret:
        name: minio-creds
        key: accesskey
      secretKeySecret:
        name: minio-creds
        key: secretkey
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-creds
  namespace: argo-ai-demo
type: Opaque
stringData:
  accesskey: <base64-encoded-minio-user>
  secretkey: <base64-encoded-minio-password>
EOF

# Configure workflow controller to use MinIO
oc patch configmap workflow-controller-configmap -n argo-ai-demo \
  --patch '{"data":{"artifactRepository":"|  s3:\n    bucket: argo-artifacts\n    endpoint: minio.argo-ai-demo.svc.cluster.local:9000\n    insecure: true\n    accessKeySecret:\n      name: minio-creds\n      key: accesskey\n    secretKeySecret:\n      name: minio-creds\n      key: secretkey"}}'
```

**Validation**: Verify all pods are running and routes are accessible.

## Phase 3: Deploy AI Workflow Template (10 minutes)

### 3.1 Create AI Document Processor Workflow
Create file: `ai-workflow-template.yaml` with the complete WorkflowTemplate from PLAN1.md (lines 340-893).

```bash
oc apply -f ai-workflow-template.yaml
```

**Validation**: Verify WorkflowTemplate is created successfully.

## Phase 4: Testing and Validation (10 minutes)

### 4.1 Create Test Documents
```bash
# Create a sample invoice document
cat <<EOF > /tmp/sample-invoice.txt
INVOICE #2024-1234
Date: January 15, 2024
Due Date: February 15, 2024

Bill To:
Acme Corporation
123 Business Street
San Francisco, CA 94105

From:
Tech Solutions Inc.
456 Innovation Drive
San Jose, CA 95110

Description                     Quantity    Rate      Amount
Cloud Infrastructure Setup           1      5000.00   5000.00
Monthly Hosting Services            3      1500.00   4500.00
Security Audit                      1      2500.00   2500.00
Technical Support                   10       150.00   1500.00

Subtotal: 13,500.00
Tax (8.5%): 1,147.50
TOTAL DUE: 14,647.50

Payment Terms: Net 30
Please remit payment to account ending in 4532
EOF

# Upload to accessible location or create configmap
oc create configmap sample-docs --from-file=/tmp/sample-invoice.txt -n argo-ai-demo
```

### 4.2 Execute Test Workflow
```bash
# Submit workflow
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
      value: "https://raw.githubusercontent.com/your-repo/sample-invoice.txt"
    - name: model
      value: "llama3.2:3b"
EOF

# Watch the workflow
argo watch -n argo-ai-demo @latest

# Get workflow logs
argo logs -n argo-ai-demo @latest
```

### 4.3 Access Services and Verify
```bash
# Get all routes
oc get routes -n argo-ai-demo

# Access Argo UI
echo "Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"

# Access MinIO Console
echo "MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"

# OpenShift Console
echo "OpenShift Console: $(crc console --url)"
```

## Phase 5: Optional Monitoring Setup (5 minutes)

### 5.1 Add ServiceMonitor for Prometheus
```bash
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ai-workflow-metrics
  namespace: argo-ai-demo
spec:
  selector:
    matchLabels:
      app: ai-workflow
  endpoints:
  - port: metrics
    interval: 30s
EOF
```

## Troubleshooting Guide

### Common Issues and Solutions

1. **CRC Resource Issues**
   - Ensure minimum 16GB RAM available
   - Increase disk space if needed: `crc config set disk-size 80`

2. **Pod Security Issues**
   - Verify SCC assignments: `oc get scc anyuid -o yaml`
   - Check service account permissions

3. **Ollama Model Loading**
   - Monitor pod logs: `oc logs deployment/ollama -f`
   - Verify PVC mount: `oc describe pvc ollama-models-pvc`

4. **MinIO Connectivity**
   - Test bucket creation via console
   - Verify service endpoints: `oc get svc minio`

5. **Workflow Failures**
   - Check artifact storage configuration
   - Verify RBAC permissions for workflow service accounts

## Demo Scenarios

Once implementation is complete, demonstrate these scenarios:

1. **Invoice Processing**: Upload urgent invoice, show automatic classification and priority routing
2. **Contract Analysis**: Process legal contract, demonstrate information extraction
3. **Batch Processing**: Submit multiple documents simultaneously
4. **Model Comparison**: Run same document through different LLM models

## Success Criteria

- [ ] OpenShift Local running with all services deployed
- [ ] Argo Workflows UI accessible and functional
- [ ] Ollama service responding to API calls
- [ ] MinIO console accessible with artifact storage working
- [ ] AI document processing workflow executes successfully
- [ ] Generated reports accessible via artifacts
- [ ] All OpenShift Routes functioning properly
- [ ] Monitoring integration operational (optional)

## Next Steps

After successful implementation:
1. Explore additional document types and processing templates
2. Implement custom operators for automated deployment
3. Add advanced monitoring and alerting
4. Scale services for production workloads
5. Integrate with external systems (databases, notification services)