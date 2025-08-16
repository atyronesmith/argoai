#!/bin/bash

# Script to submit test workflows for the AI-Enhanced Document Processing Pipeline
# This script makes it easy to test the pipeline with various documents and models

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

# Default values
DEFAULT_MODEL="llama3.2:3b"
DEFAULT_DOC_URL="https://raw.githubusercontent.com/kubernetes/kubernetes/master/README.md"
NAMESPACE="argo-ai-demo"

# Sample document URLs for testing
get_sample_doc_url() {
    case $1 in
        "kubernetes")
            echo "https://raw.githubusercontent.com/kubernetes/kubernetes/master/README.md"
            ;;
        "argo")
            echo "https://raw.githubusercontent.com/argoproj/argo-workflows/master/README.md"
            ;;
        "openshift")
            echo "https://raw.githubusercontent.com/openshift/origin/master/README.md"
            ;;
        "sample-invoice")
            echo "https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/README.md"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -d, --doc URL        Document URL to process (default: Kubernetes README)"
    echo "  -m, --model MODEL    Ollama model to use (default: llama3.2:3b)"
    echo "  -n, --name NAME      Workflow name prefix (default: test-ai-doc)"
    echo "  -s, --sample NAME    Use a predefined sample document:"
    echo "                       kubernetes, argo, openshift, sample-invoice"
    echo "  -w, --watch          Watch the workflow after submission"
    echo "  -l, --list           List all workflows"
    echo "  -g, --get NAME       Get details of a specific workflow"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Use defaults"
    echo "  $0 -s argo                           # Process Argo README"
    echo "  $0 -d https://example.com/doc.txt    # Process custom document"
    echo "  $0 -m mistral:7b -w                  # Use different model and watch"
}

# Function to check prerequisites
check_prerequisites() {
    # Check if CRC is running
    if ! command -v crc >/dev/null 2>&1 || ! crc status 2>/dev/null | grep -q "Running"; then
        print_error "CRC is not running. Please start it with: crc start"
        exit 1
    fi

    # Setup OpenShift client environment
    print_info "Setting up OpenShift client environment..."
    eval $(crc oc-env)

    # Check if logged in
    if ! oc whoami >/dev/null 2>&1; then
        print_warning "Not logged in. Attempting to login..."
        KUBEADMIN_PASSWORD=$(crc console --credentials | grep "kubeadmin" | sed -n 's/.*-p \([^ ]*\).*/\1/p')
        oc login -u kubeadmin -p "$KUBEADMIN_PASSWORD" https://api.crc.testing:6443 --insecure-skip-tls-verify=true
    fi

    # Check if project exists
    if ! oc get project $NAMESPACE >/dev/null 2>&1; then
        print_error "Project $NAMESPACE not found. Please run setup-crc-openshift.sh first."
        exit 1
    fi

    oc project $NAMESPACE >/dev/null 2>&1
}

# Function to check if model is loaded
check_model() {
    local model=$1
    print_info "Checking if model $model is loaded..."

    # Get Ollama pod
    local ollama_pod=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/component=ollama -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [ -z "$ollama_pod" ]; then
        print_error "Ollama pod not found"
        exit 1
    fi

    # Check if model exists
    if ! oc exec -n $NAMESPACE "$ollama_pod" -- ollama list | grep -q "$model"; then
        print_error "Model $model is not loaded in Ollama"
        echo "Available models:"
        oc exec -n $NAMESPACE "$ollama_pod" -- ollama list
        echo ""
        echo "Load the model with: ./load-ollama-models.sh -m $model"
        exit 1
    fi

    print_success "Model $model is available"
}

