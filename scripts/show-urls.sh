#!/bin/bash

# Display service URLs for AI Document Pipeline

echo "============================================"
echo "🌐 AI Document Pipeline Service URLs"
echo "============================================"
echo ""

# Get namespace from environment or use default
NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-demo}"

# Check if logged in
if ! oc whoami &> /dev/null; then
    echo "❌ Not logged into OpenShift"
    echo "Please run: source ./setup-env.sh"
    exit 1
fi

# Get routes
ARGO_ROUTE=$(oc get route argo-server -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
MINIO_CONSOLE_ROUTE=$(oc get route minio-console -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
MINIO_API_ROUTE=$(oc get route minio-api -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")
OLLAMA_ROUTE=$(oc get route ollama -n "$NAMESPACE" -o jsonpath='{.spec.host}' 2>/dev/null || echo "Not available")

echo "📊 Argo Workflows UI:"
echo "   https://$ARGO_ROUTE"
echo ""
echo "📦 MinIO Console:"
echo "   https://$MINIO_CONSOLE_ROUTE"
echo "   Username: admin"
echo "   Password: changeme123"
echo ""
echo "🤖 Ollama API:"
echo "   https://$OLLAMA_ROUTE"
echo ""
echo "🔗 MinIO API (S3):"
echo "   https://$MINIO_API_ROUTE"
echo ""
echo "============================================"
echo ""
echo "To check pod status:"
echo "  oc get pods -n $NAMESPACE"
echo ""
echo "To view logs:"
echo "  oc logs -n $NAMESPACE deployment/argo-server"
echo ""
echo "To submit a test workflow:"
echo "  ./scripts/submit-test-workflow.sh"
