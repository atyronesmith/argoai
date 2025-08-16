import express from 'express';
import cors from 'cors';
import compression from 'compression';
import helmet from 'helmet';
import { WebSocketServer } from 'ws';
import { createServer } from 'http';
import dotenv from 'dotenv';

import workflowRoutes from './routes/workflows';
import metricsRoutes from './routes/metrics';
import { WorkflowService } from './services/workflowService';

dotenv.config();

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: (origin, callback) => {
    // Allow requests from dashboard routes and localhost
    const allowedOrigins = [
      'http://localhost:3000',
      'http://localhost:8080',
      process.env.FRONTEND_URL
    ].filter(Boolean);

    // Also allow any origin that matches our OpenShift routes pattern
    const allowedPatterns = [
      /^https?:\/\/.*dashboard.*\.apps-crc\.testing$/,
      /^https?:\/\/localhost:\d+$/
    ];

    if (!origin ||
        allowedOrigins.includes(origin) ||
        allowedPatterns.some(pattern => pattern.test(origin))) {
      callback(null, true);
    } else {
      console.log('CORS rejected origin:', origin);
      callback(new Error('Not allowed by CORS'));
    }
  },
  credentials: true
}));
app.use(express.json());

// Routes
app.use('/api/workflows', workflowRoutes);
app.use('/api/metrics', metricsRoutes);

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Create HTTP server
const server = createServer(app);

// WebSocket server for real-time updates
const wss = new WebSocketServer({
  server,
  path: '/ws'
});

// Workflow service for real-time sync
const workflowService = new WorkflowService();

// WebSocket connections
const clients = new Set<any>();

wss.on('connection', (ws) => {
  console.log('New WebSocket connection established');
  clients.add(ws);

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message.toString());
      console.log('Received WebSocket message:', data);

      // Handle different message types
      if (data.type === 'subscribe') {
        ws.send(JSON.stringify({ type: 'subscribed', message: 'Successfully subscribed to updates' }));
      }
    } catch (error) {
      console.error('Error parsing WebSocket message:', error);
    }
  });

  ws.on('close', () => {
    console.log('WebSocket connection closed');
    clients.delete(ws);
  });

  ws.on('error', (error) => {
    console.error('WebSocket error:', error);
    clients.delete(ws);
  });
});

// Broadcast function for real-time updates
function broadcast(data: any) {
  const message = JSON.stringify(data);
  clients.forEach(client => {
    if (client.readyState === 1) { // WebSocket.OPEN
      client.send(message);
    }
  });
}

// Periodic workflow sync and real-time updates
let syncInterval: NodeJS.Timeout;

function startPeriodicSync() {
  syncInterval = setInterval(async () => {
    try {
      console.log('Syncing workflows...');
      await workflowService.syncWorkflows();

      // Get updated data and broadcast to clients
      const [workflows, metrics] = await Promise.all([
        workflowService.getWorkflows(20, 0),
        workflowService.getMetrics()
      ]);

      broadcast({
        type: 'workflow_update',
        data: { workflows, metrics }
      });
    } catch (error) {
      console.error('Error during periodic sync:', error);
    }
  }, 10000); // Sync every 10 seconds
}

// Graceful shutdown
function gracefulShutdown() {
  console.log('Shutting down gracefully...');

  if (syncInterval) {
    clearInterval(syncInterval);
  }

  workflowService.close();

  server.close(() => {
    console.log('HTTP server closed');
    process.exit(0);
  });
}

process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

// Start server
server.listen(port, () => {
  console.log(`AI Workflow Dashboard Backend running on port ${port}`);
  console.log(`WebSocket server ready for connections`);

  // Start periodic sync
  startPeriodicSync();

  // Initial sync
  workflowService.syncWorkflows().catch(error => {
    console.error('Initial workflow sync failed:', error);
  });
});

export { broadcast };