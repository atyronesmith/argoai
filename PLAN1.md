I'll adapt the demo plan to use OpenShift Local (CRC) instead of k3d. This provides a more enterprise-ready environment that better represents production scenarios.

## Demo: AI-Enhanced Document Processing Pipeline on OpenShift

### Architecture Overview
```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Minio     │────▶│ Argo         │────▶│   Ollama    │
│  (Storage)  │     │ Workflows    │     │ (LLM Server)│
└─────────────┘     └──────────────┘     └─────────────┘
                           │
                    ┌──────▼──────┐
                    │   Qdrant    │
                    │(Vector DB)  │
                    └─────────────┘
```

### Quick Setup Plan (45-60 minutes)

#### Phase 1: OpenShift Local Setup (15 mins)

**Install and Start CRC:**
```bash
# Download CRC from https://console.redhat.com/openshift/create/local
# Setup CRC (requires 9GB RAM minimum, recommend 16GB)
crc setup

# Start CRC with increased resources
crc start --cpus 6 --memory 16384 --disk-size 60

# Get credentials and login
eval $(crc oc-env)
oc login -u developer -p developer https://api.crc.testing:6443

# Alternative: login as kubeadmin for admin tasks
oc login -u kubeadmin -p $(crc console --credentials | grep kubeadmin | awk '{print $NF}')
```

**Create Project for Argo Workflows:**
```bash
# Create a new project (OpenShift's namespace)
oc new-project argo-ai-demo
oc project argo-ai-demo

# Add necessary permissions
oc adm policy add-scc-to-user anyuid -z default -n argo-ai-demo
oc adm policy add-scc-to-user privileged -z default -n argo-ai-demo
```

#### Phase 2: Deploy Argo Workflows on OpenShift (10 mins)

**Install Argo Workflows with OpenShift-specific configurations:**
```bash
# Download and modify Argo installation for OpenShift
curl -sL https://github.com/argoproj/argo-workflows/releases/download/v3.5.0/install.yaml -o argo-install.yaml

# Apply with OpenShift-specific modifications
oc apply -n argo-ai-demo -f argo-install.yaml

# Create OpenShift Route for Argo Server UI
cat <<EOF | oc apply -f -
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: argo-server
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: argo-server
  port:
    targetPort: 2746
  tls:
    termination: edge
    insecureEdgeTerminationPolicy: Redirect
EOF

# Patch for easier access (dev only)
oc patch deployment argo-server -n argo-ai-demo \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args", "value": ["server", "--auth-mode=server", "--secure=false"]}]'

# Grant Argo SA proper permissions
oc create rolebinding default-admin --clusterrole=admin --serviceaccount=argo-ai-demo:default -n argo-ai-demo
oc create rolebinding argo-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo -n argo-ai-demo
oc create rolebinding argo-server-admin --clusterrole=admin --serviceaccount=argo-ai-demo:argo-server -n argo-ai-demo
```

**Deploy Ollama on OpenShift:**
```yaml
# ollama-openshift.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: argo-ai-demo
  labels:
    app: ollama
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      serviceAccountName: default
      containers:
      - name: ollama
        image: docker.io/ollama/ollama:latest
        ports:
        - containerPort: 11434
          protocol: TCP
        env:
        - name: OLLAMA_HOST
          value: "0.0.0.0"
        - name: OLLAMA_MODELS
          value: "/models"
        volumeMounts:
        - name: ollama-models
          mountPath: /models
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
          limits:
            memory: "8Gi"
            cpu: "4"
        securityContext:
          runAsNonRoot: false
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
      volumes:
      - name: ollama-models
        persistentVolumeClaim:
          claimName: ollama-models-pvc
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ollama-models-pvc
  namespace: argo-ai-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-service
  namespace: argo-ai-demo
spec:
  selector:
    app: ollama
  ports:
  - port: 11434
    targetPort: 11434
    protocol: TCP
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: ollama
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: ollama-service
  port:
    targetPort: 11434
  tls:
    termination: edge
EOF

# Apply the configuration
oc apply -f ollama-openshift.yaml
```

