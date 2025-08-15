#!/bin/bash

# URL Configuration Helper
# This script helps configure URLs for different OpenShift environments

# Default to CRC for local development
CLUSTER_DOMAIN="${CLUSTER_DOMAIN:-apps-crc.testing}"

# Check if running on OpenShift
if command -v oc >/dev/null 2>&1; then
    # Try to detect the cluster domain
    DETECTED_DOMAIN=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' 2>/dev/null)
    if [ -n "$DETECTED_DOMAIN" ]; then
        CLUSTER_DOMAIN="$DETECTED_DOMAIN"
        echo "Detected OpenShift cluster domain: $CLUSTER_DOMAIN"
    fi
fi

# Export URLs based on the cluster domain
export ARGO_URL="https://argo-server-${OPENSHIFT_PROJECT:-argo-ai-demo}.${CLUSTER_DOMAIN}"
export MINIO_CONSOLE_URL="https://minio-console-${OPENSHIFT_PROJECT:-argo-ai-demo}.${CLUSTER_DOMAIN}"
export OLLAMA_URL="https://ollama-${OPENSHIFT_PROJECT:-argo-ai-demo}.${CLUSTER_DOMAIN}"
export OPENSHIFT_CONSOLE_URL="https://console-openshift-console.${CLUSTER_DOMAIN}"

# Function to get service URLs
get_service_urls() {
    echo "Service URLs for cluster domain: $CLUSTER_DOMAIN"
    echo "================================================"
    echo "Argo Workflows UI: $ARGO_URL"
    echo "MinIO Console: $MINIO_CONSOLE_URL"
    echo "Ollama API: $OLLAMA_URL"
    echo "OpenShift Console: $OPENSHIFT_CONSOLE_URL"
}

# If sourced, just export variables
# If executed, show the URLs
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    get_service_urls
fi
