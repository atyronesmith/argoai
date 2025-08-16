export interface Workflow {
  id: string;
  name: string;
  status: WorkflowStatus;
  docUrl: string;
  docType?: string;
  priority?: string;
  confidence?: number;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
  artifacts?: WorkflowArtifact[];
  steps?: WorkflowStep[];
}

export interface WorkflowStep {
  id: number;
  workflowId: string;
  stepName: string;
  status: StepStatus;
  startedAt?: string;
  completedAt?: string;
  logs?: string;
  error?: string;
}

export interface WorkflowArtifact {
  name: string;
  path: string;
  size?: number;
  contentType?: string;
}

export enum WorkflowStatus {
  PENDING = 'Pending',
  RUNNING = 'Running',
  SUCCEEDED = 'Succeeded',
  FAILED = 'Failed',
  ERROR = 'Error'
}

export enum StepStatus {
  PENDING = 'Pending',
  RUNNING = 'Running',
  SUCCEEDED = 'Succeeded',
  FAILED = 'Failed',
  SKIPPED = 'Skipped'
}

export interface SystemMetrics {
  totalWorkflows: number;
  activeWorkflows: number;
  completedWorkflows: number;
  failedWorkflows: number;
  avgProcessingTime: number;
  documentsProcessed: number;
}

export interface DocumentSummary {
  id: string;
  name: string;
  type: string;
  priority: string;
  confidence: number;
  status: string;
  processedAt: string;
  downloadUrl: string;
}