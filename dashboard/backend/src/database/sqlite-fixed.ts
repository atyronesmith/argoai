import sqlite3 from 'sqlite3';
import { promisify } from 'util';
import path from 'path';
import fs from 'fs';

export class Database {
  private db: sqlite3.Database;

  constructor(dbPath?: string) {
    const dataDir = path.dirname(dbPath || path.join(__dirname, '../../data/workflows.db'));

    // Ensure data directory exists
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }

    this.db = new sqlite3.Database(
      dbPath || path.join(__dirname, '../../data/workflows.db'),
      (err) => {
        if (err) {
          console.error('Error opening database:', err);
        } else {
          console.log('Connected to SQLite database');
        }
      }
    );
  }

  async initialize() {
    const run = promisify(this.db.run.bind(this.db));

    // Create workflows table
    await run(`
      CREATE TABLE IF NOT EXISTS workflows (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        doc_url TEXT NOT NULL,
        doc_type TEXT,
        priority TEXT,
        confidence REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed_at TEXT
      )
    `);

    // Create workflow_steps table
    await run(`
      CREATE TABLE IF NOT EXISTS workflow_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workflow_id TEXT NOT NULL,
        step_name TEXT NOT NULL,
        status TEXT NOT NULL,
        started_at TEXT,
        completed_at TEXT,
        logs TEXT,
        error TEXT,
        FOREIGN KEY (workflow_id) REFERENCES workflows(id)
      )
    `);
  }

  async insertWorkflow(workflow: any) {
    return new Promise((resolve, reject) => {
      this.db.run(`
        INSERT INTO workflows (id, name, status, doc_url, doc_type, priority, confidence, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        workflow.id,
        workflow.name,
        workflow.status,
        workflow.docUrl,
        workflow.docType || null,
        workflow.priority || null,
        workflow.confidence || null,
        workflow.createdAt,
        workflow.updatedAt
      ], function(err) {
        if (err) reject(err);
        else resolve(this);
      });
    });
  }

  async updateWorkflow(id: string, updates: any) {
    const setParts: string[] = [];
    const values: any[] = [];

    Object.keys(updates).forEach(key => {
      if (updates[key] !== undefined) {
        setParts.push(`${key} = ?`);
        values.push(updates[key]);
      }
    });

    if (setParts.length === 0) return;

    values.push(new Date().toISOString(), id);

    return new Promise((resolve, reject) => {
      this.db.run(`
        UPDATE workflows
        SET ${setParts.join(', ')}, updated_at = ?
        WHERE id = ?
      `, values, function(err) {
        if (err) reject(err);
        else resolve(this);
      });
    });
  }

  async getWorkflows(limit: number = 50, offset: number = 0): Promise<any[]> {
    return new Promise((resolve, reject) => {
      this.db.all(`
        SELECT * FROM workflows
        ORDER BY created_at DESC
        LIMIT ? OFFSET ?
      `, [limit, offset], (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
  }

  async getWorkflow(id: string): Promise<any> {
    return new Promise((resolve, reject) => {
      this.db.get(`
        SELECT * FROM workflows WHERE id = ?
      `, [id], (err, row) => {
        if (err) reject(err);
        else resolve(row);
      });
    });
  }

  async insertStep(step: any) {
    return new Promise((resolve, reject) => {
      this.db.run(`
        INSERT INTO workflow_steps (workflow_id, step_name, status, started_at, completed_at, logs, error)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      `, [
        step.workflowId,
        step.stepName,
        step.status,
        step.startedAt || null,
        step.completedAt || null,
        step.logs || null,
        step.error || null
      ], function(err) {
        if (err) reject(err);
        else resolve(this.lastID);
      });
    });
  }

  async updateStep(id: number, updates: any) {
    const setParts: string[] = [];
    const values: any[] = [];

    Object.keys(updates).forEach(key => {
      if (updates[key] !== undefined) {
        setParts.push(`${key} = ?`);
        values.push(updates[key]);
      }
    });

    if (setParts.length === 0) return;

    values.push(id);

    return new Promise((resolve, reject) => {
      this.db.run(`
        UPDATE workflow_steps
        SET ${setParts.join(', ')}
        WHERE id = ?
      `, values, function(err) {
        if (err) reject(err);
        else resolve(this);
      });
    });
  }

  async getWorkflowSteps(workflowId: string): Promise<any[]> {
    return new Promise((resolve, reject) => {
      this.db.all(`
        SELECT * FROM workflow_steps
        WHERE workflow_id = ?
        ORDER BY id
      `, [workflowId], (err, rows) => {
        if (err) reject(err);
        else resolve(rows);
      });
    });
  }

  async getMetrics(): Promise<any> {
    return new Promise((resolve, reject) => {
      this.db.get(`
        SELECT
          COUNT(*) as totalWorkflows,
          COUNT(CASE WHEN status = 'Running' THEN 1 END) as activeWorkflows,
          COUNT(CASE WHEN status = 'Succeeded' THEN 1 END) as completedWorkflows,
          COUNT(CASE WHEN status IN ('Failed', 'Error') THEN 1 END) as failedWorkflows,
          AVG(CASE
            WHEN status = 'Succeeded' AND completed_at IS NOT NULL
            THEN (julianday(completed_at) - julianday(created_at)) * 24 * 60 * 60
          END) as avgTime
        FROM workflows
      `, (err, row: any) => {
        if (err) {
          reject(err);
        } else {
          resolve({
            totalWorkflows: row.totalWorkflows || 0,
            activeWorkflows: row.activeWorkflows || 0,
            completedWorkflows: row.completedWorkflows || 0,
            failedWorkflows: row.failedWorkflows || 0,
            avgProcessingTime: row.avgTime || 0,
            documentsProcessed: row.completedWorkflows || 0
          });
        }
      });
    });
  }

  close() {
    this.db.close();
  }
}
