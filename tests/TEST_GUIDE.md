# AI Pipeline Testing Guide

## Overview

This test suite leverages Kubernetes-native testing capabilities:
- **Kubernetes Jobs** for quick smoke tests
- **Argo Workflows** for comprehensive integration tests
- **ConfigMaps** for test data management
- **Make** for test orchestration

## Architecture

```
┌─────────────────────────────────────────────────┐
│                 Test Suite                       │
├─────────────────────────────────────────────────┤
│  Quick Tests (K8s Job)    Full Tests (Argo)     │
│  - Connectivity           - All doc types       │
│  - Basic health          - All priorities      │
│  - Smoke tests           - Validation          │
└─────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────┐
│            AI Document Pipeline                  │
│  - Document classification                       │
│  - Priority detection                           │
│  - AI processing                                │
│  - Output generation                            │
└─────────────────────────────────────────────────┘
```

## Test Types

### 1. Quick Tests (Kubernetes Job)
Fast connectivity and health checks:
```bash
cd tests
make quick
```

### 2. Full Test Suite (Argo Workflow)
Comprehensive testing of all document types:
```bash
cd tests
make full
```

### 3. Individual Document Type Tests
Test specific document types:
```bash
make test-invoice
make test-contract
make test-techdoc
make test-correspondence
```

## Test Documents

Test documents are stored in a ConfigMap with realistic examples:

| Type | Normal Priority | Urgent Priority |
|------|----------------|-----------------|
| **Invoice** | Standard invoice with Net 30 terms | Past due invoice with legal warning |
| **Contract** | Standard service agreement | Expiring contract requiring immediate signature |
| **Technical Doc** | Regular technical specification | Critical security patch documentation |
| **Correspondence** | General business email | Urgent request with deadline |

## Running Tests

### Prerequisites

**IMPORTANT**: Before running any tests, you must set up your environment:

```bash
# From the project root directory:
source ./setup-env.sh

# Then navigate to tests:
cd tests
```

If you forget to do this, the Makefile will show you exactly what to do:
```bash
❌ ERROR: OpenShift CLI (oc) is not available!

Please run the following commands from the project root:

  cd ..
  source ./setup-env.sh
  cd tests

Then try running the tests again.
```

### Environment Verification
```bash
# Quick check (automatically run before each test)
make check-env

# Detailed environment check
make check-env-detailed

# Set up test resources
make setup
```

### Basic Test Flow
```bash
# 1. Validate environment
make validate

# 2. Run quick tests
make quick

# 3. Run full test suite
make full

# 4. Generate report
make report
```

### Continuous Testing
```bash
# Watch test progress
make watch

# Clean up after tests
make clean
```

## Test Validation

The test suite validates:

1. **Service Connectivity**
   - Ollama API responding
   - MinIO accessible
   - Argo Workflows running

2. **Document Classification**
   - Correct type detection
   - Accurate priority assessment

3. **Workflow Execution**
   - Successful completion
   - No errors in processing

4. **Output Quality**
   - Summary generated
   - Key information extracted
   - Routing recommendations

## CI/CD Integration

### GitLab CI Example
```yaml
test-pipeline:
  stage: test
  script:
    - oc login $OPENSHIFT_URL --token=$OPENSHIFT_TOKEN
    - cd tests
    - make validate
    - make quick
    - make report
  artifacts:
    paths:
      - tests/test-report.txt
```

### Jenkins Pipeline Example
```groovy
pipeline {
    agent any
    stages {
        stage('Test') {
            steps {
                sh 'cd tests && make quick'
            }
        }
        stage('Full Test') {
            when { branch 'main' }
            steps {
                sh 'cd tests && make full'
            }
        }
    }
}
```

### Tekton Pipeline Example
```yaml
apiVersion: tekton.dev/v1beta1
kind: Pipeline
metadata:
  name: ai-pipeline-tests
spec:
  tasks:
    - name: quick-test
      taskRef:
        name: run-quick-tests
    - name: full-test
      runAfter: [quick-test]
      taskRef:
        name: run-full-tests
```

## Extending Tests

### Adding New Test Documents
1. Edit `workflows/quick-test-job.yaml`
2. Add new document to ConfigMap
3. Update test logic

### Adding New Test Scenarios
1. Edit `workflows/test-suite-template.yaml`
2. Add new test case to DAG
3. Update validation logic

### Custom Test Workflows
Create new workflow templates:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: custom-test
spec:
  # Your custom test logic
```

## Troubleshooting

### Common Issues

1. **Tests failing to start**
   ```bash
   # Check service account permissions
   oc get rolebinding -n argo-ai-demo | grep argo
   ```

2. **Workflow timeouts**
   ```bash
   # Check Ollama is responding
   oc logs -l app.kubernetes.io/component=ollama -n argo-ai-demo
   ```

3. **ConfigMap not found**
   ```bash
   # Ensure test resources are deployed
   make setup
   ```

## Best Practices

1. **Run quick tests first** - Catch basic issues early
2. **Clean up after tests** - Use `make clean`
3. **Monitor resource usage** - Tests can consume resources
4. **Version test data** - Keep ConfigMaps in sync with pipeline changes
5. **Automate in CI/CD** - Run tests on every deployment
