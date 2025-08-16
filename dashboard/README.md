# AI Workflow Dashboard

A comprehensive web dashboard for monitoring and managing AI document processing workflows in OpenShift using Argo Workflows.

## Features

- **Real-time Workflow Monitoring**: Live updates on workflow status and progress
- **Document Processing Pipeline**: Complete view of AI classification, extraction, and routing
- **Interactive UI**: Submit new workflows, view detailed logs, and download artifacts
- **OpenShift Native**: Designed for OpenShift deployment with proper RBAC and Routes
- **SQLite Database**: Lightweight persistence for demo environments
- **WebSocket Integration**: Real-time updates without page refresh

## Architecture

### Backend (Node.js/TypeScript)
- Express API server with SQLite database
- Argo Workflows API integration
- WebSocket server for real-time updates
- MinIO artifact management

### Frontend (React/TypeScript)
- Modern React dashboard with Tailwind CSS
- Real-time workflow status cards
- Step-by-step progress visualization
- Document library and metrics

## Registry Configuration

The dashboard uses a configurable container registry for building and pushing images.

### Setup Registry Configuration

1. **Copy the example configuration:**
   ```bash
   cp ../secrets/registry.conf.example ../secrets/registry.conf
   ```

2. **Edit the configuration with your registry details:**
   ```bash
   vi ../secrets/registry.conf
   ```

   Example configurations:
   ```bash
   # For Quay.io
   REGISTRY_URL=quay.io
   REGISTRY_ORG=myorganization

   # For Docker Hub
   REGISTRY_URL=docker.io
   REGISTRY_ORG=myusername

   # For OpenShift Internal Registry
   REGISTRY_URL=image-registry.openshift-image-registry.svc:5000
   REGISTRY_ORG=my-namespace
   ```

3. **Verify your configuration:**
   ```bash
   make registry-info
   ```

The Makefile will automatically use these settings when building and pushing images.

## Quick Start

### Local Development

1. **Install dependencies:**
   ```bash
   cd dashboard
   npm run install:all
   ```

2. **Start development servers:**
   ```bash
   npm run dev
   ```

3. **Access the application:**
   - Frontend: http://localhost:3000
   - Backend API: http://localhost:3001

### Podman Compose

```bash
cd dashboard
make up
```

Or manually:
```bash
podman-compose -f podman-compose.yml up --build
```

### OpenShift Deployment

**Using Makefile (Recommended):**
```bash
cd dashboard
make deploy
```

**Manual deployment:**
```bash
# Or use the deployment script
./deploy.sh

# Or manually step by step
oc apply -f k8s/namespace.yaml
oc apply -f k8s/rbac.yaml
oc apply -f k8s/backend-deployment.yaml
oc apply -f k8s/frontend-deployment.yaml
oc apply -f k8s/route.yaml
```

**Get dashboard URL:**
```bash
make urls
```

## Usage

### Dashboard Overview
- View active and recent workflows
- Monitor system metrics and performance
- Submit new document processing workflows

### Workflow Details
- Real-time step progress tracking
- View logs for each workflow step
- Download generated artifacts and reports

### Document Management
- Browse processed documents by type
- View classification confidence scores
- Access generated reports and extracts

## Configuration

### Environment Variables

**Backend:**
- `DATABASE_PATH`: SQLite database file location
- `ARGO_SERVER`: Argo server endpoint
- `ARGO_NAMESPACE`: Kubernetes namespace
- `MINIO_ENDPOINT`: MinIO server for artifacts

**Frontend:**
- `REACT_APP_API_URL`: Backend API endpoint
- `REACT_APP_WS_URL`: WebSocket endpoint

### OpenShift Integration

The dashboard integrates with existing OpenShift AI workflow infrastructure:

- **Argo Workflows**: Monitors workflow execution and status
- **Ollama**: AI model serving for document classification
- **MinIO**: Artifact storage and retrieval
- **OpenShift Routes**: External access with TLS termination

## API Endpoints

### Workflows
- `GET /api/workflows` - List workflows with pagination
- `GET /api/workflows/:id` - Get workflow details
- `POST /api/workflows` - Submit new workflow
- `GET /api/workflows/:id/logs` - Get workflow logs

### Metrics
- `GET /api/metrics` - System performance metrics
- `GET /api/metrics/documents` - Document summaries

### WebSocket
- `WS /` - Real-time workflow updates

## Development

### Project Structure
```
dashboard/
├── backend/          # Node.js API server
│   ├── src/
│   │   ├── database/ # SQLite database layer
│   │   ├── routes/   # API route handlers
│   │   ├── services/ # Business logic
│   │   └── types/    # TypeScript definitions
│   └── Dockerfile
├── frontend/         # React application
│   ├── src/
│   │   ├── components/ # UI components
│   │   ├── pages/      # Page components
│   │   ├── hooks/      # Custom React hooks
│   │   └── utils/      # Utilities and API client
│   └── Dockerfile
└── k8s/             # OpenShift manifests
```

## Makefile Commands

The dashboard includes a comprehensive Makefile for all operations:

```bash
# Development
make install          # Install all dependencies
make dev             # Start development servers
make test            # Run all tests

# Container Images
make build-images    # Build both backend and frontend images
make push-images     # Push images to registry

# Registry Configuration
make registry-info   # Show current registry configuration

# Local Deployment
make up              # Start with podman-compose
make down            # Stop services
make logs            # View logs

# OpenShift Deployment
make deploy          # Full deployment to OpenShift
make remove          # Remove deployment
make status          # Show deployment status

# Monitoring
make logs-backend    # View backend logs
make port-forward    # Port forward services
make urls            # Show access URLs

# Utilities
make clean           # Clean up artifacts
make help            # Show all commands
```

### Building Images

**Using Makefile:**
```bash
make build-images
```

**Manual build:**
```bash
cd backend && podman build -t ai-dashboard-backend .
cd frontend && podman build -t ai-dashboard-frontend .
```

## Security

- OpenShift Security Context Constraints (SCC) compliance
- Non-root container execution
- RBAC permissions for Argo Workflows access
- TLS termination at OpenShift Routes
- Security headers in nginx configuration

## Monitoring

The dashboard includes built-in health checks and monitoring:

- Kubernetes liveness and readiness probes
- Application health endpoint (`/api/health`)
- WebSocket connection status indicators
- Real-time metrics and alerts

## License

MIT License - see LICENSE file for details.