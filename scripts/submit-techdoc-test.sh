#!/bin/bash
oc create -f - <<EOFW
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ai-techdoc-test-
  namespace: argo-ai-demo
spec:
  workflowTemplateRef:
    name: ai-document-processor
  arguments:
    parameters:
    - name: doc-url
      value: "https://raw.githubusercontent.com/kubernetes/kubernetes/master/README.md"
    - name: model
      value: "llama3.2:3b"
EOFW
