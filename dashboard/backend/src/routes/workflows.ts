import express from 'express';
import { WorkflowService } from '../services/workflowService';

const router = express.Router();
const workflowService = new WorkflowService();

// Get all workflows with pagination
router.get('/', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit as string) || 50;
    const offset = parseInt(req.query.offset as string) || 0;
    
    const workflows = await workflowService.getWorkflows(limit, offset);
    res.json(workflows);
  } catch (error) {
    console.error('Error fetching workflows:', error);
    res.status(500).json({ error: 'Failed to fetch workflows' });
  }
});

// Get specific workflow with details
router.get('/:id', async (req, res) => {
  try {
    const workflow = await workflowService.getWorkflow(req.params.id);
    if (!workflow) {
      return res.status(404).json({ error: 'Workflow not found' });
    }
    res.json(workflow);
  } catch (error) {
    console.error('Error fetching workflow:', error);
    res.status(500).json({ error: 'Failed to fetch workflow' });
  }
});

// Get workflow steps
router.get('/:id/steps', async (req, res) => {
  try {
    const steps = await workflowService.getWorkflowSteps(req.params.id);
    res.json(steps);
  } catch (error) {
    console.error('Error fetching workflow steps:', error);
    res.status(500).json({ error: 'Failed to fetch workflow steps' });
  }
});

// Get workflow logs
router.get('/:id/logs', async (req, res) => {
  try {
    const stepName = req.query.step as string;
    const logs = await workflowService.getWorkflowLogs(req.params.id, stepName);
    res.json({ logs });
  } catch (error) {
    console.error('Error fetching workflow logs:', error);
    res.status(500).json({ error: 'Failed to fetch workflow logs' });
  }
});

// Submit new workflow
router.post('/', async (req, res) => {
  try {
    const { docUrl, model } = req.body;
    
    if (!docUrl) {
      return res.status(400).json({ error: 'Document URL is required' });
    }

    const result = await workflowService.submitWorkflow(docUrl, model);
    res.json(result);
  } catch (error) {
    console.error('Error submitting workflow:', error);
    res.status(500).json({ error: 'Failed to submit workflow' });
  }
});

// Sync workflows from Argo
router.post('/sync', async (req, res) => {
  try {
    await workflowService.syncWorkflows();
    res.json({ message: 'Workflows synced successfully' });
  } catch (error) {
    console.error('Error syncing workflows:', error);
    res.status(500).json({ error: 'Failed to sync workflows' });
  }
});

export default router;