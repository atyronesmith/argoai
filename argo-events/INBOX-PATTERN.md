# Smart Inbox Pattern for Document Processing

## Overview

Instead of requiring users to know which folder to use, they simply drop ALL documents into a single "inbox" folder. The AI automatically:
1. Classifies the document type
2. Determines priority
3. Moves it to the appropriate folder
4. Processes it accordingly

## Benefits

✅ **User-Friendly** - No need to know folder structure
✅ **Self-Organizing** - Documents automatically filed correctly
✅ **Audit Trail** - Track document movement and classification
✅ **Error Reduction** - No more misfiled documents
✅ **Scalable** - Handle thousands of documents automatically

## Folder Structure

```
documents/
├── inbox/                    # 📥 Users drop ALL files here
│   └── (empty after processing)
│
├── invoices/                 # 📄 Auto-organized by AI
│   ├── normal/
│   │   └── 20240115_143022_invoice-12345.pdf
│   └── urgent/
│       └── 20240115_143159_overdue-invoice.pdf
│
├── contracts/                # 📋 Auto-organized by AI
│   ├── normal/
│   │   └── 20240115_143512_service-agreement.pdf
│   └── urgent/
│       └── 20240115_143623_expiring-contract.pdf
│
├── technical/                # 📚 Auto-organized by AI
│   ├── normal/
│   │   └── 20240115_143745_api-docs.pdf
│   └── urgent/
│       └── 20240115_143856_security-patch.pdf
│
└── correspondence/           # 📧 Auto-organized by AI
    ├── normal/
    │   └── 20240115_144012_meeting-notes.pdf
    └── urgent/
        └── 20240115_144123_action-required.pdf
```

## Workflow Steps

### 1. User Drops File
```bash
# User simply uploads to inbox
mc cp important-document.pdf myminio/documents/inbox/
```

### 2. Event Triggers
```yaml
# Sensor watches only the inbox folder
filter:
  prefix: "inbox/"
```

### 3. AI Classification
```python
# Ollama analyzes the document
prompt = """
Analyze this document and determine:
1. Type: invoice, contract, techdoc, or correspondence
2. Priority: urgent or normal

Look for keywords like:
- Invoice: "invoice", "bill", "payment due"
- Contract: "agreement", "terms", "parties"
- Technical: "specification", "API", "documentation"
- Urgent: "overdue", "immediate", "deadline", "critical"
"""
```

### 4. Smart Move
```bash
# Document moved based on classification
inbox/scan-001.pdf → invoices/urgent/20240115_144523_scan-001.pdf
```

### 5. Process in Final Location
The document is now processed with the correct workflow based on its classification and location.

## Implementation Example

```yaml
# Simplified workflow
- name: process-inbox-file
  dag:
    tasks:
    - name: classify
      template: ai-classify
      arguments:
        parameters:
        - name: file
          value: "inbox/new-document.pdf"

    - name: move
      template: move-to-folder
      dependencies: [classify]
      arguments:
        parameters:
        - name: type
          value: "{{tasks.classify.outputs.parameters.type}}"
        - name: priority
          value: "{{tasks.classify.outputs.parameters.priority}}"

    - name: process
      template: process-document
      dependencies: [move]
      arguments:
        parameters:
        - name: final_path
          value: "{{tasks.move.outputs.parameters.new_path}}"
```

## User Experience

### Before (Manual Organization)
1. User must know document type
2. User must choose correct folder
3. User might misfile documents
4. No priority detection

### After (AI Inbox)
1. User drops file in inbox - done!
2. AI classifies automatically
3. AI detects priority
4. Document filed correctly
5. Appropriate workflow triggered

## Testing the Pattern

```bash
# 1. Create inbox folder
mc mb myminio/documents/inbox

# 2. Upload test documents
mc cp invoice.pdf myminio/documents/inbox/
mc cp contract.pdf myminio/documents/inbox/
mc cp urgent-memo.pdf myminio/documents/inbox/

# 3. Watch them get organized
mc ls myminio/documents/invoices/
mc ls myminio/documents/contracts/
mc ls myminio/documents/correspondence/urgent/

# 4. Verify inbox is empty
mc ls myminio/documents/inbox/
```

## Advanced Features

### Confidence Threshold
```yaml
# Only auto-file if confidence > 80%
- name: check-confidence
  when: "{{tasks.classify.outputs.parameters.confidence}} > 0.8"
```

### Manual Review Queue
```yaml
# Low confidence → manual review
- name: needs-review
  when: "{{tasks.classify.outputs.parameters.confidence}} <= 0.8"
  template: move-to-review
```

### Processing Status
```yaml
# Add metadata about processing
- name: add-metadata
  template: tag-document
  arguments:
    parameters:
    - name: tags
      value: "classified:{{date}},confidence:{{confidence}},ai-model:llama3.2"
```

## Benefits for MCP Integration

This pattern is perfect for future MCP server integration:
- **Standardized Input** - All documents enter through inbox
- **Metadata Rich** - Classification data available for routing
- **Event Driven** - Each move can trigger additional events
- **Audit Ready** - Complete trail of document journey

The inbox pattern transforms document management from a manual filing task to an intelligent, automated system!
