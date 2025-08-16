import React from 'react';
import { CheckCircle, Clock, AlertCircle, Play, ArrowRight } from 'lucide-react';
import { WorkflowStep } from '../types/workflow';
import { formatDuration, getStatusColor } from '../utils/formatters';

interface WorkflowStepsProps {
  steps: WorkflowStep[];
}

const WorkflowSteps: React.FC<WorkflowStepsProps> = ({ steps }) => {
  const stepOrder = [
    'init-model',
    'ingest-document',
    'classify-document',
    'extract-info',
    'process-by-type',
    'generate-report'
  ];

  const stepLabels = {
    'init-model': 'Initialize Model',
    'ingest-document': 'Ingest Document',
    'classify-document': 'AI Classification',
    'extract-info': 'Extract Information',
    'process-by-type': 'Route & Process',
    'generate-report': 'Generate Report'
  };

  const getStepIcon = (status: string) => {
    switch (status) {
      case 'Running':
        return <Play className="h-5 w-5 text-blue-600" />;
      case 'Succeeded':
        return <CheckCircle className="h-5 w-5 text-green-600" />;
      case 'Failed':
      case 'Error':
        return <AlertCircle className="h-5 w-5 text-red-600" />;
      default:
        return <Clock className="h-5 w-5 text-gray-400" />;
    }
  };

  // Create ordered steps array
  const orderedSteps = stepOrder.map(stepName => {
    const step = steps.find(s => s.stepName === stepName);
    return step || {
      id: 0,
      workflowId: '',
      stepName,
      status: 'Pending',
      startedAt: undefined,
      completedAt: undefined,
      error: undefined
    } as WorkflowStep;
  });

  return (
    <div className="card p-6">
      <h3 className="text-lg font-medium text-gray-900 mb-4">Workflow Progress</h3>

      <div className="space-y-4">
        {orderedSteps.map((step, index) => (
          <div key={step.stepName} className="flex items-center">
            {/* Step Icon */}
            <div className="flex-shrink-0">
              {getStepIcon(step.status)}
            </div>

            {/* Step Content */}
            <div className="ml-4 flex-1">
              <div className="flex items-center justify-between">
                <div>
                  <h4 className="text-sm font-medium text-gray-900">
                    {stepLabels[step.stepName as keyof typeof stepLabels] || step.stepName}
                  </h4>
                  <div className="flex items-center space-x-4 mt-1">
                    <span className={getStatusColor(step.status)}>
                      {step.status}
                    </span>
                    {step.startedAt && step.completedAt && (
                      <span className="text-xs text-gray-500">
                        Duration: {formatDuration(step.startedAt, step.completedAt)}
                      </span>
                    )}
                    {step.status === 'Running' && step.startedAt && (
                      <span className="text-xs text-gray-500">
                        Running: {formatDuration(step.startedAt)}
                      </span>
                    )}
                  </div>
                </div>
              </div>

              {/* Error Message */}
              {step.error && (
                <div className="mt-2 p-2 bg-red-50 border border-red-200 rounded-md">
                  <p className="text-sm text-red-700">{step.error}</p>
                </div>
              )}
            </div>

            {/* Arrow for non-last steps */}
            {index < orderedSteps.length - 1 && (
              <div className="ml-4 flex-shrink-0">
                <ArrowRight className="h-4 w-4 text-gray-400" />
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Progress Bar */}
      <div className="mt-6">
        <div className="flex justify-between text-sm text-gray-600 mb-1">
          <span>Progress</span>
          <span>
            {orderedSteps.filter(s => s.status === 'Succeeded').length} of {orderedSteps.length} completed
          </span>
        </div>
        <div className="w-full bg-gray-200 rounded-full h-2">
          <div
            className="bg-primary-600 h-2 rounded-full transition-all duration-300"
            style={{
              width: `${(orderedSteps.filter(s => s.status === 'Succeeded').length / orderedSteps.length) * 100}%`
            }}
          />
        </div>
      </div>
    </div>
  );
};

export default WorkflowSteps;