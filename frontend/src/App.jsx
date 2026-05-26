import React, { useState, useEffect, useRef } from 'react';
import { 
  Activity, 
  Terminal, 
  Settings, 
  Play, 
  RefreshCw, 
  CheckCircle2, 
  AlertTriangle, 
  XCircle,
  Database,
  Layers,
  Sparkles
} from 'lucide-react';
import './App.css';

function App() {
  // Determine default base URL using Vite env var, falling back to localhost:8000
  const defaultApiUrl = import.meta.env?.VITE_API_BASE_URL || 'http://localhost:8000';
  
  const [apiBaseUrl, setApiBaseUrl] = useState(defaultApiUrl);
  const [customMessage, setCustomMessage] = useState('');
  const [healthStatus, setHealthStatus] = useState('checking'); // 'healthy', 'unhealthy', 'checking', 'unknown'
  const [healthDetails, setHealthDetails] = useState(null);
  const [logs, setLogs] = useState([]);
  
  // Stats Counters
  const [stats, setStats] = useState({
    infoCount: 0,
    warnCount: 0,
    errorCount: 0,
    healthChecks: 0
  });

  const terminalEndRef = useRef(null);

  // Auto-scroll terminal viewport to bottom when new logs are added
  useEffect(() => {
    terminalEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [logs]);

  // Initial health check on application startup
  useEffect(() => {
    performHealthCheck();
  }, [apiBaseUrl]);

  // Performs a health check request to the backend
  const performHealthCheck = async () => {
    setHealthStatus('checking');
    const checkTime = new Date().toLocaleTimeString();
    
    try {
      const response = await fetch(`${apiBaseUrl}/health`);
      if (response.ok) {
        const data = await response.json();
        setHealthStatus('healthy');
        setHealthDetails(data);
        addLog('success', 'Health Check Passed', {
          api: apiBaseUrl,
          response: data
        });
        setStats(prev => ({ 
          ...prev, 
          healthChecks: prev.healthChecks + 1 
        }));
      } else {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
    } catch (error) {
      setHealthStatus('unhealthy');
      setHealthDetails(null);
      addLog('error', `Health Check Failed - Could not reach backend API at: ${apiBaseUrl}`, {
        error: error.message
      });
      setStats(prev => ({ 
        ...prev, 
        healthChecks: prev.healthChecks + 1 
      }));
    }
  };

  // Triggers a request to generate backend logs
  const triggerLogGeneration = async (level) => {
    const timestamp = new Date().toLocaleTimeString();
    
    try {
      let url = `${apiBaseUrl}/generate-log?level=${level}`;
      if (customMessage.trim()) {
        url += `&message=${encodeURIComponent(customMessage)}`;
      }
      
      const response = await fetch(url);
      const data = await response.json();
      
      if (response.ok) {
        addLog(level, data.message || `Generated ${level} log entries.`, data);
        
        // Update statistics counter
        setStats(prev => {
          const key = `${level}Count`;
          return {
            ...prev,
            infoCount: level === 'info' ? prev.infoCount + 1 : prev.infoCount,
            warnCount: level === 'warning' ? prev.warnCount + 1 : prev.warnCount,
            errorCount: level === 'error' ? prev.errorCount + 1 : prev.errorCount,
          };
        });
      } else {
        throw new Error(data.detail || `Server returned ${response.status}`);
      }
    } catch (error) {
      addLog('error', `Failed to generate ${level} log - Backend connectivity issue`, {
        error: error.message,
        target_url: apiBaseUrl
      });
    }
  };

  // Adds a formatted entry to the UI terminal
  const addLog = (level, message, metadata = {}) => {
    const newLog = {
      id: Date.now() + Math.random().toString(36).substr(2, 5),
      timestamp: new Date().toISOString().substring(11, 19),
      level,
      message,
      metadata
    };
    setLogs(prev => [...prev, newLog]);
  };

  // Clears the logs history in the browser
  const clearTerminal = () => {
    setLogs([]);
  };

  return (
    <div className="app-container">
      {/* Top Header Section */}
      <header className="dashboard-header">
        <div className="header-title-section">
          <Activity className="header-icon" size={32} />
          <div>
            <h1>Cloud-Native DevOps Dashboard</h1>
            <p>Demonstrate observability, structured logging, and microservices health monitoring.</p>
          </div>
        </div>

        {/* Global Settings & Config */}
        <div className="config-panel">
          <div className="config-input-group">
            <Settings size={16} className="text-muted" />
            <label htmlFor="api-url">API Base URL:</label>
            <input 
              id="api-url"
              type="text" 
              className="config-input" 
              value={apiBaseUrl} 
              onChange={(e) => setApiBaseUrl(e.target.value)}
              placeholder="e.g. http://localhost:8000"
            />
          </div>
          
          <div className="health-indicator">
            <span className={`pulse-dot ${healthStatus}`}></span>
            <span style={{ textTransform: 'capitalize' }}>
              Backend Status: {healthStatus === 'checking' ? 'connecting...' : healthStatus}
            </span>
          </div>
          
          <button className="btn-terminal-clear" onClick={performHealthCheck} title="Recheck Health">
            <RefreshCw size={12} />
          </button>
        </div>
      </header>

      {/* Main Grid: Control Station on left, Terminal output on right */}
      <main className="dashboard-grid">
        
        {/* Left Side: Controls and Actions */}
        <div className="glass-card">
          <h2 className="card-title">
            <Layers size={20} />
            Control Station
          </h2>
          
          <div className="control-actions">
            
            {/* Custom Log Message field */}
            <div className="input-field-group">
              <label htmlFor="log-message">Custom Log Message (Optional):</label>
              <input 
                id="log-message"
                type="text" 
                className="text-input"
                placeholder="Type a custom log message here..." 
                value={customMessage}
                onChange={(e) => setCustomMessage(e.target.value)}
              />
            </div>
            
            {/* Generate Log Actions */}
            <div className="input-field-group">
              <label>Simulate Log Event:</label>
              <div className="button-grid">
                <button 
                  className="btn btn-info"
                  onClick={() => triggerLogGeneration('info')}
                >
                  <Play size={16} />
                  Generate Info Log
                </button>
                <button 
                  className="btn btn-warning"
                  onClick={() => triggerLogGeneration('warning')}
                >
                  <AlertTriangle size={16} />
                  Generate Warning Log
                </button>
                <button 
                  className="btn btn-error"
                  onClick={() => triggerLogGeneration('error')}
                >
                  <XCircle size={16} />
                  Generate Error Log
                </button>
              </div>
            </div>
            
            {/* Health check action */}
            <div className="input-field-group" style={{ marginTop: '0.5rem' }}>
              <label>System Integrity Check:</label>
              <button 
                className="btn btn-health"
                onClick={performHealthCheck}
              >
                <CheckCircle2 size={16} />
                Check Backend Health
              </button>
            </div>
          </div>

          {/* Quick Metrics Statistics Widget */}
          <div style={{ marginTop: '0.5rem' }}>
            <h3 className="card-title" style={{ fontSize: '1rem', marginBottom: '1rem', paddingBottom: '0.5rem' }}>
              <Database size={16} />
              Session Telemetry
            </h3>
            <div className="metrics-summary-grid">
              <div className="metric-stat-card">
                <span className="metric-stat-label">Info logs</span>
                <span className="metric-stat-value info">{stats.infoCount}</span>
              </div>
              <div className="metric-stat-card">
                <span className="metric-stat-label">Warnings</span>
                <span className="metric-stat-value warning">{stats.warnCount}</span>
              </div>
              <div className="metric-stat-card">
                <span className="metric-stat-label">Errors</span>
                <span className="metric-stat-value error">{stats.errorCount}</span>
              </div>
              <div className="metric-stat-card">
                <span className="metric-stat-label">health checks</span>
                <span className="metric-stat-value success">{stats.healthChecks}</span>
              </div>
            </div>
          </div>
        </div>

        {/* Right Side: Interactive Logs Terminal Viewer */}
        <div className="glass-card terminal-card">
          <div className="terminal-header">
            <div className="header-title-section">
              <Terminal size={20} className="header-icon" />
              <h2 style={{ fontSize: '1.25rem', fontWeight: 700 }}>Live Logs Viewer</h2>
            </div>
            <div className="terminal-actions">
              <div className="terminal-dots" style={{ marginRight: '1rem' }}>
                <span className="dot red"></span>
                <span className="dot yellow"></span>
                <span className="dot green"></span>
              </div>
              {logs.length > 0 && (
                <button className="btn-terminal-clear" onClick={clearTerminal}>
                  Clear Terminal
                </button>
              )}
            </div>
          </div>

          <div className="terminal-viewport">
            {logs.length === 0 ? (
              <div className="terminal-placeholder">
                <Sparkles size={24} style={{ marginBottom: '0.5rem', opacity: 0.7 }} />
                <span>Terminal idle. Click buttons on the left to trigger event logs.</span>
              </div>
            ) : (
              logs.map((log) => (
                <div className="terminal-row" key={log.id}>
                  <div>
                    <span className="log-time">[{log.timestamp}]</span>
                    <span className={`log-level-badge ${log.level}`}>
                      {log.level}
                    </span>
                    <span className="log-msg">{log.message}</span>
                  </div>
                  {log.metadata && Object.keys(log.metadata).length > 0 && (
                    <pre className="log-metadata-box">
                      {JSON.stringify(log.metadata, null, 2)}
                    </pre>
                  )}
                </div>
              ))
            )}
            <div ref={terminalEndRef} />
          </div>
        </div>
      </main>
      
      {/* Footer Meta Details */}
      {healthDetails && (
        <footer style={{ 
          textAlign: 'center', 
          fontSize: '0.8rem', 
          color: 'var(--text-muted)', 
          marginTop: '1rem',
          display: 'flex',
          justifyContent: 'center',
          gap: '1.5rem'
        }}>
          <span>Backend Env: <strong>{healthDetails.environment}</strong></span>
          <span>FastAPI version: <strong>1.0.0</strong></span>
          <span>Target Host: <strong>{apiBaseUrl}</strong></span>
        </footer>
      )}
    </div>
  );
}

export default App;
