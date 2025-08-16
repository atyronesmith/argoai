import React, { useState } from 'react';
import { Plus, Upload, Loader2 } from 'lucide-react';
import { apiClient } from '../utils/api';

interface SubmitWorkflowFormProps {
  onSubmit?: (workflow: any) => void;
}

const SubmitWorkflowForm: React.FC<SubmitWorkflowFormProps> = ({ onSubmit }) => {
  const [isOpen, setIsOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [formData, setFormData] = useState({
    docUrl: '',
    model: 'llama3.2:3b'
  });
  const [error, setError] = useState<string | null>(null);

  const models = [
    { value: 'llama3.2:3b', label: 'Llama 3.2 3B (Fast)' },
    { value: 'mistral:7b', label: 'Mistral 7B (Accurate)' },
    { value: 'phi3:mini', label: 'Phi 3 Mini (Balanced)' }
  ];

  const sampleDocuments = [
    'https://raw.githubusercontent.com/example/sample-invoice.pdf',
    'https://raw.githubusercontent.com/example/sample-contract.pdf',
    'https://raw.githubusercontent.com/example/sample-report.pdf'
  ];

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setError(null);

    try {
      const result = await apiClient.submitWorkflow(formData.docUrl, formData.model);
      onSubmit?.(result);
      setIsOpen(false);
      setFormData({ docUrl: '', model: 'llama3.2:3b' });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to submit workflow');
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSampleSelect = (url: string) => {
    setFormData(prev => ({ ...prev, docUrl: url }));
  };

  if (!isOpen) {
    return (
      <button
        onClick={() => setIsOpen(true)}
        className="btn-primary"
      >
        <Plus className="h-4 w-4 mr-2" />
        Submit Workflow
      </button>
    );
  }

  return (
    <div className="fixed inset-0 bg-gray-600 bg-opacity-50 overflow-y-auto h-full w-full z-50">
      <div className="relative top-20 mx-auto p-5 border w-96 shadow-lg rounded-md bg-white">
        <div className="mt-3">
          <div className="flex items-center justify-between mb-4">
            <h3 className="text-lg font-medium text-gray-900">Submit New Workflow</h3>
            <button
              onClick={() => setIsOpen(false)}
              className="text-gray-400 hover:text-gray-600"
            >
              ×
            </button>
          </div>

          <form onSubmit={handleSubmit} className="space-y-4">
            {/* Document URL */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Document URL
              </label>
              <input
                type="url"
                value={formData.docUrl}
                onChange={(e) => setFormData(prev => ({ ...prev, docUrl: e.target.value }))}
                placeholder="https://example.com/document.pdf"
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
                required
              />
            </div>

            {/* Sample Documents */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Or choose a sample document:
              </label>
              <div className="space-y-1">
                {sampleDocuments.map((url, index) => (
                  <button
                    key={index}
                    type="button"
                    onClick={() => handleSampleSelect(url)}
                    className="block w-full text-left px-3 py-2 text-sm text-primary-600 hover:bg-primary-50 rounded-md"
                  >
                    Sample Document {index + 1}
                  </button>
                ))}
              </div>
            </div>

            {/* Model Selection */}
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                AI Model
              </label>
              <select
                value={formData.model}
                onChange={(e) => setFormData(prev => ({ ...prev, model: e.target.value }))}
                className="w-full px-3 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-2 focus:ring-primary-500 focus:border-transparent"
              >
                {models.map(model => (
                  <option key={model.value} value={model.value}>
                    {model.label}
                  </option>
                ))}
              </select>
            </div>

            {/* Error Message */}
            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-md">
                <p className="text-sm text-red-700">{error}</p>
              </div>
            )}

            {/* Submit Buttons */}
            <div className="flex space-x-3">
              <button
                type="submit"
                disabled={isSubmitting}
                className="flex-1 btn-primary disabled:opacity-50 disabled:cursor-not-allowed"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="h-4 w-4 mr-2 animate-spin" />
                    Submitting...
                  </>
                ) : (
                  <>
                    <Upload className="h-4 w-4 mr-2" />
                    Submit
                  </>
                )}
              </button>
              <button
                type="button"
                onClick={() => setIsOpen(false)}
                className="btn-secondary"
              >
                Cancel
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
};

export default SubmitWorkflowForm;