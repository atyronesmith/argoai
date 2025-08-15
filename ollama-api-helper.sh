#!/bin/bash

# Helper script to interact with Ollama API via OpenShift route
# Useful for testing and managing models without pod access

set -e

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Get Ollama route URL
OLLAMA_URL=$(oc get route ollama -n argo-ai-demo -o jsonpath='https://{.spec.host}' 2>/dev/null)

if [ -z "$OLLAMA_URL" ]; then
    echo "Error: Could not find Ollama route. Is the deployment running?"
    exit 1
fi

print_info "Ollama API URL: $OLLAMA_URL"

# Function to make API calls
ollama_api() {
    local endpoint=$1
    local data=$2
    local method=${3:-POST}

    if [ -n "$data" ]; then
        curl -sk -X "$method" "$OLLAMA_URL/api/$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -sk -X "$method" "$OLLAMA_URL/api/$endpoint"
    fi
}

# Function to pull model via API
pull_model_api() {
    local model=$1
    print_info "Pulling model $model via API..."

    # Start the pull
    ollama_api "pull" "{\"name\": \"$model\"}"
    echo ""
    print_success "Model pull initiated for $model"
}

# Function to list models via API
list_models_api() {
    print_info "Listing models via API..."
    ollama_api "tags" "" "GET" | jq -r '.models[] | "\(.name) - Size: \(.size | tonumber / 1024 / 1024 / 1024 | tostring | .[0:4])GB"' 2>/dev/null || {
        ollama_api "tags" "" "GET"
    }
}

# Function to test model via API
test_model_api() {
    local model=$1
    local prompt=${2:-"What is OpenShift in one sentence?"}

    print_info "Testing model $model via API..."

    response=$(ollama_api "generate" "{
        \"model\": \"$model\",
        \"prompt\": \"$prompt\",
        \"stream\": false
    }")

    echo "$response" | jq -r '.response' 2>/dev/null || echo "$response"
}

# Function to check model status
check_model_status() {
    local model=$1

    response=$(ollama_api "show" "{\"name\": \"$model\"}" "POST" 2>/dev/null)

    if echo "$response" | grep -q "error"; then
        echo "Model $model is not loaded"
        return 1
    else
        echo "Model $model is available"
        return 0
    fi
}

# Main menu
echo "Ollama API Helper"
echo "================="
echo ""
echo "1) List loaded models"
echo "2) Pull a model"
echo "3) Test a model"
echo "4) Check model status"
echo "5) Show Ollama API endpoint"
echo ""
read -p "Choose an option (1-5): " choice

case $choice in
    1)
        list_models_api
        ;;
    2)
        read -p "Enter model name to pull (e.g., llama3.2:3b): " model
        pull_model_api "$model"
        echo ""
        echo "Note: Model pulling happens in the background."
        echo "Check status with option 4 or pod logs:"
        echo "oc logs deployment/ollama -f -n argo-ai-demo"
        ;;
    3)
        read -p "Enter model name to test: " model
        read -p "Enter prompt (or press Enter for default): " prompt
        test_model_api "$model" "${prompt:-What is OpenShift in one sentence?}"
        ;;
    4)
        read -p "Enter model name to check: " model
        check_model_status "$model"
        ;;
    5)
        echo "Ollama API Endpoint: $OLLAMA_URL"
        echo ""
        echo "Example API calls:"
        echo "List models: curl -sk $OLLAMA_URL/api/tags"
        echo "Pull model: curl -sk -X POST $OLLAMA_URL/api/pull -d '{\"name\":\"llama3.2:3b\"}'"
        echo "Generate: curl -sk -X POST $OLLAMA_URL/api/generate -d '{\"model\":\"llama3.2:3b\",\"prompt\":\"Hello\",\"stream\":false}'"
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac
