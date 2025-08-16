#!/bin/bash

# CRC (OpenShift Local) Setup Script
# This script handles CRC installation/setup and ensures Helm is installed
# Services are deployed via Helm charts
#
# Pull Secret Setup:
# The script looks for a pull secret file at: ./secrets/pull-secret.txt
# To create this file:
#   1. Go to https://console.redhat.com/openshift/create/local
#   2. Download your pull secret
#   3. Save it as: ./secrets/pull-secret.txt
#
# The script will automatically use this file for CRC configuration

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to install Helm
install_helm() {
    print_info "Installing Helm..."

    OS=$(detect_os)

    case $OS in
        "linux"|"macos")
            # Use the official Helm installation script
            print_info "Downloading and installing Helm via official script..."
            curl -fsSL -o "$WORK_DIR/get_helm.sh" https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
            chmod 700 "$WORK_DIR/get_helm.sh"
            "$WORK_DIR/get_helm.sh"
            rm -f "$WORK_DIR/get_helm.sh"
            ;;
        "windows")
            print_warning "Windows detected. Please install Helm manually:"
            echo "  1. Download from: https://github.com/helm/helm/releases"
            echo "  2. Extract and add to PATH"
            echo "  Or use Chocolatey: choco install kubernetes-helm"
            return 1
            ;;
        *)
            print_error "Unknown OS. Please install Helm manually from:"
            echo "  https://helm.sh/docs/intro/install/"
            return 1
            ;;
    esac

    # Verify installation
    if command_exists helm; then
        print_success "Helm installed successfully: $(helm version --short)"
        return 0
    else
        print_error "Helm installation failed"
        return 1
    fi
}

# Function to install Argo CLI
install_argo_cli() {
    print_info "Installing Argo CLI..."

    OS=$(detect_os)
    ARCH=$(uname -m)

    # Convert architecture names
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    # Get latest version
    ARGO_VERSION=$(curl -s https://api.github.com/repos/argoproj/argo-workflows/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$ARGO_VERSION" ]; then
        ARGO_VERSION="v3.5.0"  # Fallback version
    fi

    case $OS in
        "linux")
            ARGO_URL="https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-linux-${ARCH}.gz"
            ;;
        "macos")
            ARGO_URL="https://github.com/argoproj/argo-workflows/releases/download/${ARGO_VERSION}/argo-darwin-${ARCH}.gz"
            ;;
        *)
            print_warning "Argo CLI installation not supported on $OS"
            return 1
            ;;
    esac

    print_info "Downloading Argo CLI ${ARGO_VERSION}..."
    curl -sLO "$ARGO_URL"
    gunzip -f argo-*.gz
    chmod +x argo-*

    # Move to /usr/local/bin
    print_info "Installing Argo CLI to /usr/local/bin (may require sudo)..."
    sudo mv argo-* /usr/local/bin/argo

    # Verify installation
    if command_exists argo; then
        print_success "Argo CLI installed successfully: $(argo version --short)"
        return 0
    else
        print_error "Argo CLI installation failed"
        return 1
    fi
}

# Function to install MinIO Client
install_minio_client() {
    print_info "Installing MinIO Client (mc)..."

    OS=$(detect_os)
    ARCH=$(uname -m)

    # Convert architecture names
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
    esac

    case $OS in
        "linux")
            MC_URL="https://dl.min.io/client/mc/release/linux-${ARCH}/mc"
            ;;
        "macos")
            MC_URL="https://dl.min.io/client/mc/release/darwin-${ARCH}/mc"
            ;;
        *)
            print_warning "MinIO Client installation not supported on $OS"
            return 1
            ;;
    esac

    print_info "Downloading MinIO Client..."
    curl -sLO "$MC_URL"
    chmod +x mc

    # Move to /usr/local/bin
    print_info "Installing MinIO Client to /usr/local/bin (may require sudo)..."
    sudo mv mc /usr/local/bin/mc

    # Verify installation
    if command_exists mc; then
        print_success "MinIO Client installed successfully: $(mc --version)"
        return 0
    else
        print_error "MinIO Client installation failed"
        return 1
    fi
}

