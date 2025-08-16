import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import WorkflowDetail from './pages/WorkflowDetail';
import './index.css';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/" element={<Layout />}>
          <Route index element={<Dashboard />} />
          <Route path="workflows" element={<Dashboard />} />
          <Route path="workflows/:id" element={<WorkflowDetail />} />
          <Route path="documents" element={<div>Documents page (TODO)</div>} />
          <Route path="metrics" element={<div>Metrics page (TODO)</div>} />
          <Route path="settings" element={<div>Settings page (TODO)</div>} />
        </Route>
      </Routes>
    </Router>
  );
}

export default App;