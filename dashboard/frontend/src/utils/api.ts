import { Workflow, SystemMetrics, WorkflowStep, DocumentSummary } from '../types/workflow';

// Dynamically determine API URL based on current location
const getApiBaseUrl = () => {
  // Check for runtime config first
  const runtimeConfig = (window as any)._env_;

  // For OpenShift deployment, use the public API URL if available
  if (window.location.hostname.includes('apps-crc.testing')) {
    if (runtimeConfig?.REACT_APP_PUBLIC_API_URL) {
      return runtimeConfig.REACT_APP_PUBLIC_API_URL;
    }
    if (process.env.REACT_APP_PUBLIC_API_URL) {
      return process.env.REACT_APP_PUBLIC_API_URL;
    }
  }

  // Fallback for local development or internal access
  return runtimeConfig?.REACT_APP_API_URL || process.env.REACT_APP_API_URL || 'http://localhost:3001';
};

const API_BASE_URL = getApiBaseUrl();

class ApiClient {
  private baseUrl: string;

  constructor(baseUrl: string = API_BASE_URL) {
    this.baseUrl = baseUrl;
  }

  private async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const url = `${this.baseUrl}${endpoint}`;

    const config: RequestInit = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      return await response.json();
    } catch (error) {
      console.error(`API request failed: ${endpoint}`, error);
      throw error;
    }
  }

  // Workflow endpoints
  async getWorkflows(limit = 50, offset = 0): Promise<Workflow[]> {
    return this.request<Workflow[]>(`/api/workflows?limit=${limit}&offset=${offset}`);
  }

  async getWorkflow(id: string): Promise<Workflow> {
    return this.request<Workflow>(`/api/workflows/${id}`);
  }

  async getWorkflowSteps(id: string): Promise<WorkflowStep[]> {
    return this.request<WorkflowStep[]>(`/api/workflows/${id}/steps`);
  }

  async getWorkflowLogs(id: string, step?: string): Promise<{ logs: string }> {
    const query = step ? `?step=${step}` : '';
    return this.request<{ logs: string }>(`/api/workflows/${id}/logs${query}`);
  }

  async submitWorkflow(docUrl: string, model = 'llama3.2:3b'): Promise<{ id: string }> {
    return this.request<{ id: string }>('/api/workflows', {
      method: 'POST',
      body: JSON.stringify({ docUrl, model }),
    });
  }

  async syncWorkflows(): Promise<{ message: string }> {
    return this.request<{ message: string }>('/api/workflows/sync', {
      method: 'POST',
    });
  }

  // Metrics endpoints
  async getMetrics(): Promise<SystemMetrics> {
    return this.request<SystemMetrics>('/api/metrics');
  }

  async getDocuments(): Promise<DocumentSummary[]> {
    return this.request<DocumentSummary[]>('/api/metrics/documents');
  }

  // Health check
  async getHealth() {
    return this.request('/api/health');
  }
}

export const apiClient = new ApiClient();
export default apiClient;