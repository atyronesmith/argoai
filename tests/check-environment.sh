#!/bin/bash

# Comprehensive environment check for AI Pipeline tests

echo "🔍 Checking test environment..."
echo "================================"

ERRORS=0
WARNINGS=0

# Check for oc CLI
echo -n "OpenShift CLI (oc)... "
if command -v oc >/dev/null 2>&1; then
    echo "✓ Found"
else
    echo "✗ Not found"
    ERRORS=$((ERRORS + 1))
fi

# Check OpenShift login
echo -n "OpenShift login... "
if command -v oc >/dev/null 2>&1 && oc whoami >/dev/null 2>&1; then
    USER=$(oc whoami)
    echo "✓ Logged in as $USER"
else
    echo "✗ Not logged in"
    ERRORS=$((ERRORS + 1))
fi

# Check current project
echo -n "OpenShift project... "
if command -v oc >/dev/null 2>&1 && oc project >/dev/null 2>&1; then
    PROJECT=$(oc project -q)
    if [ "$PROJECT" = "argo-ai-demo" ]; then
        echo "✓ $PROJECT"
    else
        echo "⚠ $PROJECT (expected: argo-ai-demo)"
        WARNINGS=$((WARNINGS + 1))
    fi
else
    echo "✗ Cannot determine"
    ERRORS=$((ERRORS + 1))
fi

# Check for argo CLI (optional)
echo -n "Argo CLI... "
if command -v argo >/dev/null 2>&1; then
    echo "✓ Found (optional)"
else
    echo "⚠ Not found (optional - tests will use oc instead)"
    WARNINGS=$((WARNINGS + 1))
fi

# Check for curl
echo -n "curl... "
if command -v curl >/dev/null 2>&1; then
    echo "✓ Found"
else
    echo "✗ Not found"
    ERRORS=$((ERRORS + 1))
fi

# Check for jq (optional but useful)
echo -n "jq... "
if command -v jq >/dev/null 2>&1; then
    echo "✓ Found (optional)"
else
    echo "⚠ Not found (optional - some features may be limited)"
    WARNINGS=$((WARNINGS + 1))
fi

echo "================================"

# Summary and instructions
if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "❌ Environment check FAILED with $ERRORS error(s)"
    echo ""
    echo "To fix the errors, run these commands from the project root:"
    echo ""
    echo "  cd $(dirname $(pwd))"
    echo "  source ./setup-env.sh"
    echo "  cd tests"
    echo ""
    echo "The setup-env.sh script will:"
    echo "  • Set up the OpenShift CLI environment"
    echo "  • Log you into OpenShift"
    echo "  • Configure helpful aliases and functions"
    echo "  • Set the correct project context"
    echo ""
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    echo ""
    echo "⚠️  Environment check passed with $WARNINGS warning(s)"
    echo ""
    echo "Tests can run but some features may be limited."
    echo "For the best experience, consider:"
    if ! command -v argo >/dev/null 2>&1; then
        echo "  • Installing Argo CLI: https://github.com/argoproj/argo-workflows/releases"
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo "  • Installing jq: https://stedolan.github.io/jq/download/"
    fi
    echo ""
else
    echo ""
    echo "✅ Environment check PASSED - all requirements met!"
    echo ""
fi

# Show available test commands
echo "Available test commands:"
echo "  make quick              - Run quick connectivity tests"
echo "  make validate           - Validate environment"
echo "  make full               - Run full test suite"
echo "  make test-invoice       - Test invoice processing"
echo "  make test-contract      - Test contract processing"
echo "  make test-techdoc       - Test technical documentation"
echo "  make test-correspondence - Test correspondence"
echo ""
