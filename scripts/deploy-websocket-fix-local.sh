#!/bin/bash
# Deploy WebSocket fix using local build

set -e

echo "=== Deploying WebSocket Fix Locally ==="
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-dev}"

# Step 1: Check if the deployment exists
echo -e "${GREEN}Checking current deployment...${NC}"
if ! oc get deployment ai-dashboard-frontend -n $NAMESPACE &>/dev/null; then
    # Check with different naming conventions
    FRONTEND_DEPLOYMENT=$(oc get deployments -n $NAMESPACE -o name | grep -i "dashboard.*frontend" | head -1 | cut -d'/' -f2)
    if [ -z "$FRONTEND_DEPLOYMENT" ]; then
        echo -e "${RED}Error: No frontend deployment found in namespace $NAMESPACE${NC}"
        echo "Available deployments:"
        oc get deployments -n $NAMESPACE
        exit 1
    fi
else
    FRONTEND_DEPLOYMENT="ai-dashboard-frontend"
fi

echo "Using deployment: $FRONTEND_DEPLOYMENT"

# Step 2: Build the frontend locally
echo -e "${GREEN}Building frontend with WebSocket fix...${NC}"
cd dashboard/frontend

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build the frontend
echo "Building production bundle..."
npm run build

# Step 3: Create a ConfigMap with the built files
echo -e "${GREEN}Creating ConfigMap with built files...${NC}"
cd build

# Create configmap from the build directory
oc create configmap frontend-build-fix \
    --from-file=. \
    --dry-run=client -o yaml | \
    oc apply -n $NAMESPACE -f -

cd ../../..

# Step 4: Patch the deployment to use the new build
echo -e "${GREEN}Patching deployment to use fixed build...${NC}"

# Create a patch that mounts the configmap
cat <<EOF | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-nginx-config-fix
  namespace: $NAMESPACE
data:
  nginx.conf: |
    worker_processes auto;
    error_log /dev/stderr;
    pid /tmp/nginx.pid;

    events {
        worker_connections 1024;
    }

    http {
        log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                        '\$status \$body_bytes_sent "\$http_referer" '
                        '"\$http_user_agent" "\$http_x_forwarded_for"';

        access_log /dev/stdout main;
        client_body_temp_path /tmp/client_temp;
        proxy_temp_path /tmp/proxy_temp_path;
        fastcgi_temp_path /tmp/fastcgi_temp;
        uwsgi_temp_path /tmp/uwsgi_temp;
        scgi_temp_path /tmp/scgi_temp;

        include /etc/nginx/mime.types;
        default_type application/octet-stream;

        server {
            listen 8080;
            server_name _;
            root /opt/app-root/src;
            index index.html;

            location / {
                try_files \$uri \$uri/ /index.html;
                add_header Cache-Control "no-cache, no-store, must-revalidate";
            }

            location /static/ {
                expires 1y;
                add_header Cache-Control "public, immutable";
            }

            location /api/ {
                proxy_pass http://ai-dashboard-backend:3001;
                proxy_set_header Host \$host;
                proxy_set_header X-Real-IP \$remote_addr;
            }
        }
    }
EOF

# Step 5: Restart the frontend pods
echo -e "${GREEN}Restarting frontend pods...${NC}"
oc delete pods -l deployment=$FRONTEND_DEPLOYMENT -n $NAMESPACE

# Wait for rollout
echo -e "${GREEN}Waiting for pods to restart...${NC}"
sleep 5
oc wait --for=condition=ready pod -l deployment=$FRONTEND_DEPLOYMENT -n $NAMESPACE --timeout=120s

echo
echo -e "${GREEN}=== WebSocket Fix Deployed ===${NC}"
echo
echo "The frontend has been updated with the WebSocket fix."
echo
echo -e "${YELLOW}IMPORTANT:${NC}"
echo "1. Clear your browser cache completely (Cmd+Shift+Delete)"
echo "2. Open the dashboard in an incognito/private window"
echo "3. The WebSocket errors should now be resolved"
echo
echo "Dashboard URL: https://$FRONTEND_DEPLOYMENT-$NAMESPACE.apps-crc.testing"
echo

# Show the pod logs to verify
echo -e "${GREEN}Frontend pod logs:${NC}"
oc logs -l deployment=$FRONTEND_DEPLOYMENT -n $NAMESPACE --tail=20

