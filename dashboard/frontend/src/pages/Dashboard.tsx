import React, { useEffect, useState, useCallback } from 'react';
import { Activity, FileText, Clock, AlertTriangle, TrendingUp } from 'lucide-react';
import MetricsCard from '../components/MetricsCard';
import WorkflowCard from '../components/WorkflowCard';
import SubmitWorkflowForm from '../components/SubmitWorkflowForm';
import { useWebSocket } from '../hooks/useWebSocket';
import { apiClient } from '../utils/api';
import { Workflow, SystemMetrics } from '../types/workflow';

const Dashboard: React.FC = () => {
  const [workflows, setWorkflows] = useState<Workflow[]>([]);
  const [metrics, setMetrics] = useState<SystemMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // WebSocket connection for real-time updates
  // Dynamically determine WebSocket URL based on current location
  const getWebSocketUrl = () => {
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = window.location.host;

    console.log('Window location:', {
      protocol: window.location.protocol,
      host: window.location.host,
      hostname: window.location.hostname,
      href: window.location.href
    });

    // Check for runtime config first
    const runtimeConfig = (window as any)._env_;

    // If we're on the dashboard route, use the public WebSocket URL
    if (host.includes('apps-crc.testing')) {
      if (runtimeConfig?.REACT_APP_PUBLIC_WS_URL) {
        const wsUrl = runtimeConfig.REACT_APP_PUBLIC_WS_URL + '/ws';
        console.log('Using runtime public WebSocket URL:', wsUrl);
        return wsUrl;
      }
      if (process.env.REACT_APP_PUBLIC_WS_URL) {
        const wsUrl = process.env.REACT_APP_PUBLIC_WS_URL + '/ws';
        console.log('Using build-time public WebSocket URL:', wsUrl);
        return wsUrl;
      }
    }

    // Fallback for local development or internal access
    const fallbackUrl = runtimeConfig?.REACT_APP_WS_URL || process.env.REACT_APP_WS_URL || 'ws://localhost:3001/ws';
    console.log('Using fallback WebSocket URL:', fallbackUrl);
    return fallbackUrl;
  };

  const wsUrl = getWebSocketUrl();
  console.log('WebSocket URL:', wsUrl);

  const handleWebSocketMessage = useCallback((data: any) => {
    console.log('[Dashboard] WebSocket message received in Dashboard:', data);
    if (data.type === 'workflow_update') {
      console.log('[Dashboard] Updating workflows and metrics');
      setWorkflows(data.data.workflows);
      setMetrics(data.data.metrics);
    } else if (data.type === 'subscribed') {
      console.log('[Dashboard] Successfully subscribed to updates');
    }
  }, []);

  const { isConnected } = useWebSocket(wsUrl, handleWebSocketMessage);

  // Initial data fetch
  useEffect(() => {
    const fetchData = async () => {
      try {
        const [workflowsData, metricsData] = await Promise.all([
          apiClient.getWorkflows(10, 0),
          apiClient.getMetrics()
        ]);
        setWorkflows(workflowsData);
        setMetrics(metricsData);
        setError(null);
      } catch (err) {
        console.error('Error fetching data:', err);
        setError('Failed to load dashboard data');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  const handleWorkflowSubmit = async () => {
    // Refresh workflows after submission
    try {
      const workflowsData = await apiClient.getWorkflows(10, 0);
      setWorkflows(workflowsData);
    } catch (err) {
      console.error('Error refreshing workflows:', err);
    }
  };

  const handleSync = async () => {
    try {
      await apiClient.syncWorkflows();
      // Data will be updated via WebSocket
    } catch (err) {
      console.error('Error syncing workflows:', err);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto"></div>
          <p className="mt-4 text-gray-600">Loading dashboard...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50">
      <div className="max-w-7xl mx-auto px-4 py-8">
        {/* Header */}
        <div className="mb-8">
          <h1 className="text-3xl font-bold text-gray-900 mb-2">AI Workflow Dashboard</h1>
          <div className="flex items-center justify-between">
            <p className="text-gray-600">Monitor and manage your document processing workflows</p>
            <div className="flex items-center space-x-4">
              <button
                onClick={handleSync}
                className="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
              >
                Sync Workflows
              </button>
              <div className="flex items-center space-x-2">
                <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-green-500' : 'bg-red-500'}`}></div>
                <span className="text-sm text-gray-600">
                  {isConnected ? 'Connected' : 'Disconnected'}
                </span>
              </div>
            </div>
          </div>
        </div>

        {error && (
          <div className="mb-6 bg-red-50 border border-red-200 rounded-lg p-4">
            <div className="flex items-center">
              <AlertTriangle className="h-5 w-5 text-red-600 mr-2" />
              <p className="text-red-800">{error}</p>
            </div>
          </div>
        )}

        {/* Metrics Grid */}
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
          <MetricsCard
            title="Total Workflows"
            value={metrics?.totalWorkflows || 0}
            icon={Activity}
            color="blue"
          />
          <MetricsCard
            title="Running"
            value={metrics?.activeWorkflows || 0}
            icon={TrendingUp}
            color="green"
          />
          <MetricsCard
            title="Documents Processed"
            value={metrics?.documentsProcessed || 0}
            icon={FileText}
            color="yellow"
          />
          <MetricsCard
            title="Avg Processing Time"
            value={`${metrics?.avgProcessingTime || 0}s`}
            icon={Clock}
            color="gray"
          />
        </div>

        {/* Submit Workflow Form */}
        <div className="mb-8">
          <SubmitWorkflowForm onSubmit={handleWorkflowSubmit} />
        </div>

        {/* Workflows List */}
        <div>
          <h2 className="text-xl font-semibold text-gray-900 mb-4">Recent Workflows</h2>
          {workflows.length === 0 ? (
            <div className="bg-white rounded-lg shadow p-8 text-center">
              <FileText className="h-12 w-12 text-gray-400 mx-auto mb-4" />
              <p className="text-gray-600">No workflows found</p>
              <p className="text-sm text-gray-500 mt-2">Submit a document to start processing</p>
            </div>
          ) : (
            <div className="space-y-4">
              {workflows.map((workflow) => (
                <WorkflowCard key={workflow.id} workflow={workflow} />
              ))}
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Dashboard;