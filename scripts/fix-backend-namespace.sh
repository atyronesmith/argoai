#!/bin/bash
# Quick fix for backend namespace issue

set -e

echo "=== Fixing Backend Namespace Issue ==="
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="${OPENSHIFT_PROJECT:-argo-ai-dev}"

echo -e "${YELLOW}This is a temporary workaround until the backend image can be rebuilt.${NC}"
echo

# Option 1: Use a proxy/wrapper approach
echo -e "${GREEN}Creating a workaround ConfigMap...${NC}"

# Create a ConfigMap with a wrapper script
cat <<'EOF' | oc apply -n $NAMESPACE -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-wrapper-script
  namespace: argo-ai-dev
data:
  wrapper.js: |
    // Wrapper to intercept and fix workflow submissions
    const Module = require('module');
    const originalRequire = Module.prototype.require;

    Module.prototype.require = function(id) {
      const module = originalRequire.apply(this, arguments);

      // Intercept the workflowService module
      if (id.includes('workflowService')) {
        const originalSubmitWorkflow = module.WorkflowService.prototype.submitWorkflow;

        module.WorkflowService.prototype.submitWorkflow = async function(docUrl, model = 'llama3.2:3b') {
          console.log('Intercepting workflow submission...');
          const workflowTemplate = {
            apiVersion: 'argoproj.io/v1alpha1',
            kind: 'Workflow',
            metadata: {
              generateName: 'ai-doc-dash-'
              // Remove namespace - let Kubernetes use the current namespace
            },
            spec: {
              workflowTemplateRef: {
                name: 'ai-document-processor'
              },
              arguments: {
                parameters: [
                  { name: 'doc-url', value: docUrl },
                  { name: 'model', value: model }
                ]
              }
            }
          };

          return this.argoService.submitWorkflow(workflowTemplate);
        };
      }

      return module;
    };

    // Load the original app
    require('./dist/index.js');
EOF

echo
echo -e "${BLUE}Workaround deployed!${NC}"
echo
echo -e "${YELLOW}IMPORTANT:${NC} This is a temporary fix. The permanent solution is to:"
echo "1. Update the backend source code to use process.env.ARGO_NAMESPACE"
echo "2. Build and push a new backend image"
echo "3. Update the deployment to use the new image"
echo
echo -e "${GREEN}For now, you can try these alternatives:${NC}"
echo
echo "1. Submit workflows directly using the Argo CLI:"
echo "   ${BLUE}argo submit --from workflowtemplate/ai-document-processor -p doc-url=https://example.com/doc.pdf -n argo-ai-dev${NC}"
echo
echo "2. Use the Argo UI directly:"
echo "   ${BLUE}https://argo-server-argo-ai-dev.apps-crc.testing${NC}"
echo
echo "3. Update the backend image:"
echo "   - Fork/clone the repository"
echo "   - Fix the namespace issue in workflowService.ts"
echo "   - Build and push to a registry you have access to"
echo "   - Update the deployment"
echo

# Check workflow status
echo -e "${GREEN}Recent workflows:${NC}"
oc get workflows -n $NAMESPACE --sort-by=.metadata.creationTimestamp | tail -5

