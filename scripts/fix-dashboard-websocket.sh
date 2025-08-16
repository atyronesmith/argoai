#!/bin/bash
# Script to fix dashboard WebSocket connectivity issues

set -e

echo "=== Dashboard WebSocket Fix ==="
echo

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -d "dashboard" ]; then
    echo -e "${RED}Error: dashboard directory not found. Please run from project root.${NC}"
    exit 1
fi

echo -e "${BLUE}This script will fix WebSocket connectivity issues by:${NC}"
echo "1. Updating the backend to use /ws path for WebSocket"
echo "2. Creating a unified backend route for both API and WebSocket"
echo "3. Updating the frontend to use the correct endpoints"
echo "4. Rebuilding and redeploying the dashboard"
echo

echo -e "${YELLOW}Continue? (y/n)${NC}"
read -r response

if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

# Step 1: Apply the new backend route
echo -e "${GREEN}Step 1: Applying unified backend route...${NC}"
oc apply -f dashboard/k8s/backend-route-combined.yaml

# Step 2: Delete old routes
echo -e "${GREEN}Step 2: Removing old separate routes...${NC}"
oc delete route ai-dashboard-api -n argo-ai-demo --ignore-not-found=true
oc delete route ai-dashboard-ws -n argo-ai-demo --ignore-not-found=true

# Step 3: Build and push backend with WebSocket fix
echo -e "${GREEN}Step 3: Building backend with WebSocket fix...${NC}"
cd dashboard/backend

# Check if using podman or docker
if command -v podman &> /dev/null; then
    BUILD_CMD="podman"
else
    BUILD_CMD="docker"
fi

# Build backend
echo "Building backend image..."
$BUILD_CMD build -t ai-workflow-dashboard-backend:websocket-fix .

# Get registry info
REGISTRY=$(oc get route -n openshift-image-registry default-route -o jsonpath='{.spec.host}' 2>/dev/null || echo "")
if [ -z "$REGISTRY" ]; then
    echo -e "${YELLOW}Warning: Could not get OpenShift registry route. Using default.${NC}"
    REGISTRY="default-route-openshift-image-registry.apps-crc.testing"
fi

# Tag and push
IMAGE_TAG="$REGISTRY/argo-ai-demo/ai-workflow-dashboard-backend:websocket-fix"
$BUILD_CMD tag ai-workflow-dashboard-backend:websocket-fix $IMAGE_TAG
$BUILD_CMD push $IMAGE_TAG

# Update deployment
echo -e "${GREEN}Updating backend deployment...${NC}"
oc set image deployment/ai-dashboard-backend backend=$IMAGE_TAG -n argo-ai-demo

cd ../..

# Step 4: Build and push frontend with updated URLs
echo -e "${GREEN}Step 4: Building frontend with updated URLs...${NC}"
cd dashboard/frontend

# Build frontend
echo "Building frontend image..."
$BUILD_CMD build -t ai-workflow-dashboard-frontend:websocket-fix .

# Tag and push
IMAGE_TAG="$REGISTRY/argo-ai-demo/ai-workflow-dashboard-frontend:websocket-fix"
$BUILD_CMD tag ai-workflow-dashboard-frontend:websocket-fix $IMAGE_TAG
$BUILD_CMD push $IMAGE_TAG

# Update deployment
echo -e "${GREEN}Updating frontend deployment...${NC}"
oc set image deployment/ai-dashboard-frontend frontend=$IMAGE_TAG -n argo-ai-demo

cd ../..

# Step 5: Wait for rollouts
echo -e "${GREEN}Step 5: Waiting for deployments to roll out...${NC}"
oc rollout status deployment/ai-dashboard-backend -n argo-ai-demo
oc rollout status deployment/ai-dashboard-frontend -n argo-ai-demo

# Step 6: Display new URLs
echo
echo -e "${GREEN}=== WebSocket Fix Applied ===${NC}"
echo
echo "New unified backend URL:"
echo -e "${BLUE}https://ai-dashboard-backend-argo-ai-demo.apps-crc.testing${NC}"
echo
echo "Dashboard URL:"
echo -e "${BLUE}https://ai-dashboard-argo-ai-demo.apps-crc.testing${NC}"
echo
echo "The dashboard should now have working WebSocket connectivity!"
echo
echo -e "${YELLOW}Note:${NC} You may need to:"
echo "1. Clear your browser cache"
echo "2. Accept the certificate for the new backend URL"
echo "3. Refresh the dashboard page"
