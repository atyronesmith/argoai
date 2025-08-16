import React from 'react';
import { Link } from 'react-router-dom';
import { Clock, FileText, AlertCircle, CheckCircle, Play } from 'lucide-react';
import { Workflow } from '../types/workflow';
import { formatRelativeTime, formatDuration, getStatusColor, getPriorityColor, formatConfidence } from '../utils/formatters';

interface WorkflowCardProps {
  workflow: Workflow;
}

const WorkflowCard: React.FC<WorkflowCardProps> = ({ workflow }) => {
  const getStatusIcon = () => {
    switch (workflow.status) {
      case 'Running':
        return <Play className="h-4 w-4 text-blue-600" />;
      case 'Succeeded':
        return <CheckCircle className="h-4 w-4 text-green-600" />;
      case 'Failed':
      case 'Error':
        return <AlertCircle className="h-4 w-4 text-red-600" />;
      default:
        return <Clock className="h-4 w-4 text-gray-400" />;
    }
  };

  const getDocumentName = (url: string) => {
    try {
      const urlObj = new URL(url);
      return urlObj.pathname.split('/').pop() || 'Unknown Document';
    } catch {
      return 'Unknown Document';
    }
  };

  return (
    <Link to={`/workflows/${workflow.id}`} className="block">
      <div className="card p-6 hover:shadow-lg transition-shadow duration-200 border border-gray-200">
        {/* Header */}
        <div className="flex items-center justify-between mb-4">
          <div className="flex items-center space-x-2">
            {getStatusIcon()}
            <span className="font-medium text-gray-900 truncate">
              {workflow.name}
            </span>
          </div>
          <span className={getStatusColor(workflow.status)}>
            {workflow.status}
          </span>
        </div>

        {/* Document Info */}
        <div className="flex items-center space-x-2 mb-3">
          <FileText className="h-4 w-4 text-gray-400" />
          <span className="text-sm text-gray-600 truncate">
            {getDocumentName(workflow.docUrl)}
          </span>
        </div>

        {/* Classification Results */}
        {workflow.docType && (
          <div className="flex items-center justify-between mb-3">
            <div className="flex items-center space-x-2">
              <span className="text-sm font-medium text-gray-700">Type:</span>
              <span className="text-sm text-gray-900">{workflow.docType}</span>
            </div>
            {workflow.confidence && (
              <span className="text-sm text-gray-500">
                {formatConfidence(workflow.confidence)}
              </span>
            )}
          </div>
        )}

        {/* Priority */}
        {workflow.priority && (
          <div className="flex items-center space-x-2 mb-3">
            <span className="text-sm font-medium text-gray-700">Priority:</span>
            <span className={getPriorityColor(workflow.priority)}>
              {workflow.priority}
            </span>
          </div>
        )}

        {/* Timing */}
        <div className="flex items-center justify-between text-sm text-gray-500">
          <span>Created {formatRelativeTime(workflow.createdAt)}</span>
          {workflow.completedAt && (
            <span>
              Duration: {formatDuration(workflow.createdAt, workflow.completedAt)}
            </span>
          )}
          {workflow.status === 'Running' && (
            <span>
              Running: {formatDuration(workflow.createdAt)}
            </span>
          )}
        </div>
      </div>
    </Link>
  );
};

export default WorkflowCard;