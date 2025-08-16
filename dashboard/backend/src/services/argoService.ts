import axios from 'axios';
import { Workflow, WorkflowStatus, StepStatus } from '../types/workflow';

export class ArgoService {
  private baseUrl: string;
  private namespace: string;

  constructor() {
    this.baseUrl = process.env.ARGO_SERVER || 'http://argo-server.argo-ai-dev.svc.cluster.local:2746';
    this.namespace = process.env.ARGO_NAMESPACE || 'argo-ai-dev';
  }

  async getWorkflows(): Promise<any[]> {
    try {
      const response = await axios.get(`${this.baseUrl}/api/v1/workflows/${this.namespace}`, {
        headers: {
          'Authorization': `Bearer ${process.env.ARGO_TOKEN || ''}`,
          'Content-Type': 'application/json'
        },
        timeout: 5000
      });

      return response.data.items || [];
    } catch (error) {
      console.error('Failed to fetch workflows from Argo:', error);
      return [];
    }
  }

  async getWorkflow(workflowId: string): Promise<any | null> {
    try {
      const response = await axios.get(`${this.baseUrl}/api/v1/workflows/${this.namespace}/${workflowId}`, {
        headers: {
          'Authorization': `Bearer ${process.env.ARGO_TOKEN || ''}`,
          'Content-Type': 'application/json'
        },
        timeout: 5000
      });

      return response.data;
    } catch (error) {
      console.error(`Failed to fetch workflow ${workflowId} from Argo:`, error);
      return null;
    }
  }

  async getWorkflowLogs(workflowId: string, stepName?: string): Promise<string> {
    try {
      let url = `${this.baseUrl}/api/v1/workflows/${this.namespace}/${workflowId}/log`;
      if (stepName) {
        url += `?podName=${stepName}`;
      }

      const response = await axios.get(url, {
        headers: {
          'Authorization': `Bearer ${process.env.ARGO_TOKEN || ''}`,
          'Content-Type': 'application/json'
        },
        timeout: 10000
      });

      return response.data || '';
    } catch (error) {
      console.error(`Failed to fetch logs for workflow ${workflowId}:`, error);
      return '';
    }
  }

    async submitWorkflow(workflowData: any): Promise<any | null> {
    try {
      // Argo API expects the workflow to be wrapped in a 'workflow' property
      const response = await axios.post(`${this.baseUrl}/api/v1/workflows/${this.namespace}`,
        { workflow: workflowData },
        {
          headers: {
            'Authorization': `Bearer ${process.env.ARGO_TOKEN || ''}`,
            'Content-Type': 'application/json'
          },
          timeout: 10000
        }
      );

      return response.data;
    } catch (error) {
      console.error('Failed to submit workflow to Argo:', error);
      throw error;
    }
  }

  mapArgoWorkflowToInternal(argoWorkflow: any): Workflow {
    const status = this.mapArgoStatus(argoWorkflow.status?.phase);
    const docUrl = argoWorkflow.spec?.arguments?.parameters?.find((p: any) => p.name === 'doc-url')?.value || '';

    return {
      id: argoWorkflow.metadata.name,
      name: argoWorkflow.metadata.generateName || argoWorkflow.metadata.name,
      status,
      docUrl,
      docType: this.extractDocType(argoWorkflow),
      priority: this.extractPriority(argoWorkflow),
      confidence: this.extractConfidence(argoWorkflow),
      createdAt: argoWorkflow.metadata.creationTimestamp,
      updatedAt: argoWorkflow.status?.finishedAt || argoWorkflow.status?.startedAt || argoWorkflow.metadata.creationTimestamp,
      completedAt: argoWorkflow.status?.finishedAt,
      artifacts: this.extractArtifacts(argoWorkflow)
    };
  }

  private mapArgoStatus(phase: string): WorkflowStatus {
    switch (phase) {
      case 'Pending':
        return WorkflowStatus.PENDING;
      case 'Running':
        return WorkflowStatus.RUNNING;
      case 'Succeeded':
        return WorkflowStatus.SUCCEEDED;
      case 'Failed':
      case 'Error':
        return WorkflowStatus.FAILED;
      default:
        return WorkflowStatus.PENDING;
    }
  }

  private extractDocType(workflow: any): string | undefined {
    // Look for classification output in workflow status
    const nodes = workflow.status?.nodes || {};
    for (const node of Object.values(nodes) as any[]) {
      if (node.templateName === 'llm-classify-monitored' && node.outputs?.parameters) {
        const classParam = node.outputs.parameters.find((p: any) => p.name === 'classification');
        return classParam?.value;
      }
    }
    return undefined;
  }

  private extractPriority(workflow: any): string | undefined {
    const nodes = workflow.status?.nodes || {};
    for (const node of Object.values(nodes) as any[]) {
      if (node.templateName === 'llm-classify-monitored' && node.outputs?.parameters) {
        const priorityParam = node.outputs.parameters.find((p: any) => p.name === 'priority');
        return priorityParam?.value;
      }
    }
    return undefined;
  }

  private extractConfidence(workflow: any): number | undefined {
    const nodes = workflow.status?.nodes || {};
    for (const node of Object.values(nodes) as any[]) {
      if (node.templateName === 'llm-classify-monitored' && node.outputs?.parameters) {
        const confParam = node.outputs.parameters.find((p: any) => p.name === 'confidence');
        return confParam?.value ? parseFloat(confParam.value) : undefined;
      }
    }
    return undefined;
  }

  private extractArtifacts(workflow: any): any[] {
    const artifacts: any[] = [];
    const nodes = workflow.status?.nodes || {};

    for (const node of Object.values(nodes) as any[]) {
      if (node.outputs?.artifacts) {
        for (const artifact of node.outputs.artifacts) {
          artifacts.push({
            name: artifact.name,
            path: artifact.s3?.key || artifact.path,
            size: artifact.s3?.size,
            contentType: artifact.s3?.contentType
          });
        }
      }
    }

    return artifacts;
  }

  extractWorkflowSteps(argoWorkflow: any): any[] {
    const steps: any[] = [];
    const nodes = argoWorkflow.status?.nodes || {};

    // Define the expected step order
    const stepOrder = [
      'init-model',
      'ingest-document',
      'classify-document',
      'extract-info',
      'process-by-type',
      'generate-report'
    ];

    for (const stepName of stepOrder) {
      const node = Object.values(nodes).find((n: any) => n.displayName === stepName || n.templateName === stepName) as any;

      if (node) {
        steps.push({
          workflowId: argoWorkflow.metadata.name,
          stepName,
          status: this.mapNodeStatus(node.phase),
          startedAt: node.startedAt,
          completedAt: node.finishedAt,
          logs: '', // Will be fetched separately
          error: node.message
        });
      } else {
        // Add pending step if not found
        steps.push({
          workflowId: argoWorkflow.metadata.name,
          stepName,
          status: StepStatus.PENDING,
          startedAt: null,
          completedAt: null,
          logs: '',
          error: null
        });
      }
    }

    return steps;
  }

  private mapNodeStatus(phase: string): StepStatus {
    switch (phase) {
      case 'Pending':
        return StepStatus.PENDING;
      case 'Running':
        return StepStatus.RUNNING;
      case 'Succeeded':
        return StepStatus.SUCCEEDED;
      case 'Failed':
      case 'Error':
        return StepStatus.FAILED;
      case 'Skipped':
        return StepStatus.SKIPPED;
      default:
        return StepStatus.PENDING;
    }
  }
}