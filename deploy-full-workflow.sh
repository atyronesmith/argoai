#!/bin/bash

# Script to deploy the full AI document processing workflow template
# This replaces the simplified version with the complete implementation

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

print_info "Deploying Full AI Document Processing Workflow Template"
echo "===================================================="

# Check if simplified template exists and delete it
if oc get workflowtemplate ai-document-processor -n argo-ai-demo >/dev/null 2>&1; then
    print_warning "Existing simplified workflow template found. Replacing with full version..."
    oc delete workflowtemplate ai-document-processor -n argo-ai-demo
    sleep 2
fi

# Apply the full workflow template
print_info "Deploying full workflow template..."
oc apply -f ai-workflow-template-full.yaml

# Verify deployment
if oc get workflowtemplate ai-document-processor -n argo-ai-demo >/dev/null 2>&1; then
    print_success "Full workflow template deployed successfully!"
else
    print_error "Failed to deploy workflow template"
    exit 1
fi

# Get template details
print_info "Workflow template details:"
oc describe workflowtemplate ai-document-processor -n argo-ai-demo | grep -A 10 "Spec:"

echo ""
print_info "Full AI Document Processing Workflow Features:"
echo "=============================================="
echo "✓ Model initialization and checking"
echo "✓ Document ingestion from URL"
echo "✓ AI-powered document classification (6 types)"
echo "✓ Priority detection (urgent/normal/low)"
echo "✓ Type-specific information extraction"
echo "✓ Intelligent routing based on type and priority"
echo "✓ Executive report generation"
echo "✓ Full artifact storage in MinIO"
echo "✓ Processing metrics and monitoring"
echo ""

# Create test scripts
print_info "Creating test workflow submission scripts..."

# Test with invoice
cat > submit-invoice-test.sh <<'EOF'
#!/bin/bash
oc create -f - <<EOFW
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ai-invoice-test-
  namespace: argo-ai-demo
spec:
  workflowTemplateRef:
    name: ai-document-processor
  arguments:
    parameters:
    - name: doc-url
      value: "https://raw.githubusercontent.com/argoproj/argo-workflows/master/examples/README.md"
    - name: model
      value: "llama3.2:3b"
EOFW
EOF

# Test with technical doc
cat > submit-techdoc-test.sh <<'EOF'
#!/bin/bash
oc create -f - <<EOFW
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ai-techdoc-test-
  namespace: argo-ai-demo
spec:
  workflowTemplateRef:
    name: ai-document-processor
  arguments:
    parameters:
    - name: doc-url
      value: "https://raw.githubusercontent.com/kubernetes/kubernetes/master/README.md"
    - name: model
      value: "llama3.2:3b"
EOFW
EOF

chmod +x submit-invoice-test.sh submit-techdoc-test.sh

print_success "Test scripts created: submit-invoice-test.sh and submit-techdoc-test.sh"
echo ""

# Show usage
print_info "Usage Examples:"
echo "=============="
echo ""
echo "1. Submit a workflow with the full template:"
echo "   ./submit-test-workflow.sh -d 'https://example.com/document.pdf'"
echo ""
echo "2. Test with invoice processing:"
echo "   ./submit-invoice-test.sh"
echo ""
echo "3. Test with technical documentation:"
echo "   ./submit-techdoc-test.sh"
echo ""
echo "4. Monitor workflow execution:"
echo "   argo watch -n argo-ai-demo @latest"
echo ""
echo "5. View in Argo UI:"
echo "   https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"
echo ""

print_info "The full workflow includes these steps:"
echo "1. Initialize/verify Ollama model"
echo "2. Download and ingest document"
echo "3. Classify document type and priority using AI"
echo "4. Extract type-specific information"
echo "5. Route for processing based on type/priority"
echo "6. Generate executive report with AI"
echo ""

print_warning "Note: First run may take longer as models initialize"
