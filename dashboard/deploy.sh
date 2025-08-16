#!/bin/bash

set -e

# AI Workflow Dashboard Deployment Script for OpenShift
# This script deploys the complete dashboard to OpenShift

echo "🚀 Deploying AI Workflow Dashboard to OpenShift..."

# Check if oc is available
if ! command -v oc &> /dev/null; then
    echo "❌ OpenShift CLI (oc) is not installed or not in PATH"
    exit 1
fi

# Check if we're logged into OpenShift
if ! oc whoami &> /dev/null; then
    echo "❌ Not logged into OpenShift. Please run 'oc login' first"
    exit 1
fi

# Set namespace
NAMESPACE=${NAMESPACE:-argo-ai-demo}
echo "📁 Using namespace: $NAMESPACE"

# Create namespace if it doesn't exist
echo "📦 Creating namespace..."
oc apply -f k8s/namespace.yaml

# Apply RBAC
echo "🔐 Setting up RBAC..."
oc apply -f k8s/rbac.yaml

# Deploy backend
echo "⚙️  Deploying backend..."
oc apply -f k8s/backend-deployment.yaml

# Wait for backend to be ready
echo "⏳ Waiting for backend to be ready..."
oc wait --for=condition=available --timeout=300s deployment/ai-dashboard-backend -n $NAMESPACE

# Deploy frontend
echo "🎨 Deploying frontend..."
oc apply -f k8s/frontend-deployment.yaml

# Wait for frontend to be ready
echo "⏳ Waiting for frontend to be ready..."
oc wait --for=condition=available --timeout=300s deployment/ai-dashboard-frontend -n $NAMESPACE

# Create routes
echo "🌐 Creating routes..."
oc apply -f k8s/route.yaml

# Get route URLs
echo "✅ Deployment complete!"
echo ""
echo "📋 Access Information:"
echo "====================="

DASHBOARD_URL=$(oc get route ai-dashboard -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "Route not found")
API_URL=$(oc get route ai-dashboard-api -n $NAMESPACE -o jsonpath='{.spec.host}' 2>/dev/null || echo "Route not found")

if [ "$DASHBOARD_URL" != "Route not found" ]; then
    echo "🎯 Dashboard: https://$DASHBOARD_URL"
else
    echo "⚠️  Dashboard route not available yet"
fi

if [ "$API_URL" != "Route not found" ]; then
    echo "🔌 API: https://$API_URL"
else
    echo "⚠️  API route not available yet"
fi

echo ""
echo "📊 Status Check:"
echo "================"
oc get pods -n $NAMESPACE -l app=ai-dashboard-backend,app=ai-dashboard-frontend

echo ""
echo "🔍 Useful Commands:"
echo "=================="
echo "View logs: oc logs -f deployment/ai-dashboard-backend -n $NAMESPACE"
echo "View events: oc get events -n $NAMESPACE --sort-by=.metadata.creationTimestamp"
echo "Port forward: oc port-forward svc/ai-dashboard-frontend 8080:8080 -n $NAMESPACE"

echo ""
echo "🎉 AI Workflow Dashboard is now deployed!"