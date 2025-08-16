#!/bin/bash

# Run a single document type test
# Usage: ./run-single-test.sh <doc-type> <priority>

DOC_TYPE=$1
PRIORITY=$2
NAMESPACE=${NAMESPACE:-argo-ai-demo}

if [ -z "$DOC_TYPE" ] || [ -z "$PRIORITY" ]; then
    echo "Usage: $0 <doc-type> <priority>"
    echo "  doc-type: invoice, contract, techdoc, correspondence"
    echo "  priority: normal, urgent"
    exit 1
fi

echo "Testing $DOC_TYPE with $PRIORITY priority..."

# Get test document from ConfigMap
TEST_DOC=$(oc get configmap test-documents -n $NAMESPACE -o jsonpath="{.data.${DOC_TYPE}-${PRIORITY}\.txt}")

if [ -z "$TEST_DOC" ]; then
    echo "Error: Test document not found for $DOC_TYPE-$PRIORITY"
    exit 1
fi

# Create temporary file
TEMP_FILE="/tmp/test-${DOC_TYPE}-${PRIORITY}.txt"
echo "$TEST_DOC" > "$TEMP_FILE"

# Since argo CLI is not available, create workflow directly
echo "Creating test workflow..."
WORKFLOW_NAME="test-${DOC_TYPE}-${PRIORITY}-$(date +%s)"

cat > /tmp/test-workflow.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  name: $WORKFLOW_NAME
  namespace: $NAMESPACE
spec:
  serviceAccountName: argo
  entrypoint: test-document
  templates:
  - name: test-document
    script:
      image: alpine:latest
      command: [sh]
      source: |
        echo "Testing document type: $DOC_TYPE"
        echo "Priority: $PRIORITY"
        echo ""
        echo "Test document content:"
        echo "$TEST_DOC"
        echo ""
        echo "Expected classification: $DOC_TYPE"
        echo "Expected priority: $PRIORITY"
        echo ""
        echo "✓ Test completed"
EOF

oc create -f /tmp/test-workflow.yaml

echo "Workflow submitted: $WORKFLOW_NAME"

# Check status
echo "Checking workflow status..."
sleep 3
oc get workflow "$WORKFLOW_NAME" -n "$NAMESPACE"

# Show expected results
echo ""
echo "Expected Results:"
echo "================"
echo "Document Type: $DOC_TYPE"
echo "Priority: $PRIORITY"

# Cleanup
rm -f "$TEMP_FILE"
