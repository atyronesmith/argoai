#!/bin/bash

# Script to prepare the repository for public release
# This removes or updates sensitive information

set -e

echo "🔐 Preparing repository for public release..."
echo "============================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create .env.example if it doesn't exist
if [ ! -f .env.example ]; then
    echo -e "${GREEN}✓${NC} Creating .env.example..."
    cat > .env.example << 'EOF'
# AI-Enhanced Document Processing Pipeline Configuration
# Copy this file to .env and update with your values

# MinIO Configuration
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=changeme
MINIO_ENDPOINT=minio.argo-ai-demo.svc.cluster.local:9000
MINIO_BUCKET=argo-artifacts

# OpenShift/Kubernetes Configuration
OPENSHIFT_PROJECT=argo-ai-demo
OPENSHIFT_API_URL=https://api.crc.testing:6443

# Argo Workflows Configuration
ARGO_NAMESPACE=argo-ai-demo
ARGO_SERVICE_ACCOUNT=argo

# Ollama Configuration
OLLAMA_MODELS=llama3.2:3b,mistral:7b,phi3:mini,gemma2:2b

# Security Settings
INSECURE_SKIP_TLS_VERIFY=true  # Set to false for production
ENABLE_DEBUG_LOGGING=false
EOF
else
    echo -e "${YELLOW}!${NC} .env.example already exists"
fi

# Check for hardcoded passwords
echo ""
echo "🔍 Checking for hardcoded credentials..."
echo "----------------------------------------"

# Check for password123
echo -e "\n${YELLOW}Files containing 'password123':${NC}"
PASS_FILES=$(grep -r "password123" --include="*.sh" --include="*.yaml" --include="*.yml" --include="*.md" . 2>/dev/null | grep -v ".git" | cut -d: -f1 | sort | uniq)
if [ -n "$PASS_FILES" ]; then
    echo "$PASS_FILES" | while read -r file; do
        echo -e "${RED}✗${NC} $file"
    done
else
    echo -e "${GREEN}✓${NC} No files found with hardcoded password"
fi

# Check for admin credentials
echo -e "\n${YELLOW}Files containing MinIO 'admin' credentials:${NC}"
ADMIN_FILES=$(grep -r "accesskey: admin" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v ".git" | cut -d: -f1 | sort | uniq)
if [ -n "$ADMIN_FILES" ]; then
    echo "$ADMIN_FILES" | while read -r file; do
        echo -e "${RED}✗${NC} $file"
    done
else
    echo -e "${GREEN}✓${NC} No files found with hardcoded admin credentials"
fi

# Check for pull-secret references
echo -e "\n${YELLOW}Files referencing pull secrets:${NC}"
PULL_FILES=$(grep -r "pull-secret" --include="*.sh" --include="*.md" . 2>/dev/null | grep -v ".git" | grep -v "^Binary file" | cut -d: -f1 | sort | uniq)
if [ -n "$PULL_FILES" ]; then
    echo "$PULL_FILES" | while read -r file; do
        echo -e "${YELLOW}!${NC} $file (verify it doesn't contain actual secrets)"
    done
fi

# Security recommendations
echo ""
echo "📋 Security Checklist:"
echo "====================="
echo ""
echo "Before making this repository public, ensure you have:"
echo ""
echo "1. [ ] Updated all files to use environment variables instead of hardcoded credentials"
echo "2. [ ] Removed any actual pull secrets or tokens from the code"
echo "3. [ ] Updated documentation to use placeholder values (e.g., <your-password>)"
echo "4. [ ] Added security warnings in README about not committing secrets"
echo "5. [ ] Verified .gitignore includes all sensitive file patterns"
echo "6. [ ] Removed any company-specific or personal information"
echo "7. [ ] Updated URLs to be generic (not .apps-crc.testing specific)"
echo ""

# Offer to create a security-enhanced version of a script
echo "📝 Example: Converting hardcoded credentials to environment variables"
echo "====================================================================="
echo ""
echo "Instead of:"
echo "  value: password123"
echo ""
echo "Use:"
echo "  valueFrom:"
echo "    secretKeyRef:"
echo "      name: minio-creds"
echo "      key: secretkey"
echo ""

# Summary
echo "🎯 Summary"
echo "=========="
echo ""
if [ -n "$PASS_FILES" ] || [ -n "$ADMIN_FILES" ]; then
    echo -e "${RED}⚠️  CRITICAL:${NC} Hardcoded credentials found in the repository!"
    echo "   Please update these files before making the repository public."
else
    echo -e "${GREEN}✓${NC} No obvious hardcoded credentials found."
fi
echo ""
echo "Remember to:"
echo "- Review all files manually for any sensitive information"
echo "- Test that everything works with environment variables"
echo "- Add a SECURITY.md file with security best practices"
echo ""
echo "Run this script again after making changes to verify all issues are resolved."
