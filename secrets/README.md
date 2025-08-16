# Secrets Directory

This directory contains configuration files with sensitive or environment-specific settings.

## CRC Pull Secret

The `pull-secret.txt` file contains the Red Hat pull secret required for running CodeReady Containers (CRC).

### Setup

1. Copy the example file:
   ```bash
   cp pull-secret.txt.example pull-secret.txt
   ```

2. Get your pull secret from Red Hat:
   - Go to https://console.redhat.com/openshift/create/local
   - Log in with your Red Hat account
   - Click "Download pull secret"
   - Copy the entire JSON content into `pull-secret.txt`

3. The setup script will automatically use this pull secret when starting CRC.

### Security

- The `pull-secret.txt` file is ignored by git to prevent accidental commits
- Never share your pull secret as it contains authentication credentials
- Keep this file secure and treat it as a password

## Registry Configuration

The `registry.conf` file contains the container registry settings used by the build system.

### Setup

1. Copy the example configuration:
   ```bash
   cp registry.conf.example registry.conf
   ```

2. Edit `registry.conf` with your registry details:
   ```bash
   # Example configurations:

   # For Docker Hub:
   REGISTRY_URL=docker.io
   REGISTRY_ORG=myusername

   # For Quay.io:
   REGISTRY_URL=quay.io
   REGISTRY_ORG=myorganization

   # For private registry:
   REGISTRY_URL=registry.example.com
   REGISTRY_ORG=myproject

   # For OpenShift internal registry:
   REGISTRY_URL=image-registry.openshift-image-registry.svc:5000
   REGISTRY_ORG=my-namespace
   ```

3. The Makefile will automatically use these settings when building images.

### Security

- The `registry.conf` file is ignored by git to prevent accidental commits
- Never commit credentials or sensitive information
- Use environment variables or secret management tools for production deployments

### Verifying Configuration

From the dashboard directory, run:
```bash
make registry-info
```

This will show your current registry configuration.