# Function to install jq
install_jq() {
    print_info "Installing jq..."

    OS=$(detect_os)

    case $OS in
        "linux")
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y jq
            elif command_exists yum; then
                sudo yum install -y jq
            elif command_exists dnf; then
                sudo dnf install -y jq
            else
                print_warning "Cannot install jq automatically. Please install manually."
                return 1
            fi
            ;;
        "macos")
            if command_exists brew; then
                brew install jq
            else
                print_warning "Homebrew not found. Please install jq manually."
                return 1
            fi
            ;;
        *)
            print_warning "jq installation not supported on $OS"
            return 1
            ;;
    esac

    # Verify installation
    if command_exists jq; then
        print_success "jq installed successfully: $(jq --version)"
        return 0
    else
        print_error "jq installation failed"
        return 1
    fi
}

# Create a work directory
WORK_DIR="$HOME/.crc-setup"
mkdir -p "$WORK_DIR"

echo "============================================"
echo "🚀 CRC (OpenShift Local) Setup Script"
echo "============================================"
echo ""

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

# Check and install required tools
echo ""
echo "Checking required tools..."
echo "=========================="

# Check Helm
if ! command_exists helm; then
    print_warning "Helm is not installed."
    read -p "Would you like to install Helm now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! install_helm; then
            print_error "Failed to install Helm. Please install it manually."
            echo "Visit: https://helm.sh/docs/intro/install/"
            exit 1
        fi
    else
        print_warning "Helm installation skipped. Required for deploying services."
    fi
else
    print_success "Helm is installed: $(helm version --short)"
fi

# Check Argo CLI
if ! command_exists argo; then
    print_warning "Argo CLI is not installed."
    read -p "Would you like to install Argo CLI now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! install_argo_cli; then
            print_warning "Failed to install Argo CLI. You can still use 'oc' for workflow management."
        fi
    else
        print_info "Argo CLI installation skipped. You can use 'oc' for workflow management."
    fi
else
    print_success "Argo CLI is installed: $(argo version --short)"
fi

# Check MinIO Client
if ! command_exists mc; then
    print_warning "MinIO Client (mc) is not installed."
    read -p "Would you like to install MinIO Client now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! install_minio_client; then
            print_warning "Failed to install MinIO Client. You can still use the web console."
        fi
    else
        print_info "MinIO Client installation skipped. You can use the web console for object storage."
    fi
else
    print_success "MinIO Client is installed: $(mc --version)"
fi

# Check jq
if ! command_exists jq; then
    print_warning "jq is not installed (useful for JSON processing)."
    read -p "Would you like to install jq now? (y/n): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if ! install_jq; then
            print_warning "Failed to install jq. Some scripts may have limited functionality."
        fi
    else
        print_info "jq installation skipped. Some scripts may have limited functionality."
    fi
else
    print_success "jq is installed: $(jq --version)"
fi

echo ""

# Check CRC status
print_info "Checking CRC status..."
CRC_STATUS=$(crc status -o json 2>/dev/null | jq -r '.crcStatus' || echo "Not Running")

