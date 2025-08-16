#!/bin/bash
# Script to remove dashboard deployment from default namespace (argo-ai-demo)

echo "════════════════════════════════════════════════════════════════"
echo "Removing dashboard deployment from argo-ai-demo namespace"
echo "════════════════════════════════════════════════════════════════"

# Use kubectl or oc, whichever is available
KUBECTL=$(command -v oc || command -v kubectl)

if [ -z "$KUBECTL" ]; then
    echo "Error: Neither 'oc' nor 'kubectl' found in PATH"
    exit 1
fi

echo "Using: $KUBECTL"
echo ""

# Remove deployments
echo "Removing deployments..."
$KUBECTL delete deployment ai-dashboard-backend -n argo-ai-demo --ignore-not-found=true
$KUBECTL delete deployment ai-dashboard-frontend -n argo-ai-demo --ignore-not-found=true

# Remove services
echo "Removing services..."
$KUBECTL delete service ai-dashboard-backend -n argo-ai-demo --ignore-not-found=true
$KUBECTL delete service ai-dashboard-frontend -n argo-ai-demo --ignore-not-found=true

# Remove routes (OpenShift specific)
echo "Removing routes..."
$KUBECTL delete route ai-dashboard -n argo-ai-demo --ignore-not-found=true
$KUBECTL delete route ai-dashboard-api -n argo-ai-demo --ignore-not-found=true
$KUBECTL delete route ai-dashboard-backend -n argo-ai-demo --ignore-not-found=true
$KUBECTL delete route ai-dashboard-ws -n argo-ai-demo --ignore-not-found=true

# Remove the combined backend route if it exists
$KUBECTL delete route ai-dashboard-backend-combined -n argo-ai-demo --ignore-not-found=true

# Remove configmaps
echo "Removing configmaps..."
$KUBECTL delete configmap dashboard-config -n argo-ai-demo --ignore-not-found=true

# Remove PVC for SQLite
echo "Removing persistent volume claims..."
$KUBECTL delete pvc dashboard-sqlite-pvc -n argo-ai-demo --ignore-not-found=true

# Remove service account if exists
echo "Removing service account..."
$KUBECTL delete serviceaccount ai-dashboard -n argo-ai-demo --ignore-not-found=true

# Check what's left
echo ""
echo "Checking remaining dashboard resources..."
$KUBECTL get all,pvc,configmap -n argo-ai-demo | grep -i dashboard || echo "No dashboard resources found"

echo ""
echo "✓ Dashboard removal from argo-ai-demo namespace complete!"
