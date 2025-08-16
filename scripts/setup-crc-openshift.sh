#!/bin/bash

# AI-Enhanced Document Processing Pipeline on OpenShift Local Setup Script
# Based on IMPLEMENTATION_PLAN.md
#
# ⚠️  DEPRECATED: This script contains hardcoded credentials for demo purposes.
# Please use setup-crc-openshift-env.sh which uses environment variables instead.
#
# This script automates the installation and configuration of CRC (OpenShift Local)
# and deploys the AI-Enhanced Document Processing Pipeline

set -e  # Exit on error

echo "⚠️  WARNING: This script uses hardcoded demo credentials."
echo "For production or public use, please use setup-crc-openshift-env.sh instead."
echo "Press Ctrl+C to cancel or Enter to continue..."
read -r

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pod to be ready
wait_for_pod() {
    local pod_label=$1
    local namespace=$2
    local timeout=${3:-300}  # Default 5 minutes

    print_info "Waiting for pod with label $pod_label to be ready in namespace $namespace..."

    local count=0
    while [ $count -lt $timeout ]; do
        if oc get pods -n "$namespace" -l "$pod_label" 2>/dev/null | grep -q "Running"; then
            print_success "Pod with label $pod_label is running"
            return 0
        fi
        sleep 2
        ((count+=2))
        echo -n "."
    done

    print_error "Timeout waiting for pod with label $pod_label"
    return 1
}

# Function to create directory if it doesn't exist
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        print_info "Created directory: $1"
    fi
}

# Main script starts here
print_info "Starting AI-Enhanced Document Processing Pipeline Setup on OpenShift Local"
echo "=================================================================="

# Check prerequisites
print_info "Checking prerequisites..."

# Check if running on macOS or Linux
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS_TYPE="macos"
    print_info "Detected macOS"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS_TYPE="linux"
    print_info "Detected Linux"
else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

# Create working directory
WORK_DIR="$HOME/argoai-openshift-setup"
ensure_dir "$WORK_DIR"
cd "$WORK_DIR"

# Phase 1: CRC Installation and Setup
print_info "Phase 1: OpenShift Local (CRC) Setup"
echo "------------------------------------"

# Check if CRC is already installed
if ! command_exists crc; then
    print_warning "CRC (OpenShift Local) not found. Please install it first:"
    echo ""
    echo "Installation steps:"
    echo "1. Create a free Red Hat Developer account (if you don't have one):"
    echo "   https://developers.redhat.com/register"
    echo ""
    echo "2. Download OpenShift Local (CRC) from:"
    echo "   https://console.redhat.com/openshift/create/local"
    echo "   - Login with your Red Hat account"
    echo "   - Select your operating system (macOS, Linux, or Windows)"
    echo "   - Download the installer package"
    echo "   - IMPORTANT: Also download your pull secret from the same page"
    echo ""
    echo "3. Install CRC:"
    echo "   - macOS/Linux: Extract archive and move 'crc' binary to /usr/local/bin/"
    echo "   - Windows: Run the installer"
    echo ""
    echo "4. Keep your pull secret ready - you'll need it during 'crc setup'"
    echo ""
    read -p "Press Enter once CRC is installed to continue..."

    if ! command_exists crc; then
        print_error "CRC still not found in PATH. Please install it and try again."
        exit 1
    fi
fi

print_success "CRC is installed: $(crc version)"

# Check if pull secret is already configured
if ! crc config get pull-secret-file >/dev/null 2>&1; then
    print_info "Pull secret not configured. Let's set it up."
    print_info "Get your pull secret from: https://console.redhat.com/openshift/create/local"
    echo ""
    echo "Please paste your pull secret below (it's a long JSON string):"
    echo "Note: The input will be hidden for security"
    read -s -r PULL_SECRET
    echo ""

    # Save pull secret to temporary file
    PULL_SECRET_FILE="$WORK_DIR/pull-secret.txt"
    echo "$PULL_SECRET" > "$PULL_SECRET_FILE"

    # Configure CRC with pull secret
    print_info "Configuring CRC with pull secret..."
    crc config set pull-secret-file "$PULL_SECRET_FILE"

    # Clean up pull secret file for security
    rm -f "$PULL_SECRET_FILE"
fi

# Setup CRC
print_info "Setting up CRC (this may take several minutes)..."
crc setup

