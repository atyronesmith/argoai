#!/bin/bash

# Script to load AI models into Ollama running on OpenShift
# This script handles model loading for the AI-Enhanced Document Processing Pipeline

set -e  # Exit on error

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

# Default models for document processing
DEFAULT_MODELS=(
    "llama3.2:3b"      # Smaller, faster model for quick processing
    "llama3.2:latest"  # Latest stable version
    "mistral:7b"       # Good for document analysis
    "phi3:mini"        # Microsoft's efficient model
)

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to show usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --model MODEL    Specific model to load (e.g., llama3.2:3b)"
    echo "  -a, --all           Load all default models"
    echo "  -l, --list          List available models from Ollama library"
    echo "  -s, --status        Show currently loaded models"
    echo "  -h, --help          Show this help message"
    echo ""
    echo "Default models: ${DEFAULT_MODELS[*]}"
    echo ""
    echo "Examples:"
    echo "  $0 -m llama3.2:3b              # Load specific model"
    echo "  $0 -a                           # Load all default models"
    echo "  $0 -s                           # Show loaded models"
}

# Parse command line arguments
LOAD_ALL=false
SPECIFIC_MODEL=""
LIST_MODELS=false
SHOW_STATUS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            SPECIFIC_MODEL="$2"
            shift 2
            ;;
        -a|--all)
            LOAD_ALL=true
            shift
            ;;
        -l|--list)
            LIST_MODELS=true
            shift
            ;;
        -s|--status)
            SHOW_STATUS=true
            shift
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

# Check if oc is available
if ! command_exists oc; then
    print_error "OpenShift CLI (oc) not found. Please ensure CRC is set up."
    echo "Run: eval \$(crc oc-env)"
    exit 1
fi

# Ensure we're logged in and in the right project
print_info "Checking OpenShift connection..."
if ! oc whoami >/dev/null 2>&1; then
    print_error "Not logged into OpenShift. Please login first."
    echo "Run: oc login -u kubeadmin -p <password> https://api.crc.testing:6443"
    exit 1
fi

# Switch to argo-ai-demo project
oc project argo-ai-demo >/dev/null 2>&1 || {
    print_error "Project argo-ai-demo not found. Please run setup-crc-openshift.sh first."
    exit 1
}

# Check if Ollama is running
print_info "Checking Ollama deployment..."
if ! oc get deployment ollama -n argo-ai-demo >/dev/null 2>&1; then
    print_error "Ollama deployment not found. Please run setup-crc-openshift.sh first."
    exit 1
fi

# Get Ollama pod name
OLLAMA_POD=$(oc get pods -n argo-ai-demo -l app=ollama -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
if [ -z "$OLLAMA_POD" ]; then
    print_error "Ollama pod not found or not running."
    exit 1
fi

print_info "Found Ollama pod: $OLLAMA_POD"

# Function to execute command in Ollama pod
ollama_exec() {
    oc exec -n argo-ai-demo "$OLLAMA_POD" -- $@
}

# Function to show loaded models
show_loaded_models() {
    print_info "Currently loaded models in Ollama:"
    echo ""
    ollama_exec ollama list 2>/dev/null || {
        print_warning "No models currently loaded"
        return
    }
}

# Function to pull a model
pull_model() {
    local model=$1
    print_info "Pulling model: $model"
    print_warning "This may take several minutes depending on model size..."

    # Pull the model with progress
    if ollama_exec ollama pull "$model"; then
        print_success "Model $model loaded successfully"
    else
        print_error "Failed to load model $model"
        return 1
    fi
}

# Function to list available models
list_available_models() {
    print_info "Popular models for document processing:"
    echo ""
    echo "Small/Fast Models (< 4GB):"
    echo "  - llama3.2:3b         : Latest Llama 3.2B model, good for general tasks"
    echo "  - phi3:mini           : Microsoft's efficient 3.8B model"
    echo "  - gemma2:2b           : Google's 2B model, fast and efficient"
    echo ""
    echo "Medium Models (4-8GB):"
    echo "  - llama3.2:latest     : Standard Llama model"
    echo "  - mistral:7b          : Excellent for document analysis"
    echo "  - neural-chat:7b      : Intel's optimized chat model"
    echo ""
    echo "Large Models (8GB+):"
    echo "  - llama3.1:8b         : Larger Llama for complex tasks"
    echo "  - mixtral:8x7b        : MoE model for advanced processing"
    echo ""
    echo "For full list, visit: https://ollama.com/library"
}

# Function to test model
test_model() {
    local model=$1
    print_info "Testing model $model with a simple prompt..."

    local test_prompt="Summarize in one sentence: OpenShift is a container platform."

    if ollama_exec ollama run "$model" "$test_prompt" --verbose=false 2>/dev/null; then
        print_success "Model $model is working correctly"
    else
        print_warning "Model $model test failed or timed out"
    fi
}

# Main execution
print_info "Ollama Model Loader for AI Document Processing Pipeline"
echo "======================================================="

# Show status if requested
if [ "$SHOW_STATUS" = true ]; then
    show_loaded_models
    exit 0
fi

# List models if requested
if [ "$LIST_MODELS" = true ]; then
    list_available_models
    exit 0
fi

# Check current models first
print_info "Checking currently loaded models..."
show_loaded_models
echo ""

# Load specific model if provided
if [ -n "$SPECIFIC_MODEL" ]; then
    pull_model "$SPECIFIC_MODEL"
    print_info "Testing model..."
    test_model "$SPECIFIC_MODEL"
    exit 0
fi

# Load all default models if requested
if [ "$LOAD_ALL" = true ]; then
    print_info "Loading all default models..."
    for model in "${DEFAULT_MODELS[@]}"; do
        echo ""
        pull_model "$model" || print_warning "Skipping remaining models due to error"
    done
    echo ""
    show_loaded_models
    exit 0
fi

# If no options provided, show interactive menu
if [ -z "$SPECIFIC_MODEL" ] && [ "$LOAD_ALL" = false ]; then
    echo "What would you like to do?"
    echo "1) Load recommended model for document processing (llama3.2:3b)"
    echo "2) Load all default models"
    echo "3) Load a specific model"
    echo "4) Show currently loaded models"
    echo "5) Exit"
    echo ""
    read -p "Enter your choice (1-5): " choice

    case $choice in
        1)
            pull_model "llama3.2:3b"
            test_model "llama3.2:3b"
            ;;
        2)
            for model in "${DEFAULT_MODELS[@]}"; do
                echo ""
                pull_model "$model"
            done
            show_loaded_models
            ;;
        3)
            read -p "Enter model name (e.g., mistral:7b): " custom_model
            if [ -n "$custom_model" ]; then
                pull_model "$custom_model"
                test_model "$custom_model"
            else
                print_error "No model name provided"
                exit 1
            fi
            ;;
        4)
            show_loaded_models
            ;;
        5)
            echo "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            exit 1
            ;;
    esac
fi

echo ""
print_info "Model loading complete!"
echo ""
echo "Next steps:"
echo "1. Test the workflow with: oc create -f test-workflow.yaml"
echo "2. Access Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo "3. Monitor model performance in Ollama logs: oc logs deployment/ollama -f"