# Function to submit workflow
submit_workflow() {
    local doc_url=$1
    local model=$2
    local name_prefix=$3

    print_info "Submitting workflow..."
    echo "  Document: $doc_url"
    echo "  Model: $model"
    echo ""

    # Create a label-safe version of the model name (replace : with -)
    local model_label=$(echo "$model" | tr ':' '-')

    # Create workflow YAML
    local workflow_yaml=$(cat <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ${name_prefix}-
  namespace: $NAMESPACE
  labels:
    test-type: "document-processing"
    model: "$model_label"
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
)

    # Submit the workflow
    local workflow_name=$(echo "$workflow_yaml" | oc create -f - -o jsonpath='{.metadata.name}')

    if [ -n "$workflow_name" ]; then
        print_success "Workflow submitted successfully: $workflow_name"
        echo ""
        echo "Commands to monitor:"
        echo "  Watch workflow: argo watch -n $NAMESPACE $workflow_name"
        echo "  Get workflow: oc get workflow $workflow_name -n $NAMESPACE"
        echo "  View logs: argo logs -n $NAMESPACE $workflow_name"
        echo "  Argo UI: https://$(oc get route argo-server -n $NAMESPACE -o jsonpath='{.spec.host}')"
        echo ""
        return 0
    else
        print_error "Failed to submit workflow"
        return 1
    fi
}

# Function to list workflows
list_workflows() {
    print_info "Listing workflows in namespace $NAMESPACE..."
    echo ""
    oc get workflows -n $NAMESPACE
}

# Function to get workflow details
get_workflow() {
    local workflow_name=$1
    print_info "Getting details for workflow: $workflow_name"
    echo ""
    oc get workflow "$workflow_name" -n $NAMESPACE -o yaml
}

# Function to watch workflow
watch_workflow() {
    # Get the most recent workflow
    local latest_workflow=$(oc get workflows -n $NAMESPACE --sort-by='.metadata.creationTimestamp' -o jsonpath='{.items[-1].metadata.name}')

    if [ -n "$latest_workflow" ]; then
        print_info "Watching workflow: $latest_workflow"
        if command -v argo >/dev/null 2>&1; then
            argo watch -n $NAMESPACE "$latest_workflow"
        else
            print_warning "Argo CLI not found. Using oc to monitor..."
            oc get workflow "$latest_workflow" -n $NAMESPACE -w
        fi
    else
        print_error "No workflows found"
    fi
}

# Parse command line arguments
DOC_URL=""
MODEL=""
NAME_PREFIX="test-ai-doc"
WATCH_AFTER=false
LIST_ONLY=false
GET_WORKFLOW=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--doc)
            DOC_URL="$2"
            shift 2
            ;;
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -n|--name)
            NAME_PREFIX="$2"
            shift 2
            ;;
        -s|--sample)
            SAMPLE_NAME="$2"
            DOC_URL=$(get_sample_doc_url "$SAMPLE_NAME")
            if [ -z "$DOC_URL" ]; then
                print_error "Unknown sample: $SAMPLE_NAME"
                echo "Available samples: kubernetes, argo, openshift, sample-invoice"
                exit 1
            fi
            shift 2
            ;;
        -w|--watch)
            WATCH_AFTER=true
            shift
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -g|--get)
            GET_WORKFLOW="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Main execution
print_info "AI Document Processing Workflow Submitter"
echo "========================================"

# Check prerequisites
check_prerequisites

# Handle list or get operations
if [ "$LIST_ONLY" = true ]; then
    list_workflows
    exit 0
fi

if [ -n "$GET_WORKFLOW" ]; then
    get_workflow "$GET_WORKFLOW"
    exit 0
fi

# Set defaults if not provided
DOC_URL=${DOC_URL:-$DEFAULT_DOC_URL}
MODEL=${MODEL:-$DEFAULT_MODEL}

# Check if model is loaded
check_model "$MODEL"

# Submit the workflow
if submit_workflow "$DOC_URL" "$MODEL" "$NAME_PREFIX"; then
    if [ "$WATCH_AFTER" = true ]; then
        sleep 2  # Give it a moment to create
        watch_workflow
    fi
else
    exit 1
fi
