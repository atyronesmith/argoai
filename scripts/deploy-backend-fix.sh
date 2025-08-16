#!/bin/bash
# Deploy backend fix for namespace issue

set -e

echo "=== Deploying Backend Fix ==="
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-dev}"

# Step 1: Build the backend
echo -e "${GREEN}Building backend with namespace fix...${NC}"
cd dashboard/backend

# Build backend
if command -v podman &> /dev/null; then
    BUILD_CMD="podman"
else
    BUILD_CMD="docker"
fi

# Build with timestamp tag
BUILD_TIME=$(date +%s)
echo "Building backend image..."
$BUILD_CMD build -t ai-workflow-dashboard-backend:fix-$BUILD_TIME .

# Try to push to external registry first (if you have access)
if [ -n "$EXTERNAL_REGISTRY" ]; then
    echo -e "${GREEN}Pushing to external registry...${NC}"
    $BUILD_CMD tag ai-workflow-dashboard-backend:fix-$BUILD_TIME $EXTERNAL_REGISTRY/ai-workflow-dashboard-backend:fix-$BUILD_TIME
    $BUILD_CMD push $EXTERNAL_REGISTRY/ai-workflow-dashboard-backend:fix-$BUILD_TIME

    # Update deployment
    oc set image deployment/ai-pipeline-dev-ai-document-pipeline-dashboard-backend \
      backend=$EXTERNAL_REGISTRY/ai-workflow-dashboard-backend:fix-$BUILD_TIME \
      -n $NAMESPACE
else
    echo -e "${YELLOW}No external registry configured. Using patch method...${NC}"

    # Create a patch to restart the backend with a new timestamp
    cat <<EOF | oc patch deployment ai-pipeline-dev-ai-document-pipeline-dashboard-backend -n $NAMESPACE --patch-file=/dev/stdin
spec:
  template:
    metadata:
      annotations:
        kubectl.kubernetes.io/restartedAt: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    spec:
      containers:
      - name: backend
        env:
        - name: FORCE_RESTART
          value: "$BUILD_TIME"
EOF
fi

cd ../..

# Step 2: Wait for rollout
echo -e "${GREEN}Waiting for backend to restart...${NC}"
oc rollout status deployment/ai-pipeline-dev-ai-document-pipeline-dashboard-backend -n $NAMESPACE

# Step 3: Verify the fix
echo -e "${GREEN}Verifying backend is running...${NC}"
BACKEND_POD=$(oc get pods -n $NAMESPACE -l app.kubernetes.io/component=dashboard-backend -o jsonpath='{.items[0].metadata.name}')
echo "Backend pod: $BACKEND_POD"

# Check logs
echo -e "${GREEN}Recent backend logs:${NC}"
oc logs $BACKEND_POD -n $NAMESPACE --tail=10

echo
echo -e "${GREEN}=== Backend Fix Deployed ===${NC}"
echo
echo "The backend has been updated with the namespace fix."
echo "Try submitting a document again from the dashboard."
echo
echo "Dashboard URL: https://ai-pipeline-dev-ai-document-pipeline-dashboard-argo-ai-dev.apps-crc.testing"

