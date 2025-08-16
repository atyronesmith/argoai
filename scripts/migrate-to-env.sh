#!/bin/bash

# Script to migrate existing deployment to use environment variables

set -e

echo "🔄 Migrating to Environment Variable Configuration"
echo "=================================================="
echo ""

# Load environment variables
if [ -f "scripts/load-env.sh" ]; then
    source ./scripts/load-env.sh
else
    echo "⚠️  Creating default .env file..."
    cp .env.example .env
    source ./scripts/load-env.sh
fi

# Check if logged in to OpenShift
if ! oc whoami >/dev/null 2>&1; then
    echo "❌ Not logged in to OpenShift. Please run:"
    echo "   eval \$(crc oc-env)"
    echo "   oc login -u kubeadmin -p <password> https://api.crc.testing:6443"
    exit 1
fi

PROJECT="${OPENSHIFT_PROJECT:-argo-ai-demo}"

# Check if project exists
if ! oc get project "$PROJECT" >/dev/null 2>&1; then
    echo "❌ Project $PROJECT not found"
    exit 1
fi

echo "✓ Using project: $PROJECT"
oc project "$PROJECT"

# Update MinIO credentials
echo ""
echo "📦 Updating MinIO credentials..."

# Delete old secret if exists
oc delete secret minio-creds -n "$PROJECT" --ignore-not-found=true

# Create new secret from environment variables
oc create secret generic minio-creds \
    --from-literal=accesskey="$MINIO_ACCESS_KEY" \
    --from-literal=secretkey="$MINIO_SECRET_KEY" \
    -n "$PROJECT"

echo "✓ MinIO credentials updated"

# Update MinIO deployment to use secret
echo ""
echo "🔧 Updating MinIO deployment..."

# Patch MinIO deployment to use secrets
oc patch deployment minio -n "$PROJECT" --type='json' -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/env",
    "value": [
      {
        "name": "MINIO_ROOT_USER",
        "valueFrom": {
          "secretKeyRef": {
            "name": "minio-creds",
            "key": "accesskey"
          }
        }
      },
      {
        "name": "MINIO_ROOT_PASSWORD",
        "valueFrom": {
          "secretKeyRef": {
            "name": "minio-creds",
            "key": "secretkey"
          }
        }
      }
    ]
  }
]'

echo "✓ MinIO deployment updated"

# Restart MinIO to pick up new credentials
echo ""
echo "♻️  Restarting MinIO..."
oc rollout restart deployment/minio -n "$PROJECT"
oc rollout status deployment/minio -n "$PROJECT" --timeout=120s

# Update Argo configuration
echo ""
echo "🔧 Updating Argo Workflows configuration..."

# Update workflow-controller-configmap
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: workflow-controller-configmap
  namespace: $PROJECT
data:
  artifactRepository: |
    s3:
      bucket: ${MINIO_BUCKET:-argo-artifacts}
      endpoint: ${MINIO_ENDPOINT:-minio.argo-ai-demo.svc.cluster.local:9000}
      insecure: true
      accessKeySecret:
        name: minio-creds
        key: accesskey
      secretKeySecret:
        name: minio-creds
        key: secretkey
EOF

# Restart workflow controller
echo "♻️  Restarting Argo workflow controller..."
oc rollout restart deployment/workflow-controller -n "$PROJECT"

echo ""
echo "✅ Migration Complete!"
echo ""
echo "Your deployment now uses environment variables for configuration."
echo ""
echo "Current configuration:"
echo "  MinIO Access Key: $MINIO_ACCESS_KEY"
echo "  MinIO Secret Key: ${MINIO_SECRET_KEY:0:3}***"
echo "  MinIO Endpoint: $MINIO_ENDPOINT"
echo ""
echo "To change credentials:"
echo "  1. Edit your .env file"
echo "  2. Run: source ./load-env.sh"
echo "  3. Run: ./migrate-to-env.sh"
echo ""
echo "⚠️  Note: Any existing workflows may need to be resubmitted to use new credentials."