if [ "$CRC_STATUS" != "Running" ]; then
    print_info "CRC is not running. Setting up CRC..."

    # Check if pull secret is already configured
    if ! crc config get pull-secret-file >/dev/null 2>&1; then
        print_info "Pull secret not configured. Let's set it up."

        # Check for pull secret file in secrets directory
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        PULL_SECRET_FILE="$SCRIPT_DIR/secrets/pull-secret.txt"

        if [ -f "$PULL_SECRET_FILE" ]; then
            print_info "Found pull secret file at $PULL_SECRET_FILE"
            # Configure CRC with pull secret
            print_info "Configuring CRC with pull secret..."
            crc config set pull-secret-file "$PULL_SECRET_FILE"
        else
            print_warning "Pull secret file not found at $PULL_SECRET_FILE"
            print_info "You have two options:"
            echo "  1. Create $PULL_SECRET_FILE with your pull secret (recommended)"
            echo "  2. Paste your pull secret here (less secure)"
            echo ""
            echo "To create the file:"
            echo "  1. Get your pull secret from: https://console.redhat.com/openshift/create/local"
            echo "  2. Save it to: $PULL_SECRET_FILE"
            echo ""
            read -p "Do you want to paste your pull secret now? (y/n): " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Please paste your pull secret below (it's a long JSON string):"
                echo "(Your input will be hidden for security)"
                read -s -r PULL_SECRET
                echo ""

                # Save pull secret to temporary file
                TEMP_PULL_SECRET_FILE="$WORK_DIR/pull-secret.txt"
                echo "$PULL_SECRET" > "$TEMP_PULL_SECRET_FILE"

                # Configure CRC with pull secret
                print_info "Configuring CRC with pull secret..."
                crc config set pull-secret-file "$TEMP_PULL_SECRET_FILE"

                # Clean up temporary pull secret file for security
                rm -f "$TEMP_PULL_SECRET_FILE"
            else
                print_error "Pull secret is required to start CRC. Please create $PULL_SECRET_FILE and run this script again."
                exit 1
            fi
        fi
    fi

    # Configure CRC resources (optional)
    print_info "Configuring CRC resources..."
    crc config set cpus 4
    crc config set memory 16384
    crc config set disk-size 60

    # Run CRC setup
    print_info "Running CRC setup..."
    crc setup

    # Start CRC
    print_info "Starting CRC (this may take several minutes)..."

    # Check if pull secret is configured for start
    if ! crc config get pull-secret-file >/dev/null 2>&1; then
        print_warning "Pull secret still not configured. CRC start will prompt for it."
        # Try to use the pull secret file if available
        SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
        PULL_SECRET_FILE="$SCRIPT_DIR/secrets/pull-secret.txt"
        if [ -f "$PULL_SECRET_FILE" ]; then
            print_info "Using pull secret from $PULL_SECRET_FILE"
            # CRC start will use stdin for pull secret if not configured
            CRC_OUTPUT=$(cat "$PULL_SECRET_FILE" | crc start 2>&1 | tee "$WORK_DIR/crc-start.log")
        else
            print_error "No pull secret file found. CRC start will fail."
            exit 1
        fi
    else
        # Normal start with configured pull secret
        CRC_OUTPUT=$(crc start 2>&1 | tee "$WORK_DIR/crc-start.log")
    fi

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

# Save credentials for later use
CREDENTIALS_FILE="$HOME/.crc-credentials"
cat > "$CREDENTIALS_FILE" << EOF
# CRC Credentials - Generated by setup.sh
export KUBEADMIN_PASSWORD="$KUBEADMIN_PASSWORD"
export OPENSHIFT_API_URL="https://api.crc.testing:6443"
export OPENSHIFT_CONSOLE_URL="https://console-openshift-console.apps-crc.testing"

# To login:
# oc login -u kubeadmin -p \$KUBEADMIN_PASSWORD \$OPENSHIFT_API_URL --insecure-skip-tls-verify=true

# To setup environment:
# eval \$(crc oc-env)
EOF

chmod 600 "$CREDENTIALS_FILE"

# Display summary
echo ""
echo "============================================"
echo "✅ CRC Setup Complete!"
echo "============================================"
echo ""
echo "CRC Status: Running"
echo ""
echo "Connection Details:"
echo "  API URL: https://api.crc.testing:6443"
echo "  Console: https://console-openshift-console.apps-crc.testing"
echo "  Username: kubeadmin"
echo "  Password: $KUBEADMIN_PASSWORD"
echo ""
echo "Credentials saved to: $CREDENTIALS_FILE"
echo ""
echo "To setup your shell environment:"
echo "  eval \$(crc oc-env)"
echo "  source $CREDENTIALS_FILE"
echo ""
echo "To login to OpenShift:"
echo "  oc login -u kubeadmin -p $KUBEADMIN_PASSWORD https://api.crc.testing:6443 --insecure-skip-tls-verify=true"
echo ""

# Show installed tools summary
echo "Installed Tools:"
command_exists helm && echo "  ✓ Helm - Package manager for Kubernetes"
command_exists argo && echo "  ✓ Argo CLI - Workflow management"
command_exists mc && echo "  ✓ MinIO Client - Object storage management"
command_exists jq && echo "  ✓ jq - JSON processing"
echo ""

# Check if Helm is available for next steps
if command_exists helm; then
    echo "Next Steps:"
    echo "  1. Login to OpenShift (command above)"
    echo "  2. Deploy services: helm install ai-pipeline ./helm/ai-document-pipeline"
    echo ""
    print_success "CRC and all tools are ready for deployments!"
else
    echo "Next Steps:"
    echo "  1. Install Helm: https://helm.sh/docs/intro/install/"
    echo "  2. Login to OpenShift (command above)"
    echo "  3. Deploy services: helm install ai-pipeline ./helm/ai-document-pipeline"
    echo ""
    print_success "CRC is ready! Remember to install Helm before deploying services."
fi
