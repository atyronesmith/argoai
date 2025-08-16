#!/bin/bash
# Comprehensive CRC/OpenShift Local certificate setup script
# This script extracts and imports CRC certificates to enable HTTPS/WSS connections

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== CRC/OpenShift Local Certificate Setup ===${NC}"
echo

# Function to print section headers
print_section() {
    echo
    echo -e "${BLUE}>>> $1${NC}"
    echo
}

# Function to print success messages
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Function to print error messages
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to print warning messages
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if CRC is installed
print_section "Checking CRC installation"
if command -v crc &> /dev/null; then
    CRC_VERSION=$(crc version | head -1)
    print_success "CRC is installed: $CRC_VERSION"
else
    print_error "CRC is not installed or not in PATH"
    echo "Please install OpenShift Local (CRC) from: https://developers.redhat.com/products/openshift-local/overview"
    exit 1
fi

# Check if CRC is running
if crc status &>/dev/null; then
    print_success "CRC is running"
else
    print_warning "CRC is not running. The script will still try to extract certificates."
fi

# Create temporary directory for certificates
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

print_section "Extracting CRC certificates"

# Try multiple methods to get certificates
CERT_EXTRACTED=false

# Method 1: Extract from the ingress route
echo "Attempting to extract ingress certificate..."
if echo | openssl s_client -connect apps-crc.testing:443 -showcerts 2>/dev/null | \
   awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; print}' > "$TEMP_DIR/crc-chain.pem" 2>/dev/null; then
    if [ -s "$TEMP_DIR/crc-chain.pem" ]; then
        print_success "Extracted certificate chain from ingress"
        CERT_EXTRACTED=true
        CERT_FILE="$TEMP_DIR/crc-chain.pem"
    fi
fi

# Method 2: Try specific dashboard endpoint
if [ "$CERT_EXTRACTED" = false ]; then
    echo "Attempting to extract from dashboard endpoint..."
    if echo | openssl s_client -connect ai-dashboard-argo-ai-demo.apps-crc.testing:443 -showcerts 2>/dev/null | \
       awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; print}' > "$TEMP_DIR/crc-chain.pem" 2>/dev/null; then
        if [ -s "$TEMP_DIR/crc-chain.pem" ]; then
            print_success "Extracted certificate chain from dashboard"
            CERT_EXTRACTED=true
            CERT_FILE="$TEMP_DIR/crc-chain.pem"
        fi
    fi
fi

# Method 3: Extract from API endpoint
if [ "$CERT_EXTRACTED" = false ]; then
    echo "Attempting to extract from API endpoint..."
    if echo | openssl s_client -connect api.crc.testing:6443 -showcerts 2>/dev/null | \
       awk '/BEGIN/,/END/{ if(/BEGIN/){a++}; print}' > "$TEMP_DIR/crc-chain.pem" 2>/dev/null; then
        if [ -s "$TEMP_DIR/crc-chain.pem" ]; then
            print_success "Extracted certificate chain from API"
            CERT_EXTRACTED=true
            CERT_FILE="$TEMP_DIR/crc-chain.pem"
        fi
    fi
fi

if [ "$CERT_EXTRACTED" = false ]; then
    print_error "Failed to extract certificates from CRC"
    echo
    echo "Please ensure:"
    echo "1. CRC is running (crc start)"
    echo "2. You can access https://console-openshift-console.apps-crc.testing"
    echo
    echo "As a workaround, you can manually accept certificates in your browser:"
    echo "1. Visit https://ai-dashboard-api-argo-ai-demo.apps-crc.testing/api/health"
    echo "2. Visit https://ai-dashboard-ws-argo-ai-demo.apps-crc.testing/"
    echo "3. Accept the security warnings"
    exit 1
fi

# Display certificate information
print_section "Certificate Information"
openssl x509 -in "$CERT_FILE" -text -noout | grep -E "(Subject:|Issuer:|Not After)" | head -5

# Detect OS and offer to import
print_section "System Certificate Import"

