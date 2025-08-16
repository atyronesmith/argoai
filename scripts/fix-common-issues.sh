#!/bin/bash

# Script to fix common issues with the AI-Enhanced Document Processing Pipeline
# Run this if you encounter any of the known issues

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

# Check if CRC is running
if ! command -v crc >/dev/null 2>&1 || ! crc status 2>/dev/null | grep -q "Running"; then
    print_error "CRC is not running. Please start it with: crc start"
    exit 1
fi

# Setup OpenShift client environment
print_info "Setting up OpenShift client environment..."
eval $(crc oc-env)

# Login as kubeadmin
print_info "Logging into OpenShift..."
KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true >/dev/null 2>&1

# Switch to project
oc project argo-ai-demo >/dev/null 2>&1 || {
    print_error "Project argo-ai-demo not found. Please run setup-crc-openshift.sh first."
    exit 1
}

print_info "Common Issues Fixer for AI Document Processing Pipeline"
echo "===================================================="
echo ""
echo "Select an issue to fix:"
echo "1) Argo UI showing 502 Bad Gateway"
echo "2) Workflow Controller in CrashLoopBackOff"
echo "3) MinIO not accessible"
echo "4) Ollama pod not starting"
echo "5) Fix all known issues"
echo "6) Check system health"
echo "7) Exit"
echo ""
read -p "Enter your choice (1-7): " choice

case $choice in
    1)
        print_info "Fixing Argo UI 502 Bad Gateway error..."

        # Fix readiness probe
        oc patch deployment argo-server -n argo-ai-demo \
          --type='json' \
          -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]'

        # Restart deployment
        oc rollout restart deployment/argo-server -n argo-ai-demo

        print_success "Argo server patched. Wait 30 seconds for it to restart."
        echo "Access via: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"
        ;;

    2)
        print_info "Fixing Workflow Controller..."

        # Fix the configmap
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

        # Restart workflow controller
        oc rollout restart deployment/workflow-controller -n argo-ai-demo

        print_success "Workflow controller configmap fixed and restarted."
        ;;

    3)
        print_info "Fixing MinIO access..."

        # Check if MinIO is running
        if ! oc get pods -n argo-ai-demo -l app=minio | grep -q "Running"; then
            print_warning "MinIO pod not running. Restarting..."
            oc rollout restart deployment/minio -n argo-ai-demo 2>/dev/null || \
            oc rollout restart deploymentconfig/minio -n argo-ai-demo 2>/dev/null
        fi

        # Ensure routes exist
        if ! oc get route minio-console -n argo-ai-demo >/dev/null 2>&1; then
            print_info "Creating MinIO console route..."
            cat <<EOF | oc apply -f -
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
EOF
        fi

        print_success "MinIO fixed. Access console at: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"
        echo "Credentials: Check your .env file or environment variables"
        ;;

    4)
        print_info "Fixing Ollama pod..."

        # Check PVC
        if ! oc get pvc ollama-models-pvc -n argo-ai-demo >/dev/null 2>&1; then
            print_error "Ollama PVC missing. Please run setup-crc-openshift.sh"
            exit 1
        fi

        # Restart Ollama
        oc rollout restart deployment/ollama -n argo-ai-demo

        print_success "Ollama restarted. Check logs with: oc logs deployment/ollama -f -n argo-ai-demo"
        ;;

    5)
        print_info "Fixing all known issues..."

        # Fix Argo readiness probe
        oc patch deployment argo-server -n argo-ai-demo \
          --type='json' \
          -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/readinessProbe/httpGet/scheme", "value": "HTTP"}]' 2>/dev/null || true

        # Fix workflow controller configmap
        cat <<EOF | oc apply -f - >/dev/null 2>&1
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

        # Restart all services
        print_info "Restarting all services..."
        oc rollout restart deployment/argo-server -n argo-ai-demo
        oc rollout restart deployment/workflow-controller -n argo-ai-demo
        oc rollout restart deployment/ollama -n argo-ai-demo 2>/dev/null || true
        oc rollout restart deployment/minio -n argo-ai-demo 2>/dev/null || \
        oc rollout restart deploymentconfig/minio -n argo-ai-demo 2>/dev/null || true

        print_success "All fixes applied. Services are restarting..."
        ;;

    6)
        print_info "Checking system health..."
        echo ""

        # Check pods
        echo "=== Pod Status ==="
        oc get pods -n argo-ai-demo
        echo ""

        # Check routes
        echo "=== Routes ==="
        oc get routes -n argo-ai-demo
        echo ""

        # Check recent events
        echo "=== Recent Events (errors/warnings) ==="
        oc get events -n argo-ai-demo --field-selector type!=Normal --sort-by='.lastTimestamp' | tail -10
        echo ""

        # Service URLs
        echo "=== Service URLs ==="
        echo "Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"
        echo "MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"
        echo "Ollama API: https://$(oc get route ollama -n argo-ai-demo -o jsonpath='{.spec.host}')"
        ;;

    7)
        echo "Exiting..."
        exit 0
        ;;

    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac
