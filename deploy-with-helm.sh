#!/bin/bash

# Deploy AI Document Processing Pipeline using Helm
# This script assumes CRC is already running

set -e

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

echo "============================================"
echo "🚀 AI Document Pipeline Helm Deployment"
echo "============================================"
echo ""

# Check if Helm is installed
if ! command -v helm &> /dev/null; then
    print_error "Helm is not installed!"
    echo "Please install Helm from: https://helm.sh/docs/intro/install/"
    exit 1
fi

print_success "Helm is installed: $(helm version --short)"

# Check if logged into OpenShift
if ! oc whoami &> /dev/null; then
    print_error "Not logged into OpenShift!"
    echo ""
    echo "Please login first:"
    echo "  source ~/.crc-credentials"
    echo "  oc login -u kubeadmin -p \$KUBEADMIN_PASSWORD https://api.crc.testing:6443 --insecure-skip-tls-verify=true"
    exit 1
fi

CURRENT_USER=$(oc whoami)
print_success "Logged in as: $CURRENT_USER"

# Load environment variables if available
if [ -f .env ]; then
    print_info "Loading environment variables from .env"
    set -a
    source .env
    set +a
else
    print_warning "No .env file found. Using default values."
    print_info "Copy .env.example to .env and customize for your environment."
fi

# Set deployment options
RELEASE_NAME="${HELM_RELEASE_NAME:-ai-pipeline}"
NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-demo}"
VALUES_FILE="${HELM_VALUES_FILE:-}"
ENVIRONMENT="${DEPLOY_ENV:-dev}"

# Choose values file based on environment
if [ -z "$VALUES_FILE" ]; then
    case "$ENVIRONMENT" in
        dev)
            VALUES_FILE="helm/ai-document-pipeline/values-dev.yaml"
            ;;
        prod)
            VALUES_FILE="helm/ai-document-pipeline/values-prod.yaml"
            ;;
        *)
            VALUES_FILE=""
            ;;
    esac
fi

print_info "Deployment configuration:"
echo "  Release name: $RELEASE_NAME"
echo "  Namespace: $NAMESPACE"
echo "  Environment: $ENVIRONMENT"
[ -n "$VALUES_FILE" ] && echo "  Values file: $VALUES_FILE"

# Note: CRDs will be automatically installed by Helm if crds.install=true (default)

# Create namespace if it doesn't exist
if ! oc get namespace "$NAMESPACE" &> /dev/null; then
    print_info "Creating namespace: $NAMESPACE"
    oc create namespace "$NAMESPACE"
    oc label namespace "$NAMESPACE" \
        "openshift.io/cluster-monitoring=true" \
        "app.kubernetes.io/name=ai-document-pipeline" || true
fi

# Build Helm command
HELM_CMD="helm upgrade --install $RELEASE_NAME ./helm/ai-document-pipeline"
HELM_CMD="$HELM_CMD --namespace $NAMESPACE"
HELM_CMD="$HELM_CMD --create-namespace"
HELM_CMD="$HELM_CMD --timeout 10m"
HELM_CMD="$HELM_CMD --wait"

# Add values file if specified
[ -n "$VALUES_FILE" ] && [ -f "$VALUES_FILE" ] && HELM_CMD="$HELM_CMD -f $VALUES_FILE"

# Add MinIO credentials from environment if available
if [ -n "$MINIO_ACCESS_KEY" ] && [ -n "$MINIO_SECRET_KEY" ]; then
    print_info "Using MinIO credentials from environment"
    HELM_CMD="$HELM_CMD --set minio.auth.rootUser=$MINIO_ACCESS_KEY"
    HELM_CMD="$HELM_CMD --set minio.auth.rootPassword=$MINIO_SECRET_KEY"
fi

# Dry run first (note: CRDs will be installed during actual deployment)
print_info "Performing dry run..."
print_warning "Note: CRD-related errors during dry-run are expected if CRDs aren't installed yet."
if $HELM_CMD --dry-run > /tmp/helm-dry-run.log 2>&1; then
    print_success "Dry run successful!"
else
    # Check if it's just CRD errors
    if grep -q "ensure CRDs are installed first" /tmp/helm-dry-run.log; then
        print_warning "Dry run shows missing CRDs - they will be installed during deployment"
    else
        print_error "Dry run failed! Check your configuration."
        cat /tmp/helm-dry-run.log
        exit 1
    fi
fi

# Confirm deployment
echo ""
read -p "Deploy AI Document Pipeline to namespace '$NAMESPACE'? (y/N) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Deployment cancelled"
    exit 0
fi

# Deploy
print_info "Deploying AI Document Pipeline..."
if $HELM_CMD; then
    print_success "Deployment successful!"
else
    print_error "Deployment failed!"
    exit 1
fi

# Wait for pods to be ready
print_info "Waiting for pods to be ready..."
oc wait --for=condition=Ready pods --all -n "$NAMESPACE" --timeout=300s || true

# Get service URLs
echo ""
echo "============================================"
echo "✅ Deployment Complete!"
echo "============================================"
echo ""
echo "Service URLs:"
ARGO_ROUTE=$(oc get route argo-server -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
MINIO_ROUTE=$(oc get route minio-console -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
OLLAMA_ROUTE=$(oc get route ollama -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")

echo "  Argo Workflows: https://$ARGO_ROUTE"
echo "  MinIO Console: https://$MINIO_ROUTE"
echo "  Ollama API: https://$OLLAMA_ROUTE"
echo ""
echo "To check deployment status:"
echo "  helm status $RELEASE_NAME -n $NAMESPACE"
echo ""
echo "To view pods:"
echo "  oc get pods -n $NAMESPACE"
echo ""
echo "To submit a test workflow:"
echo "  oc exec -n $NAMESPACE deploy/argo-server -- argo submit --from workflowtemplate/ai-document-processor --watch"
echo ""
print_success "AI Document Pipeline is ready!"
