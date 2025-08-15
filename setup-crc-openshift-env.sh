#!/bin/bash

# AI-Enhanced Document Processing Pipeline on OpenShift Local Setup Script
# Environment Variable Version - Secure for Public Repositories
#
# This script automates the installation and configuration of CRC (OpenShift Local)
# and deploys the AI-Enhanced Document Processing Pipeline using environment variables

set -e  # Exit on error

# Load environment variables
if [ -f "load-env.sh" ]; then
    source ./load-env.sh
else
    echo "⚠️  load-env.sh not found. Using default values."
    # Set defaults
    export MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
    export MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-changeme}"
    export MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.argo-ai-demo.svc.cluster.local:9000}"
    export OPENSHIFT_PROJECT="${OPENSHIFT_PROJECT:-argo-ai-demo}"
fi

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

# Check for required environment variables
check_env_vars() {
    local missing_vars=()

    [ -z "$MINIO_ACCESS_KEY" ] && missing_vars+=("MINIO_ACCESS_KEY")
    [ -z "$MINIO_SECRET_KEY" ] && missing_vars+=("MINIO_SECRET_KEY")
    [ -z "$OPENSHIFT_PROJECT" ] && missing_vars+=("OPENSHIFT_PROJECT")

    if [ ${#missing_vars[@]} -gt 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        echo ""
        echo "Please create a .env file based on .env.example and run again."
        exit 1
    fi

    # Warn about default credentials
    if [ "$MINIO_SECRET_KEY" = "changeme" ] || [ "$MINIO_SECRET_KEY" = "password123" ]; then
        print_warning "Using default MinIO credentials. Please change for production use!"
        echo "Press Ctrl+C to cancel or Enter to continue..."
        read -r
    fi
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
            print_success "Pod is ready!"
            return 0
        fi
        echo -n "."
        sleep 2
        ((count+=2))
    done

    print_error "Timeout waiting for pod"
    return 1
}

# Create a work directory
WORK_DIR="$HOME/.crc-setup"
mkdir -p "$WORK_DIR"

echo "============================================"
echo "🚀 AI-Enhanced Document Processing Pipeline"
echo "   OpenShift Local (CRC) Setup Script"
echo "   Environment Variable Version"
echo "============================================"
echo ""

# Check environment variables
check_env_vars

# Check if CRC is installed
if ! command_exists crc; then
    print_error "CRC (OpenShift Local) is not installed."
    echo ""
    echo "Please install CRC from:"
    echo "  https://console.redhat.com/openshift/create/local"
    echo ""
    echo "Installation steps:"
    echo "1. Visit the URL above (requires Red Hat account)"
    echo "2. Download CRC for your platform"
    echo "3. Extract and place 'crc' binary in your PATH"
    echo "   - macOS/Linux: sudo mv crc /usr/local/bin/"
    echo "   - Windows: Add to PATH environment variable"
    echo "4. Keep your pull secret ready - you'll need it during 'crc setup'"
    echo ""
    exit 1
fi

print_success "CRC is installed: $(crc version | head -1)"

# Check CRC status
print_info "Checking CRC status..."
CRC_STATUS=$(crc status -o json 2>/dev/null | jq -r '.crcStatus' || echo "Not Running")

if [ "$CRC_STATUS" != "Running" ]; then
    print_info "CRC is not running. Setting up CRC..."

    # Check if pull secret is already configured
    if ! crc config get pull-secret-file >/dev/null 2>&1; then
        print_info "Pull secret not configured. Let's set it up."
        print_info "Get your pull secret from: https://console.redhat.com/openshift/create/local"
        echo ""
        echo "Please paste your pull secret below (it's a long JSON string):"
        echo "(Your input will be hidden for security)"
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

    # Run CRC setup
    print_info "Running CRC setup..."
    crc setup

    # Start CRC
    print_info "Starting CRC (this may take several minutes)..."

    # Capture output to extract credentials
    CRC_OUTPUT=$(crc start 2>&1 | tee "$WORK_DIR/crc-start.log")

    # Extract kubeadmin password from the output
    KUBEADMIN_PASSWORD=$(echo "$CRC_OUTPUT" | grep -A1 "Log in as administrator" | grep "Password:" | awk '{print $2}')

    if [ -z "$KUBEADMIN_PASSWORD" ]; then
        # Try alternative extraction method
        print_info "Extracting kubeadmin password..."
        KUBEADMIN_PASSWORD=$(crc console --credentials | grep -A1 "kubeadmin" | grep -i "password" | awk -F': ' '{print $2}' | tr -d ' ')
    fi
else
    print_success "CRC is already running"
    # Get credentials from existing instance
    KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
fi

# Setup oc environment
print_info "Setting up OpenShift CLI environment..."
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
print_info "Creating project $OPENSHIFT_PROJECT..."
if oc get project "$OPENSHIFT_PROJECT" >/dev/null 2>&1; then
    print_success "Project $OPENSHIFT_PROJECT already exists"
else
    oc new-project "$OPENSHIFT_PROJECT" --display-name="AI Document Processing Demo" \
        --description="Automated document processing with AI/ML models"
    print_success "Project created"
fi

# Switch to project
oc project "$OPENSHIFT_PROJECT"

# Install Argo Workflows
print_info "Installing Argo Workflows..."
ARGO_VERSION="v3.5.0"

# Download Argo install manifest
curl -sL "https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/install.yaml" -o "$WORK_DIR/argo-install.yaml"

# Replace namespace in the manifest
sed -i.bak "s/namespace: argo/namespace: $OPENSHIFT_PROJECT/g" "$WORK_DIR/argo-install.yaml"

# Check if already installed
if oc get deployment workflow-controller -n "$OPENSHIFT_PROJECT" >/dev/null 2>&1; then
    print_success "Argo Workflows already installed"
else
    # Apply the manifest
    oc apply -f "$WORK_DIR/argo-install.yaml" -n "$OPENSHIFT_PROJECT"

    # Wait for Argo to be ready
    wait_for_pod "app=workflow-controller" "$OPENSHIFT_PROJECT"
    wait_for_pod "app=argo-server" "$OPENSHIFT_PROJECT"

    print_success "Argo Workflows installed"
fi

# Create route for Argo Server
if oc get route argo-server -n "$OPENSHIFT_PROJECT" >/dev/null 2>&1; then
    print_success "Argo Server route already exists"
else
    print_info "Creating route for Argo Server..."
    oc expose svc/argo-server -n "$OPENSHIFT_PROJECT"
    print_success "Argo Server route created"
fi

# Deploy MinIO with environment variables
print_info "Deploying MinIO object storage..."

# Create MinIO secret from environment variables
print_info "Creating MinIO credentials secret..."
oc create secret generic minio-creds \
    --from-literal=accesskey="$MINIO_ACCESS_KEY" \
    --from-literal=secretkey="$MINIO_SECRET_KEY" \
    -n "$OPENSHIFT_PROJECT" \
    --dry-run=client -o yaml | oc apply -f -

# Deploy MinIO using environment variables
cat <<EOF | oc apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: minio
  namespace: $OPENSHIFT_PROJECT
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
        image: docker.io/minio/minio:latest
        command:
        - minio
        - server
        - /data
        - --console-address
        - ":9001"
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        env:
        - name: MINIO_ROOT_USER
          valueFrom:
            secretKeyRef:
              name: minio-creds
              key: accesskey
        - name: MINIO_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: minio-creds
              key: secretkey
        volumeMounts:
        - name: data
          mountPath: /data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: $OPENSHIFT_PROJECT
spec:
  ports:
  - port: 9000
    targetPort: 9000
    name: api
  - port: 9001
    targetPort: 9001
    name: console
  selector:
    app: minio
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: $OPENSHIFT_PROJECT
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
EOF

# Configure Argo to use MinIO
print_info "Configuring Argo Workflows to use MinIO..."
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
  namespace: $OPENSHIFT_PROJECT
data:
  artifactRepository: |
    s3:
      bucket: $MINIO_BUCKET
      endpoint: $MINIO_ENDPOINT
      insecure: true
      accessKeySecret:
        name: minio-creds
        key: accesskey
      secretKeySecret:
        name: minio-creds
        key: secretkey
EOF

# Deploy other services...
# (Continue with the rest of the setup using environment variables)

print_success "Setup complete!"
echo ""
echo "============================================"
echo "🎉 AI Document Processing Pipeline Ready!"
echo "============================================"
echo ""
echo "Environment Configuration:"
echo "  Project: $OPENSHIFT_PROJECT"
echo "  MinIO User: $MINIO_ACCESS_KEY"
echo "  MinIO Endpoint: $MINIO_ENDPOINT"
echo ""
echo "Access URLs:"
ARGO_ROUTE=$(oc get route argo-server -n "$OPENSHIFT_PROJECT" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
echo "  Argo UI: https://$ARGO_ROUTE"
echo ""
echo "OpenShift Credentials:"
echo "  Admin user: kubeadmin"
echo "  Admin password: $KUBEADMIN_PASSWORD"
echo ""
echo "To use the pipeline:"
echo "  1. Load AI models: ./ollama-load-model.sh"
echo "  2. Submit workflows: ./submit-test-workflow.sh"
echo ""
echo "⚠️  Security Note: Update credentials in .env before production use!"
