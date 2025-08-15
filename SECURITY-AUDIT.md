# 🔐 Security Audit - AI-Enhanced Document Processing Pipeline

## ⚠️ IMPORTANT: Items to Remove/Change Before Public Repository

### 1. **Hardcoded Credentials** 🚨

The following credentials are hardcoded and MUST be changed before making the repository public:

| Service | Current Credentials | Files Containing Them | Action Required |
|---------|-------------------|---------------------|-----------------|
| MinIO | `admin` / `password123` | Multiple files (see below) | Use environment variables or secrets |
| OpenShift | References to `kubeadmin` | Scripts and docs | Document as placeholder |

**Files with hardcoded MinIO credentials:**
- `setup-crc-openshift.sh` (lines 434-436, 539-540, 722, 758)
- `IMPLEMENTATION_PLAN.md` (lines 260-262, 363-364)
- `PLAN1.md` (lines 226-228, 326-327)
- `README.md` (line 168)
- `setup-env.sh` (line 101)
- `fix-common-issues.sh` (line 144)
- `CLAUDE.md` (line 63)

### 2. **Pull Secret References** 🔑

The scripts reference Red Hat pull secrets which are personal/account-specific:

- `setup-crc-openshift.sh` - Prompts for pull secret (lines 130-149)
- Documentation mentions pull secret requirements

**Action**: Keep the prompt mechanism but add warnings about not committing pull secrets.

### 3. **Local Development URLs** 🌐

All URLs reference `.apps-crc.testing` which is specific to local CRC installations:

- `https://argo-server-argo-ai-demo.apps-crc.testing`
- `https://minio-console-argo-ai-demo.apps-crc.testing`
- `https://ollama-argo-ai-demo.apps-crc.testing`
- `https://api.crc.testing:6443`

**Action**: Document these as examples and use environment variables.

### 4. **Kubeadmin Password Extraction** 🔓

Scripts extract the `kubeadmin` password dynamically:

- `setup-crc-openshift.sh` (lines 160, 175, 180, 194)
- `submit-test-workflow.sh` (line 95)
- `setup-env.sh` (line 31)
- `fix-common-issues.sh` (line 44)
- `deploy-full-workflow.sh` (line 44)

**Action**: This is acceptable as it's extracted at runtime, not stored.

## ✅ Security Best Practices to Implement

### 1. **Environment Variables**

Replace hardcoded values with environment variables:

```bash
# .env.example (to be committed)
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=changeme
MINIO_ENDPOINT=minio.argo-ai-demo.svc.cluster.local:9000

# .env (to be git-ignored)
MINIO_ACCESS_KEY=your-actual-key
MINIO_SECRET_KEY=your-actual-secret
```

### 2. **Kubernetes Secrets**

Update scripts to create secrets properly:

```bash
# Instead of hardcoding in YAML
kubectl create secret generic minio-creds \
  --from-literal=accesskey="${MINIO_ACCESS_KEY}" \
  --from-literal=secretkey="${MINIO_SECRET_KEY}" \
  -n argo-ai-demo
```

### 3. **Git Ignore File**

Create `.gitignore`:

```
# Secrets and credentials
.env
*.pem
*.key
pull-secret.txt
pull-secret.json
*-credentials.txt

# Temporary files
*.tmp
*.log
*.swp
.DS_Store

# CRC specific
.crc/
```

### 4. **Documentation Updates**

Update all documentation to:
- Use placeholder values like `<your-minio-password>`
- Add security warnings about not committing secrets
- Provide examples of secure secret management

### 5. **Script Modifications**

#### setup-crc-openshift.sh

```bash
# Add at the beginning
if [ -f .env ]; then
    source .env
fi

# Use environment variables with defaults
MINIO_ACCESS_KEY="${MINIO_ACCESS_KEY:-admin}"
MINIO_SECRET_KEY="${MINIO_SECRET_KEY:-password123}"

# Add warning
echo "WARNING: Using default credentials. For production, set MINIO_ACCESS_KEY and MINIO_SECRET_KEY"
```

## 📋 Files to Update Before Public Release

1. **High Priority** (contains credentials):
   - [ ] `setup-crc-openshift.sh`
   - [ ] `IMPLEMENTATION_PLAN.md`
   - [ ] `PLAN1.md`
   - [ ] `fix-common-issues.sh`
   - [ ] All YAML files with MinIO credentials

2. **Medium Priority** (references credentials):
   - [ ] `README.md`
   - [ ] `setup-env.sh`
   - [ ] `CLAUDE.md`
   - [ ] `DEMO.md`

3. **Low Priority** (documentation):
   - [ ] Add security section to README
   - [ ] Create CONTRIBUTING.md with security guidelines
   - [ ] Add `.env.example` file

## 🛡️ Recommended Security Enhancements

1. **Secret Management Options**:
   - OpenShift Secrets with RBAC
   - Sealed Secrets for GitOps
   - External Secrets Operator
   - HashiCorp Vault integration

2. **Network Security**:
   - Use TLS for all services
   - Implement network policies
   - Restrict service exposure

3. **Access Control**:
   - Implement proper RBAC
   - Use service accounts with minimal permissions
   - Audit trail for all operations

4. **Data Protection**:
   - Encrypt data at rest in MinIO
   - Use secure transport (HTTPS/TLS)
   - Implement data retention policies

## 🚀 Quick Security Fixes Script

Create `prepare-for-public.sh`:

```bash
#!/bin/bash

echo "Preparing repository for public release..."

# Create .gitignore if it doesn't exist
if [ ! -f .gitignore ]; then
    cat > .gitignore << 'EOF'
# Secrets and credentials
.env
*.pem
*.key
pull-secret.txt
pull-secret.json
*-credentials.txt

# Temporary files
*.tmp
*.log
*.swp
.DS_Store

# CRC specific
.crc/
EOF
fi

# Create .env.example
cat > .env.example << 'EOF'
# MinIO Configuration
MINIO_ACCESS_KEY=admin
MINIO_SECRET_KEY=changeme

# OpenShift Configuration
OPENSHIFT_PROJECT=argo-ai-demo
EOF

# Check for hardcoded passwords
echo "Checking for hardcoded credentials..."
grep -r "password123" --include="*.sh" --include="*.yaml" --include="*.yml" . | grep -v ".git"

echo "Please manually update the files listed above to use environment variables"
echo "Don't forget to update documentation files as well!"
```

## 📝 Summary

**Critical Issues**:
1. Hardcoded MinIO credentials (`admin`/`password123`)
2. No `.gitignore` file to prevent accidental secret commits

**Moderate Issues**:
1. Local development URLs hardcoded
2. No environment variable usage

**Low Risk**:
1. Kubeadmin password extraction (acceptable as it's runtime only)
2. Documentation contains example credentials

**Next Steps**:
1. Run the security fixes script
2. Update all files to use environment variables
3. Add proper `.gitignore`
4. Update documentation with security best practices
5. Test everything still works with the changes
