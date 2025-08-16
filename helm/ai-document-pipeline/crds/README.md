# CRD Installation

Helm 3 automatically installs CRDs placed in the `crds/` directory during `helm install`.

## Important Notes:

1. CRDs in this directory are installed **before** other chart resources
2. CRDs are **NOT** removed during `helm uninstall` (this is by design to prevent data loss)
3. CRDs are **NOT** upgraded during `helm upgrade` (to prevent breaking changes)
4. To update CRDs, you must manually apply them using `kubectl apply`

## Manual CRD Management

If you need to manually manage CRDs:

```bash
# Install/Update CRDs
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-workflows/v3.5.2/manifests/base/crds/full/argoproj.io_workflows.yaml
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/v1.9.0/manifests/crds/argoproj.io_eventbus.yaml

# Remove CRDs (WARNING: This will delete all resources of these types!)
kubectl delete crd workflows.argoproj.io
kubectl delete crd eventbus.argoproj.io
```

## Why External URLs?

We're downloading CRDs from official sources rather than bundling them because:
1. Ensures we always get the correct version matching our Argo components
2. Reduces repository size
3. Makes version updates easier