**Deploy MinIO using OpenShift Templates:**
```bash
# Deploy MinIO with OpenShift-specific configuration
cat <<EOF | oc apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: minio-pvc
  namespace: argo-ai-demo
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: apps.openshift.io/v1
kind: DeploymentConfig
metadata:
  name: minio
  namespace: argo-ai-demo
spec:
  replicas: 1
  selector:
    app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: quay.io/minio/minio:latest
        args:
        - server
        - /data
        - --console-address
        - ":9001"
        env:
        - name: MINIO_ROOT_USER
          value: <your-minio-user>
        - name: MINIO_ROOT_PASSWORD
          value: <your-minio-password>
        - name: MINIO_PROMETHEUS_AUTH_TYPE
          value: public
        ports:
        - containerPort: 9000
          name: api
        - containerPort: 9001
          name: console
        volumeMounts:
        - name: data
          mountPath: /data
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1"
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: minio-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: argo-ai-demo
spec:
  selector:
    app: minio
  ports:
  - name: api
    port: 9000
    targetPort: 9000
  - name: console
    port: 9001
    targetPort: 9001
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-console
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: minio
  port:
    targetPort: 9001
  tls:
    termination: edge
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: minio-api
  namespace: argo-ai-demo
spec:
  to:
    kind: Service
    name: minio
  port:
    targetPort: 9000
  tls:
    termination: edge
EOF
```

**Configure Argo to use MinIO:**
```bash
# Create artifact repository config
cat <<EOF | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: artifact-repositories
  namespace: argo-ai-demo
data:
  default-v1: |
    s3:
      bucket: argo-artifacts
      endpoint: minio.argo-ai-demo.svc.cluster.local:9000
      insecure: true
      accessKeySecret:
        name: minio-creds
        key: accesskey
      secretKeySecret:
        name: minio-creds
        key: secretkey
---
apiVersion: v1
kind: Secret
metadata:
  name: minio-creds
  namespace: argo-ai-demo
type: Opaque
stringData:
  accesskey: <base64-encoded-minio-user>
  secretkey: <base64-encoded-minio-password>
EOF

# Configure workflow controller to use MinIO
oc patch configmap workflow-controller-configmap -n argo-ai-demo \
  --patch '{"data":{"artifactRepository":"|  s3:\n    bucket: argo-artifacts\n    endpoint: minio.argo-ai-demo.svc.cluster.local:9000\n    insecure: true\n    accessKeySecret:\n      name: minio-creds\n      key: accesskey\n    secretKeySecret:\n      name: minio-creds\n      key: secretkey"}}'
```

#### Phase 3: Deploy Enhanced Workflow with OpenShift Features (15 mins)

**Create the AI Workflow with OpenShift-specific enhancements:**

