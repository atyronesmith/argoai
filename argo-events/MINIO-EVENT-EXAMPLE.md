# MinIO Bucket Event Example

## How File Drop Events Work

When a file is dropped into a MinIO bucket, it generates an S3-compatible event that looks like this:

```json
{
  "EventVersion": "1.0",
  "EventSource": "minio:s3",
  "EventTime": "2024-01-15T10:30:45Z",
  "EventName": "s3:ObjectCreated:Put",
  "notification": [
    {
      "s3": {
        "bucket": {
          "name": "documents",
          "arn": "arn:aws:s3:::documents"
        },
        "object": {
          "key": "invoices/2024/invoice-12345.pdf",
          "size": 245632,
          "eTag": "d41d8cd98f00b204e9800998ecf8427e",
          "contentType": "application/pdf"
        }
      },
      "eventTime": "2024-01-15T10:30:45Z",
      "eventName": "s3:ObjectCreated:Put",
      "userIdentity": {
        "principalId": "admin"
      }
    }
  ]
}
```

## Event Flow

1. **File Upload** → User uploads `invoice-12345.pdf` to MinIO bucket
2. **Event Generation** → MinIO generates an S3 event
3. **EventSource** → Argo Events EventSource receives the notification
4. **Event Bus** → Event is published to NATS event bus
5. **Sensor** → Sensor detects the event and evaluates conditions
6. **Trigger** → Workflow is created to process the document

## Practical Examples

### Example 1: Simple File Drop
```bash
# Upload a file to trigger processing
mc cp invoice.pdf myminio/documents/invoices/
```

This triggers:
- EventSource detects the upload
- Sensor creates a workflow
- Document is processed by AI

### Example 2: Batch Upload
```bash
# Upload multiple files
mc cp *.pdf myminio/documents/contracts/
```

Each file triggers a separate workflow instance.

### Example 3: Using curl
```bash
# Direct upload via MinIO API
curl -X PUT \
  http://minio.argo-ai-demo.svc.cluster.local:9000/documents/invoices/test.pdf \
  -H "Authorization: Bearer $TOKEN" \
  --data-binary @invoice.pdf
```

## Sensor Features

### 1. Path-Based Routing
```yaml
filter:
  prefix: "invoices/"      # Only files in invoices folder
  suffix: ".pdf"           # Only PDF files
```

### 2. Event Types
```yaml
events:
  - s3:ObjectCreated:Put   # Direct upload
  - s3:ObjectCreated:Post  # Form upload
  - s3:ObjectCreated:CompleteMultipartUpload  # Large files
```

### 3. Dynamic Workflow Parameters
```yaml
parameters:
  - src:
      dependencyName: minio-dep
      dataKey: notification.0.s3.object.key
    dest: spec.arguments.parameters.filename
```

## Integration with AI Pipeline

The sensor automatically:
1. Extracts file metadata from the event
2. Constructs the document URL
3. Passes document type hints based on folder
4. Triggers the AI processing workflow
5. Labels workflows for easy tracking

## Testing

```bash
# Create test bucket structure
mc mb myminio/documents
mc mb myminio/documents/invoices
mc mb myminio/documents/contracts
mc mb myminio/documents/technical
mc mb myminio/documents/correspondence

# Test invoice processing
echo "INVOICE TEST" > test-invoice.txt
mc cp test-invoice.txt myminio/documents/invoices/

# Watch for triggered workflows
oc get workflows -w -l source=minio-sensor
```
