#!/bin/bash

# Wrapper script that handles CRC environment setup and loads Ollama models
# This script ensures the OpenShift environment is properly configured before running

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

# Check if CRC is installed
if ! command -v crc >/dev/null 2>&1; then
    print_error "CRC is not installed. Please install OpenShift Local first."
    exit 1
fi

# Check if CRC is running
if ! crc status 2>/dev/null | grep -q "Running"; then
    print_error "CRC is not running. Please start it with: crc start"
    exit 1
fi

# Setup OpenShift client environment
print_info "Setting up OpenShift client environment..."
eval $(crc oc-env)

# Verify oc is now available
if ! command -v oc >/dev/null 2>&1; then
    print_error "Failed to set up OpenShift client. Please check your CRC installation."
    exit 1
fi

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Check if load-ollama-models.sh exists
if [ ! -f "$SCRIPT_DIR/load-ollama-models.sh" ]; then
    print_error "load-ollama-models.sh not found in $SCRIPT_DIR"
    exit 1
fi

# Pass all arguments to the load-ollama-models.sh script
print_info "Running Ollama model loader..."
"$SCRIPT_DIR/load-ollama-models.sh" "$@"
