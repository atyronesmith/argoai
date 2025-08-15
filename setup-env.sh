#!/bin/bash

# Environment setup script for AI-Enhanced Document Processing Pipeline
# Source this script to set up your shell environment: source ./setup-env.sh

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Setting up OpenShift Local environment...${NC}"

# Check if CRC is installed
if ! command -v crc >/dev/null 2>&1; then
    echo -e "${RED}[ERROR]${NC} CRC is not installed. Please install OpenShift Local first."
    return 1
fi

# Check if CRC is running
if ! crc status 2>/dev/null | grep -q "Running"; then
    echo -e "${YELLOW}[WARNING]${NC} CRC is not running. Starting CRC..."
    crc start
fi

# Setup OpenShift client environment
eval $(crc oc-env)

# Get kubeadmin password
KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')

# Login to OpenShift
echo -e "${BLUE}Logging into OpenShift...${NC}"
oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true >/dev/null 2>&1

# Switch to argo-ai-demo project
oc project argo-ai-demo >/dev/null 2>&1 || echo -e "${YELLOW}Project argo-ai-demo not found${NC}"

# Export useful environment variables
export ARGO_NAMESPACE="argo-ai-demo"
export KUBEADMIN_PASSWORD="$KUBEADMIN_PASSWORD"

# Get service URLs
export ARGO_URL=$(oc get route argo-server -n argo-ai-demo -o jsonpath='https://{.spec.host}' 2>/dev/null)
export MINIO_URL=$(oc get route minio-console -n argo-ai-demo -o jsonpath='https://{.spec.host}' 2>/dev/null)
export OLLAMA_URL=$(oc get route ollama -n argo-ai-demo -o jsonpath='https://{.spec.host}' 2>/dev/null)
export OPENSHIFT_CONSOLE=$(crc console --url 2>/dev/null)

# Create helpful aliases
alias argo-ui='echo "Opening Argo UI..." && open $ARGO_URL'
alias minio-ui='echo "Opening MinIO Console..." && open $MINIO_URL'
alias openshift-ui='echo "Opening OpenShift Console..." && open $OPENSHIFT_CONSOLE'
alias ollama-logs='oc logs deployment/ollama -f -n argo-ai-demo'
alias argo-logs='oc logs deployment/argo-server -f -n argo-ai-demo'
alias workflow-logs='oc logs deployment/workflow-controller -f -n argo-ai-demo'
alias get-pods='oc get pods -n argo-ai-demo'
alias get-workflows='oc get workflows -n argo-ai-demo'

# Function to load Ollama model
load-model() {
    local model=${1:-llama3.2:3b}
    echo -e "${BLUE}Loading model: $model${NC}"
    "$PWD/ollama-load-model.sh" -m "$model"
}

# Function to list Ollama models
list-models() {
    "$PWD/ollama-load-model.sh" -s
}

# Function to submit a test workflow
submit-workflow() {
    local doc_url=${1:-"https://raw.githubusercontent.com/argoproj/argo-workflows/master/README.md"}
    local model=${2:-"llama3.2:3b"}

    echo -e "${BLUE}Submitting workflow...${NC}"
    cat <<EOF | oc create -f -
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
      value: "$doc_url"
    - name: model
      value: "$model"
EOF
}

# Print environment summary
echo -e "${GREEN}Environment setup complete!${NC}"
echo ""
echo "Service URLs:"
[ -n "$ARGO_URL" ] && echo "  Argo UI:          $ARGO_URL"
[ -n "$MINIO_URL" ] && echo "  MinIO Console:    $MINIO_URL"
[ -n "$OLLAMA_URL" ] && echo "  Ollama API:       $OLLAMA_URL"
[ -n "$OPENSHIFT_CONSOLE" ] && echo "  OpenShift:        $OPENSHIFT_CONSOLE"
echo ""
echo "Useful commands:"
echo "  load-model [model]     - Load an Ollama model (default: llama3.2:3b)"
echo "  list-models           - List loaded Ollama models"
echo "  submit-workflow       - Submit a test workflow"
echo "  get-pods             - Show all pods in the project"
echo "  get-workflows        - Show all workflows"
echo "  ollama-logs          - Follow Ollama logs"
echo "  argo-logs            - Follow Argo server logs"
echo "  workflow-logs        - Follow workflow controller logs"
echo ""
echo "UI shortcuts:"
echo "  argo-ui              - Open Argo UI in browser"
echo "  minio-ui             - Open MinIO Console in browser"
echo "  openshift-ui         - Open OpenShift Console in browser"
echo ""
echo -e "${YELLOW}Current project: $(oc project -q)${NC}"