# Check CRC status
if crc status 2>/dev/null | grep -q "Running"; then
    print_info "CRC is already running"
    # Get credentials from existing instance
    KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
else
    # Start CRC with recommended resources
    print_info "Starting CRC with enhanced resources..."
    print_warning "This requires at least 16GB RAM and 60GB disk space"

    # Check if pull secret is configured for start
    if ! crc config get pull-secret-file >/dev/null 2>&1; then
        print_warning "Pull secret still not configured. CRC start will prompt for it."
    fi

    # Capture output to extract credentials
    CRC_OUTPUT=$(crc start --cpus 6 --memory 16384 --disk-size 60 2>&1 | tee /dev/tty)

    # Extract kubeadmin password from the output
    KUBEADMIN_PASSWORD=$(echo "$CRC_OUTPUT" | grep -A1 "Log in as administrator" | grep "Password:" | awk '{print $2}')

    if [ -z "$KUBEADMIN_PASSWORD" ]; then
        # Fallback to getting it from console command
        print_info "Extracting kubeadmin password..."
        KUBEADMIN_PASSWORD=$(crc console --credentials | grep -A1 "kubeadmin" | grep -i "password" | awk -F': ' '{print $2}' | tr -d ' ')
    fi
fi

# Setup environment
print_info "Setting up OpenShift client environment..."
eval $(crc oc-env)

# Login to OpenShift as kubeadmin for cluster-admin privileges
print_info "Logging into OpenShift as kubeadmin..."

# Ensure we have the kubeadmin password
if [ -z "$KUBEADMIN_PASSWORD" ]; then
    print_info "Extracting kubeadmin password..."
    KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
fi

if [ -z "$KUBEADMIN_PASSWORD" ]; then
    print_error "Failed to get kubeadmin password. Please check CRC status."
    exit 1
fi

print_info "Using kubeadmin password: ${KUBEADMIN_PASSWORD:0:6}..."  # Show first 6 chars for verification
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true

# Create project
print_info "Creating project argo-ai-demo..."
if oc get project argo-ai-demo >/dev/null 2>&1; then
    print_warning "Project argo-ai-demo already exists"
    oc project argo-ai-demo
else
    oc new-project argo-ai-demo
fi

# Configure security
print_info "Configuring security policies..."
oc adm policy add-scc-to-user anyuid -z default -n argo-ai-demo || true
oc adm policy add-scc-to-user privileged -z default -n argo-ai-demo || true

print_success "Phase 1 completed: OpenShift Local is running"

# Optional: Setup CRC Certificates
print_info "Certificate Setup (Optional)"
echo "--------------------------------"
echo "Would you like to import CRC certificates to your system?"
echo "This will allow browsers to trust HTTPS connections without warnings."
echo -n "Import certificates? (y/N): "
read -r IMPORT_CERTS

if [[ "$IMPORT_CERTS" =~ ^[Yy]$ ]]; then
    print_info "Running certificate setup..."
    if [ -f "./scripts/setup-crc-certificates.sh" ]; then
        ./scripts/setup-crc-certificates.sh
    else
        print_warning "Certificate setup script not found at ./scripts/setup-crc-certificates.sh"
        print_warning "You can run it manually later from the project root"
    fi
else
    print_info "Skipping certificate import"
    print_warning "You may see certificate warnings in your browser"
    echo "To import certificates later, run: ./scripts/setup-crc-certificates.sh"
fi

# Phase 2: Deploy Core Services
print_info "Phase 2: Deploying Core Services"
echo "--------------------------------"

# Install Argo Workflows
print_info "Installing Argo Workflows..."

# Check if Argo is already installed
if oc get deployment argo-server -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "Argo Workflows already installed, skipping..."
else
    curl -sL https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/install.yaml -o "$WORK_DIR/argo-install.yaml"

    # Replace the default namespace in Argo installation with our project
    print_info "Configuring Argo for argo-ai-demo namespace..."
    sed -i.bak 's/namespace: argo/namespace: argo-ai-demo/g' "$WORK_DIR/argo-install.yaml"

    # Apply Argo installation
    oc apply -f "$WORK_DIR/argo-install.yaml"
fi

# Wait for Argo pods to be ready
wait_for_pod "app=argo-server" "argo-ai-demo" 300

# Configure Argo Server Access
print_info "Configuring Argo Server access..."

# Check if route already exists
if oc get route argo-server -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "Argo Server route already exists, skipping..."
else
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
fi

