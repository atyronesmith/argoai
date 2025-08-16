#!/bin/bash

# Load environment variables for the AI Document Processing Pipeline
# This script should be sourced: source ./load-env.sh

# Check if .env file exists
if [ -f .env ]; then
    echo "Loading environment variables from .env file..."
    set -a  # automatically export all variables
    source .env
    set +a  # turn off automatic export
    echo "✓ Environment variables loaded"
else
    echo "⚠️  No .env file found. Using defaults from .env.example"
    echo "   Copy .env.example to .env and customize for your environment"

    # Load defaults
    export MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
    export MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-changeme}"
    export MINIO_ENDPOINT="${MINIO_ENDPOINT:-minio.argo-ai-demo.svc.cluster.local:9000}"
    export MINIO_BUCKET="${MINIO_BUCKET:-argo-artifacts}"
    export OPENSHIFT_PROJECT="${OPENSHIFT_PROJECT:-argo-ai-demo}"
    export OPENSHIFT_API_URL="${OPENSHIFT_API_URL:-https://api.crc.testing:6443}"
    export ARGO_NAMESPACE="${ARGO_NAMESPACE:-argo-ai-demo}"
    export ARGO_SERVICE_ACCOUNT="${ARGO_SERVICE_ACCOUNT:-argo}"
fi

# Display loaded configuration (hide sensitive parts)
echo ""
echo "Current Configuration:"
echo "---------------------"
echo "MinIO Access Key: ${MINIO_ACCESS_KEY}"
echo "MinIO Secret Key: ${MINIO_SECRET_KEY:0:3}***"
echo "MinIO Endpoint: ${MINIO_ENDPOINT}"
echo "OpenShift Project: ${OPENSHIFT_PROJECT}"
echo "OpenShift API: ${OPENSHIFT_API_URL}"
echo ""

# Warn if using default credentials
if [ "$MINIO_SECRET_KEY" = "changeme" ] || [ "$MINIO_SECRET_KEY" = "password123" ]; then
    echo "⚠️  WARNING: Using default MinIO credentials!"
    echo "   Please update MINIO_SECRET_KEY in your .env file"
    echo ""
fi
