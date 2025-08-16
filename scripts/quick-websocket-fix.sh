#!/bin/bash
# Quick fix for WebSocket connectivity

set -e

echo "=== Quick WebSocket Fix ==="
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Check current frontend deployment
echo -e "${GREEN}Checking current frontend deployment...${NC}"
NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-dev}"
CURRENT_IMAGE=$(oc get deployment ai-dashboard-frontend -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "Not found")
echo "Current frontend image: $CURRENT_IMAGE"

# Step 2: Force rebuild frontend with cache bust
echo -e "${GREEN}Rebuilding frontend with latest code...${NC}"
cd dashboard/frontend

# Create a build timestamp to force cache invalidation
BUILD_TIME=$(date +%s)
echo "export const BUILD_TIME = '$BUILD_TIME';" > src/buildInfo.ts

# Build with no-cache
if command -v podman &> /dev/null; then
    podman build --no-cache -t ai-workflow-dashboard-frontend:fix-$BUILD_TIME .

    # Get registry - use internal registry URL for better reliability
    REGISTRY="image-registry.openshift-image-registry.svc:5000"

    # Tag and push
    podman tag ai-workflow-dashboard-frontend:fix-$BUILD_TIME $REGISTRY/$NAMESPACE/ai-workflow-dashboard-frontend:fix-$BUILD_TIME
    podman push $REGISTRY/$NAMESPACE/ai-workflow-dashboard-frontend:fix-$BUILD_TIME

    # Update deployment
    oc set image deployment/ai-dashboard-frontend frontend=$REGISTRY/$NAMESPACE/ai-workflow-dashboard-frontend:fix-$BUILD_TIME -n $NAMESPACE
else
    echo -e "${RED}Podman not found. Please install podman or use docker.${NC}"
    exit 1
fi

cd ../..

# Step 3: Force pod restart
echo -e "${GREEN}Restarting frontend pods...${NC}"
oc delete pods -l app=ai-dashboard-frontend -n $NAMESPACE

# Step 4: Wait for rollout
echo -e "${GREEN}Waiting for new pods...${NC}"
oc rollout status deployment/ai-dashboard-frontend -n $NAMESPACE

# Step 5: Clear instructions
echo
echo -e "${GREEN}=== Fix Applied ===${NC}"
echo
echo "Please do the following:"
echo "1. ${YELLOW}Clear your browser cache completely${NC}"
echo "   - Chrome: Cmd+Shift+Delete → Clear browsing data"
echo "   - Or open Developer Tools → Network tab → Disable cache"
echo
echo "2. ${YELLOW}Open the dashboard in a new incognito/private window${NC}"
echo "   - This ensures no cached JavaScript is used"
echo
echo "3. ${YELLOW}Check the browser console for debug output${NC}"
echo "   - You should see 'Window location:' with your current URL"
echo "   - You should see 'WebSocket URL:' with the correct wss:// URL"
echo
echo "Dashboard URL: https://ai-dashboard-$NAMESPACE.apps-crc.testing"