# Patch Argo for easier access
print_info "Patching Argo Server for development access..."
oc patch deployment argo-server -n argo-ai-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server", "--secure=false"]}]' || true

# Fix readiness probe to use HTTP instead of HTTPS (matches insecure mode)
print_info "Fixing Argo Server readiness probe for insecure mode..."
oc patch deployment argo-server -n argo-ai-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]' || true

# Configure RBAC
print_info "Configuring RBAC for Argo..."
oc create rolebinding default-admin --clusterrole=admin --serviceaccount=argo-ai-demo:default -n argo-ai-demo || true
oc create rolebinding argo-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo -n argo-ai-demo || true
oc create rolebinding argo-server-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo-server -n argo-ai-demo || true

# Deploy Ollama Service
print_info "Deploying Ollama service..."

# Check if Ollama is already deployed
if oc get deployment ollama -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "Ollama already deployed, skipping..."
else
    cat > "$WORK_DIR/ollama-deployment.yaml" <<'EOF'
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
EOF

    oc apply -f "$WORK_DIR/ollama-deployment.yaml"
fi

# Deploy MinIO Service
print_info "Deploying MinIO service..."

# Check if MinIO is already deployed
if oc get deploymentconfig minio -n argo-ai-demo >/dev/null 2>&1 || oc get deployment minio -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "MinIO already deployed, skipping..."
else
    cat > "$WORK_DIR/minio-deployment.yaml" <<'EOF'
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
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: argo-ai-demo
spec:
  replicas: 1
  selector:
    matchLabels:
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
          value: admin
        - name: MINIO_ROOT_PASSWORD
          value: changeme  # CHANGE THIS in production
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
EOF

    oc apply -f "$WORK_DIR/minio-deployment.yaml"
fi

# Wait for services to be ready
wait_for_pod "app=ollama" "argo-ai-demo" 300
wait_for_pod "app=minio" "argo-ai-demo" 300

# Configure Argo-MinIO Integration
print_info "Configuring Argo-MinIO integration..."
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
  accesskey: admin
  secretkey: changeme  # CHANGE THIS in production
EOF

# Configure workflow controller to use MinIO
print_info "Configuring workflow controller for MinIO..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
  namespace: argo-ai-demo
data:
  artifactRepository: |
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
EOF

print_success "Phase 2 completed: Core services deployed"

# Phase 3: Create AI Workflow Template
print_info "Phase 3: Creating AI Document Processor Workflow Template"
echo "-------------------------------------------------------"

# Note: The actual workflow template is very long, so we'll create a placeholder
print_info "Creating AI workflow template..."

# Check if workflow template already exists
if oc get workflowtemplate ai-document-processor -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "AI workflow template already exists, skipping..."
else
    cat > "$WORK_DIR/ai-workflow-template.yaml" <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ai-document-processor
  namespace: argo-ai-demo
spec:
  entrypoint: main
  templates:
  - name: main
    dag:
      tasks:
      - name: download-doc
        template: download-document
        arguments:
          parameters:
          - name: url
            value: "{{workflow.parameters.doc-url}}"

      - name: process-doc
        template: process-with-ai
        dependencies: [download-doc]
        arguments:
          parameters:
          - name: model
            value: "{{workflow.parameters.model}}"
          artifacts:
          - name: document
            from: "{{tasks.download-doc.outputs.artifacts.document}}"

  - name: download-document
    inputs:
      parameters:
      - name: url
    outputs:
      artifacts:
      - name: document
        path: /tmp/document
    container:
      image: curlimages/curl:latest
      command: [sh, -c]
      args: ["curl -L '{{inputs.parameters.url}}' -o /tmp/document"]

  - name: process-with-ai
    inputs:
      parameters:
      - name: model
      artifacts:
      - name: document
        path: /tmp/document
    outputs:
      artifacts:
      - name: result
        path: /tmp/result.json
    container:
      image: python:3.9-slim
      command: [python, -c]
      args:
      - |
        import json
        import urllib.request
        import urllib.error

        # Read document
        with open('/tmp/document', 'r') as f:
            content = f.read()

        # Simulate AI processing (in real implementation, would call Ollama)
        result = {
            "status": "processed",
            "model": "{{inputs.parameters.model}}",
            "document_length": len(content),
            "summary": "Document processed successfully"
        }

        # Write result
        with open('/tmp/result.json', 'w') as f:
            json.dump(result, f, indent=2)

        print("Document processed successfully")
