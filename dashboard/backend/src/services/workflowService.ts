import { Database } from '../database/sqlite';
import { ArgoService } from './argoService';
import { Workflow, WorkflowStep, SystemMetrics } from '../types/workflow';

export class WorkflowService {
  private db: Database;
  private argoService: ArgoService;

  constructor() {
    this.db = new Database();
    this.argoService = new ArgoService();
    this.initializeDatabase();
  }

  private async initializeDatabase() {
    try {
      await this.db.initialize();
      console.log('Database initialized successfully');
    } catch (error) {
      console.error('Failed to initialize database:', error);
    }
  }

  async syncWorkflows(): Promise<void> {
    try {
      const argoWorkflows = await this.argoService.getWorkflows();

      for (const argoWorkflow of argoWorkflows) {
        const workflow = this.argoService.mapArgoWorkflowToInternal(argoWorkflow);
        const existing = await this.db.getWorkflow(workflow.id);

        if (existing) {
          // Update existing workflow
          await this.db.updateWorkflow(workflow.id, {
            status: workflow.status,
            doc_type: workflow.docType,
            priority: workflow.priority,
            confidence: workflow.confidence,
            completed_at: workflow.completedAt
          });
        } else {
          // Insert new workflow
          await this.db.insertWorkflow(workflow);
        }

        // Sync workflow steps
        const steps = this.argoService.extractWorkflowSteps(argoWorkflow);
        for (const step of steps) {
          const existingSteps = await this.db.getWorkflowSteps(workflow.id) as any[];
          const existingStep = existingSteps.find((s: any) => s.step_name === step.stepName);

          if (existingStep) {
            await this.db.updateStep(existingStep.id, {
              status: step.status,
              started_at: step.startedAt,
              completed_at: step.completedAt,
              error: step.error
            });
          } else {
            await this.db.insertStep({
              workflowId: workflow.id,
              ...step
            });
          }
        }
      }
    } catch (error) {
      console.error('Failed to sync workflows:', error);
    }
  }

  async getWorkflows(limit: number = 50, offset: number = 0): Promise<Workflow[]> {
    const workflows = await this.db.getWorkflows(limit, offset) as any[];
    return workflows.map(this.mapDbWorkflowToInternal);
  }

  async getWorkflow(id: string): Promise<Workflow | null> {
    const workflow = await this.db.getWorkflow(id);
    if (!workflow) return null;

    const steps = await this.db.getWorkflowSteps(id) as any[];
    const mapped = this.mapDbWorkflowToInternal(workflow);

    // Add steps information
    (mapped as any).steps = steps.map((step: any) => ({
      id: step.id,
      workflowId: step.workflow_id,
      stepName: step.step_name,
      status: step.status,
      startedAt: step.started_at,
      completedAt: step.completed_at,
      logs: step.logs,
      error: step.error
    }));

    return mapped;
  }

  async getWorkflowSteps(workflowId: string): Promise<WorkflowStep[]> {
    const steps = await this.db.getWorkflowSteps(workflowId) as any[];
    return steps.map((step: any) => ({
      id: step.id,
      workflowId: step.workflow_id,
      stepName: step.step_name,
      status: step.status,
      startedAt: step.started_at,
      completedAt: step.completed_at,
      logs: step.logs,
      error: step.error
    }));
  }

  async getWorkflowLogs(workflowId: string, stepName?: string): Promise<string> {
    return this.argoService.getWorkflowLogs(workflowId, stepName);
  }

  async submitWorkflow(docUrl: string, model: string = 'llama3.2:3b'): Promise<any> {
    const workflowTemplate = {
      apiVersion: 'argoproj.io/v1alpha1',
      kind: 'Workflow',
      metadata: {
        generateName: 'ai-doc-dash-',
        namespace: process.env.ARGO_NAMESPACE || 'argo-ai-demo'
      },
      spec: {
        workflowTemplateRef: {
          name: 'ai-document-processor-simple'
        },
        arguments: {
          parameters: [
            { name: 'doc-url', value: docUrl },
            { name: 'model', value: model }
          ]
        }
      }
    };

    return this.argoService.submitWorkflow(workflowTemplate);
  }

  async getMetrics(): Promise<SystemMetrics> {
    return this.db.getMetrics();
  }

  async getDocumentSummaries(): Promise<any[]> {
    const workflows = await this.db.getWorkflows(100, 0) as any[];
    return workflows
      .filter((w: any) => w.status === 'Succeeded' && w.doc_type)
      .map((w: any) => ({
        id: w.id,
        name: this.extractDocumentName(w.doc_url),
        type: w.doc_type || 'Unknown',
        priority: w.priority || 'Normal',
        confidence: w.confidence || 0,
        status: w.status,
        processedAt: w.completed_at || w.updated_at,
        downloadUrl: `/api/workflows/${w.id}/artifacts`
      }));
  }

  private mapDbWorkflowToInternal(dbWorkflow: any): Workflow {
    return {
      id: dbWorkflow.id,
      name: dbWorkflow.name,
      status: dbWorkflow.status,
      docUrl: dbWorkflow.doc_url,
      docType: dbWorkflow.doc_type,
      priority: dbWorkflow.priority,
      confidence: dbWorkflow.confidence,
      createdAt: dbWorkflow.created_at,
      updatedAt: dbWorkflow.updated_at,
      completedAt: dbWorkflow.completed_at
    };
  }

  private extractDocumentName(url: string): string {
    try {
      const urlObj = new URL(url);
      const pathname = urlObj.pathname;
      return pathname.split('/').pop() || 'Unknown Document';
    } catch {
      return 'Unknown Document';
    }
  }

  close() {
    this.db.close();
  }
}