OS="$(uname)"
case "$OS" in
    'Darwin')
        echo -e "${GREEN}Detected macOS${NC}"
        echo
        echo "The script can import the CRC certificate to your system keychain."
        echo "This will allow all applications (including browsers) to trust CRC endpoints."
        echo
        print_warning "You will be prompted for your password to import to system keychain."
        echo
        echo -e "${YELLOW}Would you like to import the certificate to your system? (y/n)${NC}"
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo "Importing certificate to macOS System Keychain..."
            if sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain "$CERT_FILE"; then
                print_success "Certificate imported successfully!"

                # Also save a copy for reference
                cp "$CERT_FILE" "$HOME/crc-certificates.pem"
                echo "Certificate chain saved to: ~/crc-certificates.pem"

                echo
                print_section "Next Steps"
                echo "1. ${YELLOW}Restart your browser completely${NC} (Quit and reopen)"
                echo "2. Clear browser cache for *.apps-crc.testing domains"
                echo "3. Access your dashboard: https://ai-dashboard-argo-ai-demo.apps-crc.testing"
                echo
                print_success "Setup complete!"
            else
                print_error "Failed to import certificate"
                echo "You may need to import manually using Keychain Access"
            fi
        else
            echo "Skipping system import."
            cp "$CERT_FILE" "$HOME/crc-certificates.pem"
            echo
            echo "Certificate chain saved to: ~/crc-certificates.pem"
            echo "You can import it manually later using:"
            echo "  sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain ~/crc-certificates.pem"
        fi
        ;;

    'Linux')
        echo -e "${GREEN}Detected Linux${NC}"
        echo
        echo "The script can import the CRC certificate to your system trust store."
        echo
        echo -e "${YELLOW}Would you like to import the certificate to your system? (y/n)${NC}"
        read -r response

        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ -f /etc/redhat-release ]; then
                echo "Detected Red Hat based system"
                sudo cp "$CERT_FILE" /etc/pki/ca-trust/source/anchors/crc-ca.crt
                sudo update-ca-trust
                print_success "Certificate imported successfully!"
            elif [ -f /etc/debian_version ]; then
                echo "Detected Debian/Ubuntu based system"
                sudo cp "$CERT_FILE" /usr/local/share/ca-certificates/crc-ca.crt
                sudo update-ca-certificates
                print_success "Certificate imported successfully!"
            else
                print_warning "Unknown Linux distribution"
                cp "$CERT_FILE" "$HOME/crc-certificates.pem"
                echo "Certificate saved to: ~/crc-certificates.pem"
                echo "Please import it manually according to your distribution's documentation"
            fi

            if [ $? -eq 0 ]; then
                echo
                print_section "Next Steps"
                echo "1. Restart your browser"
                echo "2. Clear browser cache"
                echo "3. Access your dashboard: https://ai-dashboard-argo-ai-demo.apps-crc.testing"
            fi
        else
            echo "Skipping system import."
            cp "$CERT_FILE" "$HOME/crc-certificates.pem"
            echo "Certificate chain saved to: ~/crc-certificates.pem"
        fi
        ;;

    *)
        print_warning "Unsupported OS: $OS"
        cp "$CERT_FILE" "$HOME/crc-certificates.pem"
        echo "Certificate chain saved to: ~/crc-certificates.pem"
        echo "Please import it manually according to your OS documentation"
        ;;
esac

# Test endpoints
print_section "Testing HTTPS Endpoints"

test_endpoint() {
    local url=$1
    local name=$2

    echo -n "Testing $name... "
    if curl -s -o /dev/null -w "%{http_code}" "$url" | grep -qE "^(200|404|426)$"; then
        print_success "Accessible"
    else
        print_warning "May require browser certificate acceptance"
    fi
}

echo "Testing with curl (may fail if certificate not yet trusted by curl):"
test_endpoint "https://console-openshift-console.apps-crc.testing" "OpenShift Console"
test_endpoint "https://ai-dashboard-argo-ai-demo.apps-crc.testing" "AI Dashboard"
test_endpoint "https://ai-dashboard-api-argo-ai-demo.apps-crc.testing/api/health" "Dashboard API"

echo
echo -e "${BLUE}=== Setup Complete ===${NC}"
echo
echo "If you still see certificate errors in your browser:"
echo "1. Make sure to fully restart your browser"
echo "2. Clear all cached data for *.apps-crc.testing"
echo "3. Try in an incognito/private window first"
echo "4. Some browsers may require manually accepting each subdomain's certificate"
echo