EOF

    oc apply -f "$WORK_DIR/ai-workflow-template.yaml"
fi

print_info "Note: This is a simplified workflow template. For the full template, refer to PLAN1.md lines 340-893"

print_success "Phase 3 completed: Workflow template created"

# Phase 4: Testing and Validation
print_info "Phase 4: Testing and Validation"
echo "-------------------------------"

# Create test document
print_info "Creating test document..."

# Check if sample-docs configmap already exists
if oc get configmap sample-docs -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "Sample docs configmap already exists, skipping..."
else
    cat > "$WORK_DIR/sample-invoice.txt" <<'EOF'
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

    oc create configmap sample-docs --from-file="$WORK_DIR/sample-invoice.txt" -n argo-ai-demo
fi

# Get service URLs
print_info "Getting service URLs..."
echo ""
echo "=== Service Access URLs ==="
echo "Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo "MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo "MinIO API: https://$(oc get route minio-api -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo "Ollama API: https://$(oc get route ollama -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo "OpenShift Console: $(crc console --url)"
echo ""
echo "MinIO Credentials:"
echo "  Username: admin"
echo "  Password: changeme (CHANGE THIS!)"
echo ""
echo "OpenShift Credentials:"
echo "  Admin user: kubeadmin"
echo "  Admin password: $KUBEADMIN_PASSWORD"
echo "  Developer user: developer"
echo "  Developer password: developer"
echo ""

# Verify deployments
print_info "Verifying deployments..."
echo ""
echo "=== Pod Status ==="
oc get pods -n argo-ai-demo

echo ""
echo "=== Routes ==="
oc get routes -n argo-ai-demo

# Create MinIO bucket
print_info "Creating MinIO bucket for artifacts..."
MINIO_ROUTE="https://$(oc get route minio-api -n argo-ai-demo -o jsonpath='{.spec.host}')"

# Install mc (MinIO client) if needed
if ! command_exists mc; then
    print_info "Installing MinIO client..."
    if [[ "$OS_TYPE" == "macos" ]]; then
        curl -O https://dl.min.io/client/mc/release/darwin-amd64/mc
    else
        curl -O https://dl.min.io/client/mc/release/linux-amd64/mc
    fi
    chmod +x mc
    sudo mv mc /usr/local/bin/
fi

# Configure mc and create bucket
mc alias set myminio "$MINIO_ROUTE" admin changeme --insecure || true  # CHANGE password in production
mc mb myminio/argo-artifacts --insecure || true

# Success summary
echo ""
echo "=================================================================="
print_success "Setup Complete!"
echo "=================================================================="
echo ""
echo "Next Steps:"
echo "1. Access the Argo UI to create and monitor workflows"
echo "2. Access the MinIO console to view stored artifacts"
echo "3. Submit a test workflow using:"
echo "   argo submit -n argo-ai-demo --from workflowtemplate/ai-document-processor"
echo ""
echo "To submit a workflow with parameters:"
echo "   oc create -f - <<EOF"
echo "   apiVersion: argoproj.io/v1alpha1"
echo "   kind: Workflow"
echo "   metadata:"
echo "     generateName: ai-doc-process-"
echo "     namespace: argo-ai-demo"
echo "   spec:"
echo "     workflowTemplateRef:"
echo "       name: ai-document-processor"
echo "     arguments:"
echo "       parameters:"
echo "       - name: doc-url"
echo "         value: \"https://example.com/document.txt\""
echo "       - name: model"
echo "         value: \"llama3.2:3b\""
echo "   EOF"
echo ""
echo "To stop CRC when done:"
echo "   crc stop"
echo ""
echo "To delete CRC completely:"
echo "   crc delete"
echo ""

# Save URLs to file for reference
cat > "$WORK_DIR/service-urls.txt" <<EOF
Service Access URLs (saved $(date))
==================================
Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')
MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')
MinIO API: https://$(oc get route minio-api -n argo-ai-demo -o jsonpath='{.spec.host}')
Ollama API: https://$(oc get route ollama -n argo-ai-demo -o jsonpath='{.spec.host}')
OpenShift Console: $(crc console --url)

MinIO Credentials:
  Username: admin
  Password: changeme (CHANGE THIS!)

Project: argo-ai-demo
EOF

print_info "Service URLs saved to: $WORK_DIR/service-urls.txt"
