import React, { useEffect, useState } from 'react';
import { useParams, Link } from 'react-router-dom';
import { ArrowLeft, ExternalLink, Download, FileText, Code } from 'lucide-react';
import WorkflowSteps from '../components/WorkflowSteps';
import { apiClient } from '../utils/api';
import { Workflow } from '../types/workflow';
import { formatDate, formatDuration, getStatusColor, getPriorityColor, formatConfidence } from '../utils/formatters';

const WorkflowDetail: React.FC = () => {
  const { id } = useParams<{ id: string }>();
  const [workflow, setWorkflow] = useState<Workflow | null>(null);
  const [logs, setLogs] = useState<{ [stepName: string]: string }>({});
  const [selectedStep, setSelectedStep] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const fetchWorkflow = async () => {
      if (!id) return;

      try {
        setLoading(true);
        const workflowData = await apiClient.getWorkflow(id);
        setWorkflow(workflowData);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'Failed to fetch workflow');
      } finally {
        setLoading(false);
      }
    };

    fetchWorkflow();
  }, [id]);

  const fetchLogs = async (stepName: string) => {
    if (!id || logs[stepName]) return;

    try {
      const response = await apiClient.getWorkflowLogs(id, stepName);
      setLogs(prev => ({ ...prev, [stepName]: response.logs || 'No logs available' }));
    } catch (err) {
      setLogs(prev => ({ ...prev, [stepName]: 'Failed to fetch logs' }));
    }
  };

  const handleStepClick = (stepName: string) => {
    setSelectedStep(stepName);
    fetchLogs(stepName);
  };

  const getDocumentName = (url: string) => {
    try {
      const urlObj = new URL(url);
      return urlObj.pathname.split('/').pop() || 'Unknown Document';
    } catch {
      return 'Unknown Document';
    }
  };

  if (loading) {
    return (
      <div className="flex items-center justify-center h-64">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-primary-600"></div>
      </div>
    );
  }

  if (error || !workflow) {
    return (
      <div className="space-y-4">
        <Link to="/workflows" className="inline-flex items-center text-primary-600 hover:text-primary-700">
          <ArrowLeft className="h-4 w-4 mr-2" />
          Back to Workflows
        </Link>
        <div className="bg-red-50 border border-red-200 rounded-md p-4">
          <p className="text-red-700">{error || 'Workflow not found'}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center space-x-4">
          <Link to="/workflows" className="text-primary-600 hover:text-primary-700">
            <ArrowLeft className="h-5 w-5" />
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-gray-900">{workflow.name}</h1>
            <p className="text-gray-600">Workflow Details</p>
          </div>
        </div>
        <span className={getStatusColor(workflow.status)}>
          {workflow.status}
        </span>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Workflow Info */}
        <div className="lg:col-span-1">
          <div className="card p-6 space-y-4">
            <h3 className="text-lg font-medium text-gray-900">Workflow Information</h3>
            
            <div>
              <label className="block text-sm font-medium text-gray-700">Document</label>
              <div className="mt-1 flex items-center space-x-2">
                <FileText className="h-4 w-4 text-gray-400" />
                <span className="text-sm text-gray-900">{getDocumentName(workflow.docUrl)}</span>
                <a 
                  href={workflow.docUrl} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-primary-600 hover:text-primary-700"
                >
                  <ExternalLink className="h-4 w-4" />
                </a>
              </div>
            </div>

            {workflow.docType && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Type</label>
                <div className="mt-1 flex items-center space-x-2">
                  <span className="text-sm text-gray-900">{workflow.docType}</span>
                  {workflow.confidence && (
                    <span className="text-sm text-gray-500">
                      ({formatConfidence(workflow.confidence)})
                    </span>
                  )}
                </div>
              </div>
            )}

            {workflow.priority && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Priority</label>
                <div className="mt-1">
                  <span className={getPriorityColor(workflow.priority)}>
                    {workflow.priority}
                  </span>
                </div>
              </div>
            )}

            <div>
              <label className="block text-sm font-medium text-gray-700">Created</label>
              <p className="mt-1 text-sm text-gray-900">{formatDate(workflow.createdAt)}</p>
            </div>

            {workflow.completedAt && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Duration</label>
                <p className="mt-1 text-sm text-gray-900">
                  {formatDuration(workflow.createdAt, workflow.completedAt)}
                </p>
              </div>
            )}

            {workflow.artifacts && workflow.artifacts.length > 0 && (
              <div>
                <label className="block text-sm font-medium text-gray-700">Artifacts</label>
                <div className="mt-1 space-y-1">
                  {workflow.artifacts.map((artifact, index) => (
                    <div key={index} className="flex items-center space-x-2">
                      <Download className="h-4 w-4 text-gray-400" />
                      <span className="text-sm text-primary-600 hover:text-primary-700 cursor-pointer">
                        {artifact.name}
                      </span>
                    </div>
                  ))}
                </div>
              </div>
            )}
          </div>
        </div>

        {/* Workflow Steps */}
        <div className="lg:col-span-2">
          <WorkflowSteps steps={workflow.steps || []} />
          
          {/* Logs Section */}
          {workflow.steps && workflow.steps.length > 0 && (
            <div className="mt-6 card p-6">
              <h3 className="text-lg font-medium text-gray-900 mb-4">Step Logs</h3>
              
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                {/* Step Selection */}
                <div className="md:col-span-1">
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    Select Step
                  </label>
                  <div className="space-y-1">
                    {workflow.steps.map((step) => (
                      <button
                        key={step.stepName}
                        onClick={() => handleStepClick(step.stepName)}
                        className={`w-full text-left px-3 py-2 text-sm rounded-md transition-colors ${
                          selectedStep === step.stepName
                            ? 'bg-primary-100 text-primary-700'
                            : 'hover:bg-gray-50'
                        }`}
                      >
                        {step.stepName}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Logs Display */}
                <div className="md:col-span-2">
                  {selectedStep ? (
                    <div>
                      <div className="flex items-center space-x-2 mb-2">
                        <Code className="h-4 w-4 text-gray-400" />
                        <span className="text-sm font-medium text-gray-700">
                          Logs for {selectedStep}
                        </span>
                      </div>
                      <div className="bg-gray-900 text-gray-100 p-4 rounded-md text-sm font-mono overflow-x-auto max-h-96 overflow-y-auto">
                        <pre className="whitespace-pre-wrap">
                          {logs[selectedStep] || 'Loading logs...'}
                        </pre>
                      </div>
                    </div>
                  ) : (
                    <div className="flex items-center justify-center h-32 bg-gray-50 rounded-md">
                      <p className="text-gray-500">Select a step to view logs</p>
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default WorkflowDetail;