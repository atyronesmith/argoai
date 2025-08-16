import express from 'express';
import { WorkflowService } from '../services/workflowService';

const router = express.Router();
const workflowService = new WorkflowService();

// Get system metrics
router.get('/', async (req, res) => {
  try {
    const metrics = await workflowService.getMetrics();
    res.json(metrics);
  } catch (error) {
    console.error('Error fetching metrics:', error);
    res.status(500).json({ error: 'Failed to fetch metrics' });
  }
});

// Get document summaries
router.get('/documents', async (req, res) => {
  try {
    const documents = await workflowService.getDocumentSummaries();
    res.json(documents);
  } catch (error) {
    console.error('Error fetching document summaries:', error);
    res.status(500).json({ error: 'Failed to fetch document summaries' });
  }
});

export default router;