```yaml
# ai-document-processor-openshift.yaml
apiVersion: argoproj.io/v1alpha1
kind: WorkflowTemplate
metadata:
  name: ai-document-processor
  namespace: argo-ai-demo
  labels:
    app: ai-workflow
    version: "1.0"
spec:
  serviceAccountName: argo
  entrypoint: process-documents

  # Volume claim templates for shared storage
  volumeClaimTemplates:
  - metadata:
      name: workdir
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi

  arguments:
    parameters:
    - name: doc-url
      value: "https://raw.githubusercontent.com/example/sample-doc.txt"
    - name: model
      value: "llama3.2:3b"

  templates:
  - name: process-documents
    dag:
      tasks:
      # Step 1: Initialize Ollama model
      - name: init-model
        template: init-ollama-model
        arguments:
          parameters:
          - name: model
            value: "{{workflow.parameters.model}}"

      # Step 2: Ingest document
      - name: ingest-document
        dependencies: [init-model]
        template: document-ingestion
        arguments:
          parameters:
          - name: doc-url
            value: "{{workflow.parameters.doc-url}}"

      # Step 3: AI Classification with OpenShift monitoring
      - name: classify-document
        dependencies: [ingest-document]
        template: llm-classify-monitored
        arguments:
          artifacts:
          - name: document
            from: "{{tasks.ingest-document.outputs.artifacts.document}}"
          parameters:
          - name: model
            value: "{{workflow.parameters.model}}"

      # Step 4: Extract information with caching
      - name: extract-info
        dependencies: [classify-document]
        template: llm-extract-cached
        arguments:
          artifacts:
          - name: document
            from: "{{tasks.ingest-document.outputs.artifacts.document}}"
          parameters:
          - name: doc-type
            value: "{{tasks.classify-document.outputs.parameters.classification}}"
          - name: model
            value: "{{workflow.parameters.model}}"

      # Step 5: Parallel processing based on classification
      - name: process-by-type
        dependencies: [extract-info]
        template: route-processor
        arguments:
          parameters:
          - name: doc-type
            value: "{{tasks.classify-document.outputs.parameters.classification}}"
          - name: priority
            value: "{{tasks.classify-document.outputs.parameters.priority}}"
          artifacts:
          - name: extracted-data
            from: "{{tasks.extract-info.outputs.artifacts.extracted}}"

      # Step 6: Generate final report
      - name: generate-report
        dependencies: [process-by-type]
        template: generate-final-report
        arguments:
          artifacts:
          - name: processed-data
            from: "{{tasks.process-by-type.outputs.artifacts.result}}"
          parameters:
          - name: model
            value: "{{workflow.parameters.model}}"

  # Initialize Ollama model
  - name: init-ollama-model
    inputs:
      parameters:
      - name: model
    container:
      image: registry.access.redhat.com/ubi8/ubi:latest
      command: [sh, -c]
      args:
      - |
        # Install curl
        dnf install -y curl

        # Check if model exists, if not pull it
        echo "Checking for model {{inputs.parameters.model}}..."

        # Wait for Ollama to be ready
        until curl -s http://ollama-service:11434/api/tags > /dev/null; do
          echo "Waiting for Ollama service..."
          sleep 5
        done

        # Pull the model if needed
        curl -X POST http://ollama-service:11434/api/pull \
          -d '{"name": "{{inputs.parameters.model}}"}' \
          -H "Content-Type: application/json"

        echo "Model {{inputs.parameters.model}} ready"

  # Document ingestion with OpenShift storage
  - name: document-ingestion
    inputs:
      parameters:
      - name: doc-url
    outputs:
      artifacts:
      - name: document
        path: /tmp/document.txt
        s3:
          bucket: argo-artifacts
          key: "{{workflow.name}}/document.txt"
    container:
      image: registry.access.redhat.com/ubi8/python-39:latest
      command: [python]
      args:
      - -c
      - |
        import urllib.request
        import os

        url = "{{inputs.parameters.doc-url}}"

        # Download document
        print(f"Downloading document from {url}")
        urllib.request.urlretrieve(url, '/tmp/document.txt')

        # Get file stats
        file_size = os.path.getsize('/tmp/document.txt')
        print(f"Document downloaded: {file_size} bytes")

        # Add OpenShift labels as metadata
        with open('/tmp/metadata.txt', 'w') as f:
            f.write(f"source: {url}\n")
            f.write(f"size: {file_size}\n")
            f.write(f"project: argo-ai-demo\n")

  # LLM Classification with monitoring
  - name: llm-classify-monitored
    inputs:
      artifacts:
      - name: document
        path: /tmp/document.txt
      parameters:
      - name: model
    outputs:
      parameters:
      - name: classification
        valueFrom:
          path: /tmp/classification.txt
      - name: priority
        valueFrom:
          path: /tmp/priority.txt
      artifacts:
      - name: metrics
        path: /tmp/metrics.json
    container:
      image: registry.access.redhat.com/ubi8/python-39:latest
      command: [python]
      args:
      - -c
      - |
        import json
        import urllib.request
        import time

        start_time = time.time()

        # Read document
        with open('/tmp/document.txt', 'r') as f:
            content = f.read()

        # Classification prompt
        prompt = """Classify this document into one of these categories:
        invoice, contract, report, correspondence, technical_doc, other.
        Also determine priority: urgent, normal, low.

        Document excerpt: """ + content[:1500] + """

        Respond ONLY with JSON:
        {"category": "...", "priority": "...", "confidence": 0.0-1.0}
        """

        # Call Ollama
        data = {
            "model": "{{inputs.parameters.model}}",
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.3,
                "top_p": 0.9
            }
        }

        req = urllib.request.Request(
            'http://ollama-service:11434/api/generate',
            data=json.dumps(data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )

        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                result = json.loads(response.read())
                response_text = result['response']

            # Parse response
            parsed = json.loads(response_text)
            category = parsed.get('category', 'other')
            priority = parsed.get('priority', 'normal')
            confidence = parsed.get('confidence', 0.5)
        except Exception as e:
            print(f"Error: {e}")
            category = 'other'
            priority = 'normal'
            confidence = 0.0

        # Calculate metrics
        elapsed_time = time.time() - start_time

        # Save outputs
        with open('/tmp/classification.txt', 'w') as f:
            f.write(category)
        with open('/tmp/priority.txt', 'w') as f:
            f.write(priority)

        # Save metrics for OpenShift monitoring
        metrics = {
            "classification_time": elapsed_time,
            "category": category,
            "priority": priority,
            "confidence": confidence,
            "model": "{{inputs.parameters.model}}",
            "timestamp": time.time()
        }

        with open('/tmp/metrics.json', 'w') as f:
            json.dump(metrics, f)

        print(f"Classification complete: {category} ({priority}) - Confidence: {confidence:.2f}")
        print(f"Processing time: {elapsed_time:.2f}s")

  # Cached extraction with OpenShift ConfigMap
  - name: llm-extract-cached
    inputs:
      artifacts:
      - name: document
        path: /tmp/document.txt
      parameters:
      - name: doc-type
      - name: model
    outputs:
      artifacts:
      - name: extracted
        path: /tmp/extracted.json
        s3:
          bucket: argo-artifacts
          key: "{{workflow.name}}/extracted-{{inputs.parameters.doc-type}}.json"
    container:
      image: registry.access.redhat.com/ubi8/python-39:latest
      command: [python]
      args:
      - -c
      - |
        import json
        import urllib.request
        import hashlib

        doc_type = "{{inputs.parameters.doc-type}}"

        with open('/tmp/document.txt', 'r') as f:
            content = f.read()

        # Create cache key
        cache_key = hashlib.md5(f"{doc_type}:{content[:500]}".encode()).hexdigest()

        # Define extraction templates
        extraction_templates = {
            "invoice": {
                "fields": ["vendor", "amount", "due_date", "invoice_number", "line_items"],
                "prompt": "Extract vendor name, total amount, due date, invoice number, and line items"
            },
            "contract": {
                "fields": ["parties", "term", "value", "obligations", "termination_clause"],
                "prompt": "Extract contracting parties, contract term, total value, key obligations, and termination terms"
            },
            "report": {
                "fields": ["executive_summary", "findings", "recommendations", "metrics"],
                "prompt": "Extract executive summary, key findings, recommendations, and performance metrics"
            },
            "technical_doc": {
                "fields": ["overview", "requirements", "architecture", "dependencies"],
                "prompt": "Extract technical overview, system requirements, architecture description, and dependencies"
            },
            "correspondence": {
                "fields": ["sender", "recipient", "subject", "action_items", "deadline"],
                "prompt": "Extract sender, recipient, main subject, action items, and any deadlines"
            },
            "other": {
                "fields": ["summary", "key_points", "entities", "dates"],
                "prompt": "Extract summary, key points, mentioned entities, and important dates"
            }
        }

        template = extraction_templates.get(doc_type, extraction_templates['other'])

        prompt = f"""Extract structured information from this {doc_type}.
        {template['prompt']}

        Document: {content[:2500]}

        Return ONLY valid JSON with these fields: {json.dumps(template['fields'])}
        """

        # Call Ollama for extraction
        data = {
            "model": "{{inputs.parameters.model}}",
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.2,
                "top_p": 0.95
            }
        }

        req = urllib.request.Request(
            'http://ollama-service:11434/api/generate',
            data=json.dumps(data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )

        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read())

        # Structure the output
        extraction = {
            "document_type": doc_type,
            "cache_key": cache_key,
            "extracted_data": result['response'],
            "model_used": "{{inputs.parameters.model}}",
            "extraction_template": template['fields']
        }

        with open('/tmp/extracted.json', 'w') as f:
            json.dump(extraction, f, indent=2)

        print(f"Extraction complete for {doc_type} document")
        print(f"Cache key: {cache_key}")

  # Route processor with OpenShift-native features
  - name: route-processor
    inputs:
      parameters:
      - name: doc-type
      - name: priority
      artifacts:
      - name: extracted-data
        path: /tmp/extracted.json
    outputs:
      artifacts:
      - name: result
        path: /tmp/result.json
    container:
      image: registry.access.redhat.com/ubi8/python-39:latest
      command: [python]
      args:
      - -c
      - |
        import json
        import time

        doc_type = "{{inputs.parameters.doc-type}}"
        priority = "{{inputs.parameters.priority}}"

        with open('/tmp/extracted.json', 'r') as f:
            data = json.load(f)

        # Process based on type and priority
        processing_rules = {
            "urgent": {
                "sla_hours": 4,
                "escalation": "immediate",
                "notifications": ["email", "slack", "sms"],
                "approval_required": True
            },
            "normal": {
                "sla_hours": 24,
                "escalation": "standard",
                "notifications": ["email"],
                "approval_required": False
            },
            "low": {
                "sla_hours": 72,
                "escalation": "none",
                "notifications": [],
                "approval_required": False
            }
        }

        rules = processing_rules.get(priority, processing_rules['normal'])

        # Simulate processing
        result = {
            "status": "processed",
            "document_type": doc_type,
            "priority": priority,
            "processing_rules": rules,
            "data": data,
            "processed_at": time.time(),
            "next_steps": [],
            "openshift_project": "argo-ai-demo"
        }

        # Add type-specific next steps
        if doc_type == "invoice" and priority == "urgent":
            result["next_steps"].append("Fast-track payment approval")
            result["next_steps"].append("Notify finance team")
        elif doc_type == "contract":
            result["next_steps"].append("Legal review required")
            result["next_steps"].append("Schedule stakeholder meeting")
        elif doc_type == "report":
            result["next_steps"].append("Distribute to leadership")
            result["next_steps"].append("Schedule review session")

        with open('/tmp/result.json', 'w') as f:
            json.dump(result, f, indent=2)

        print(f"Processed {doc_type} with {priority} priority")
        print(f"SLA: {rules['sla_hours']} hours")

  # Generate final report
  - name: generate-final-report
    inputs:
      artifacts:
      - name: processed-data
        path: /tmp/processed.json
      parameters:
      - name: model
    outputs:
      artifacts:
      - name: report
        path: /tmp/report.md
        s3:
          bucket: argo-artifacts
          key: "{{workflow.name}}/final-report.md"
    container:
      image: registry.access.redhat.com/ubi8/python-39:latest
      command: [python]
      args:
      - -c
      - |
        import json
        import urllib.request
        from datetime import datetime

        with open('/tmp/processed.json', 'r') as f:
            data = json.load(f)

        # Generate executive summary
        prompt = f"""Create a professional executive summary report based on this processed document data.

        Include:
        1. Document Overview
        2. Key Findings
        3. Priority Assessment
        4. Recommended Actions
        5. Timeline and Next Steps

        Data: {json.dumps(data, indent=2)[:3000]}

        Format as professional markdown with headers and bullet points.
        Make it concise but comprehensive.
        """

        api_data = {
            "model": "{{inputs.parameters.model}}",
            "prompt": prompt,
            "stream": False,
            "options": {
                "temperature": 0.4
            }
        }

        req = urllib.request.Request(
            'http://ollama-service:11434/api/generate',
            data=json.dumps(api_data).encode('utf-8'),
            headers={'Content-Type': 'application/json'}
        )

        with urllib.request.urlopen(req, timeout=60) as response:
            result = json.loads(response.read())

        # Create final report
        report = f"""# AI Document Processing Report

        **Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
        **Workflow**: {{workflow.name}}
        **OpenShift Project**: argo-ai-demo

        ---

        {result['response']}

        ---

        ## Processing Metadata

        - **Document Type**: {data.get('document_type', 'Unknown')}
        - **Priority Level**: {data.get('priority', 'Normal')}
        - **Processing Status**: {data.get('status', 'Complete')}
        - **Model Used**: {{inputs.parameters.model}}

        ## OpenShift Integration Notes

        This document was processed using the AI-enhanced workflow running on OpenShift Local (CRC).
        All artifacts are stored in MinIO and accessible via OpenShift Routes.
        """

        with open('/tmp/report.md', 'w') as f:
            f.write(report)

        print("Final report generated successfully")
```

#### Phase 4: Deploy and Test (10 mins)

**Apply the workflow template:**
```bash
oc apply -f ai-document-processor-openshift.yaml
```

**Create a test document:**
```bash
# Create a sample invoice document
cat <<EOF > /tmp/sample-invoice.txt
INVOICE #2024-1234
Date: January 15, 2024
Due Date: February 15, 2024

Bill To:
Acme Corporation
123 Business Street
San Francisco, CA 94105

From:
Tech Solutions Inc.
456 Innovation Drive
San Jose, CA 95110

Description                     Quantity    Rate      Amount
Cloud Infrastructure Setup           1      5000.00   5000.00
Monthly Hosting Services            3      1500.00   4500.00
Security Audit                      1      2500.00   2500.00
Technical Support                   10       150.00   1500.00

Subtotal: 13,500.00
Tax (8.5%): 1,147.50
TOTAL DUE: 14,647.50

Payment Terms: Net 30
Please remit payment to account ending in 4532
EOF

# Upload to a accessible location or use oc create configmap
oc create configmap sample-docs --from-file=/tmp/sample-invoice.txt -n argo-ai-demo
```

**Submit and monitor the workflow:**
```bash
# Submit workflow
argo submit -n argo-ai-demo --watch \
  --from workflowtemplate/ai-document-processor \
  -p doc-url="https://raw.githubusercontent.com/your-repo/sample-invoice.txt" \
  -p model="llama3.2:3b"

# Or use oc to submit
oc create -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Workflow
metadata:
  generateName: ai-doc-process-
  namespace: argo-ai-demo
spec:
  workflowTemplateRef:
    name: ai-document-processor
  arguments:
    parameters:
    - name: doc-url
      value: "https://raw.githubusercontent.com/your-repo/sample-invoice.txt"
    - name: model
      value: "llama3.2:3b"
EOF

# Watch the workflow
argo watch -n argo-ai-demo @latest

# Get workflow logs
argo logs -n argo-ai-demo @latest
```

**Access the UIs:**
```bash
# Get routes
oc get routes -n argo-ai-demo

# Access Argo UI
echo "Argo UI: https://$(oc get route argo-server -n argo-ai-demo -o jsonpath='{.spec.host}')"

# Access MinIO Console
echo "MinIO Console: https://$(oc get route minio-console -n argo-ai-demo -o jsonpath='{.spec.host}')"

# Access from browser (use configured MinIO credentials)
```

### Key OpenShift-Specific Advantages to Highlight

1. **Security Context Constraints (SCC)**: Proper security policies for containers
2. **Routes vs Ingress**: Native OpenShift routing for easy access
3. **DeploymentConfigs**: OpenShift-native deployment management
4. **ImageStreams**: Could be used for managing Ollama model versions
5. **BuildConfigs**: Could build custom container images with models
6. **Monitoring Integration**: OpenShift's built-in Prometheus/Grafana
7. **Operator Framework**: Could package this as an Operator

### Monitoring and Observability

```bash
# Add ServiceMonitor for Prometheus scraping
cat <<EOF | oc apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ai-workflow-metrics
  namespace: argo-ai-demo
spec:
  selector:
    matchLabels:
      app: ai-workflow
  endpoints:
  - port: metrics
    interval: 30s
EOF

# View metrics in OpenShift Console
echo "OpenShift Console: $(crc console --url)"
```

### Demo Scenarios

1. **Urgent Invoice Processing**: Show automatic escalation
2. **Contract Analysis**: Extract and highlight key terms
3. **Multi-document Batch**: Process multiple documents in parallel
4. **Model Comparison**: Run same document through different models

This OpenShift-based approach provides enterprise features like RBAC, built-in monitoring, and operator support while demonstrating the hybrid AI-orchestration pattern effectively.
