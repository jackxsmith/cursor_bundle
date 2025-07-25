#!/usr/bin/env python3
"""
Cursor Bundle Web Interface
Enhanced Flask application for Cursor IDE management with security features.
"""

import os
import sys
import json
import subprocess
import logging
import signal
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Tuple

from flask import Flask, request, render_template_string, jsonify, redirect, url_for
from werkzeug.serving import make_server
from werkzeug.utils import secure_filename

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/cursor_web.log'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
app.secret_key = os.urandom(24)  # Secure secret key

# Configuration
CONFIG = {
    'VERSION': '6.9.163',
    'APP_NAME': 'Cursor Bundle Web Interface',
    'MAX_COMMAND_LENGTH': 1000,
    'ALLOWED_COMMANDS': [
        'status', 'version', 'check', 'info', 'help'
    ],
    'BUNDLE_DIR': Path(__file__).parent.absolute(),
    'LOG_FILE': '/tmp/cursor_web.log',
    'DEBUG': os.getenv('DEBUG', 'false').lower() == 'true'
}

# Enhanced HTML template with better styling and security
HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Cursor Bundle Web Interface">
    <meta http-equiv="Content-Security-Policy" content="default-src 'self'; style-src 'unsafe-inline';">
    <title>{{ config.APP_NAME }}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
        }
        h1 {
            text-align: center;
            margin-bottom: 30px;
            font-size: 2.5em;
        }
        .status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-bottom: 30px;
        }
        .status-card {
            background: rgba(255, 255, 255, 0.2);
            padding: 20px;
            border-radius: 10px;
            border: 1px solid rgba(255, 255, 255, 0.3);
        }
        .status-card h3 {
            margin-top: 0;
            color: #FFD700;
        }
        .form-group {
            margin-bottom: 20px;
        }
        label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        input, select, button {
            width: 100%;
            padding: 12px;
            border: none;
            border-radius: 5px;
            font-size: 16px;
            margin-bottom: 10px;
        }
        input, select {
            background: rgba(255, 255, 255, 0.9);
            color: #333;
        }
        button {
            background: #28a745;
            color: white;
            cursor: pointer;
            font-weight: bold;
            transition: background 0.3s;
        }
        button:hover {
            background: #218838;
        }
        button:disabled {
            background: #6c757d;
            cursor: not-allowed;
        }
        .output {
            background: rgba(0, 0, 0, 0.5);
            color: #00ff00;
            padding: 20px;
            border-radius: 5px;
            font-family: 'Courier New', monospace;
            white-space: pre-wrap;
            max-height: 400px;
            overflow-y: auto;
            margin-top: 20px;
        }
        .alert {
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        .alert-success { background: rgba(40, 167, 69, 0.8); }
        .alert-warning { background: rgba(255, 193, 7, 0.8); color: #333; }
        .alert-error { background: rgba(220, 53, 69, 0.8); }
        .footer {
            text-align: center;
            margin-top: 40px;
            font-size: 0.9em;
            opacity: 0.8;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 {{ config.APP_NAME }}</h1>
        <p style="text-align: center; margin-bottom: 30px;">Version {{ config.VERSION }}</p>
        
        <div class="status-grid">
            <div class="status-card">
                <h3>System Status</h3>
                <p><strong>Bundle Directory:</strong> {{ config.BUNDLE_DIR }}</p>
                <p><strong>Python Version:</strong> {{ python_version }}</p>
                <p><strong>Server Time:</strong> {{ current_time }}</p>
                <p><strong>Uptime:</strong> {{ uptime }}</p>
            </div>
            
            <div class="status-card">
                <h3>Available Commands</h3>
                <ul>
                    {% for cmd in config.ALLOWED_COMMANDS %}
                    <li>{{ cmd }}</li>
                    {% endfor %}
                </ul>
            </div>
            
            <div class="status-card">
                <h3>Quick Actions</h3>
                <form method="post" action="/quick-action">
                    <select name="action" required>
                        <option value="">Select Action</option>
                        <option value="status">Check Status</option>
                        <option value="version">Show Version</option>
                        <option value="info">System Info</option>
                        <option value="help">Show Help</option>
                    </select>
                    <button type="submit">Execute</button>
                </form>
            </div>
        </div>
        
        {% if message %}
        <div class="alert alert-{{ message.type }}">
            {{ message.text }}
        </div>
        {% endif %}
        
        <form method="post" action="/command">
            <div class="form-group">
                <label for="command">Safe Command Execution:</label>
                <input type="text" 
                       id="command" 
                       name="command" 
                       placeholder="Enter a safe command (status, version, check, info, help)"
                       maxlength="{{ config.MAX_COMMAND_LENGTH }}"
                       required>
            </div>
            <button type="submit">Execute Command</button>
        </form>
        
        {% if output %}
        <div class="output">{{ output }}</div>
        {% endif %}
        
        <div class="footer">
            <p>Cursor Bundle Web Interface | Secure Flask Application</p>
            <p>⚠️ Only safe, read-only commands are allowed for security</p>
        </div>
    </div>
</body>
</html>
"""

class CursorWebApp:
    """Enhanced Cursor Web Application with security and functionality."""
    
    def __init__(self):
        self.start_time = time.time()
        self.setup_signal_handlers()
        logger.info(f"Initializing {CONFIG['APP_NAME']} v{CONFIG['VERSION']}")
    
    def setup_signal_handlers(self):
        """Setup graceful shutdown handlers."""
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        logger.info(f"Received signal {signum}, shutting down gracefully...")
        sys.exit(0)
    
    def get_system_info(self) -> Dict:
        """Get comprehensive system information."""
        try:
            import platform
            
            return {
                'python_version': platform.python_version(),
                'platform': platform.platform(),
                'architecture': platform.architecture()[0],
                'processor': platform.processor() or 'Unknown',
                'current_time': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'uptime': self._format_uptime(),
                'working_directory': os.getcwd(),
                'user': os.getenv('USER', 'Unknown'),
                'home': os.getenv('HOME', 'Unknown')
            }
        except Exception as e:
            logger.error(f"Error getting system info: {e}")
            return {'error': str(e)}
    
    def _format_uptime(self) -> str:
        """Format uptime in human-readable format."""
        uptime_seconds = int(time.time() - self.start_time)
        hours, remainder = divmod(uptime_seconds, 3600)
        minutes, seconds = divmod(remainder, 60)
        return f"{hours:02d}:{minutes:02d}:{seconds:02d}"
    
    def validate_command(self, command: str) -> Tuple[bool, str]:
        """Validate if command is safe to execute."""
        if not command or len(command.strip()) == 0:
            return False, "Command cannot be empty"
        
        if len(command) > CONFIG['MAX_COMMAND_LENGTH']:
            return False, f"Command too long (max {CONFIG['MAX_COMMAND_LENGTH']} chars)"
        
        # Remove leading/trailing whitespace and convert to lowercase for checking
        clean_command = command.strip().lower()
        
        # Check if command starts with an allowed command
        allowed = any(clean_command.startswith(cmd) for cmd in CONFIG['ALLOWED_COMMANDS'])
        
        if not allowed:
            return False, f"Command not allowed. Allowed commands: {', '.join(CONFIG['ALLOWED_COMMANDS'])}"
        
        # Additional security checks
        dangerous_patterns = ['&', '|', ';', '`', '$', '>', '<', '(', ')', '{', '}']
        if any(pattern in command for pattern in dangerous_patterns):
            return False, "Command contains dangerous characters"
        
        return True, "Command is valid"
    
    def execute_safe_command(self, command: str) -> str:
        """Execute a validated safe command."""
        is_valid, message = self.validate_command(command)
        
        if not is_valid:
            return f"ERROR: {message}"
        
        try:
            # Map commands to safe implementations
            command_lower = command.strip().lower()
            
            if command_lower == 'status':
                return self._get_status()
            elif command_lower == 'version':
                return self._get_version()
            elif command_lower == 'check':
                return self._check_system()
            elif command_lower == 'info':
                return self._get_detailed_info()
            elif command_lower == 'help':
                return self._get_help()
            else:
                return f"Command '{command}' is recognized but not implemented yet."
                
        except Exception as e:
            logger.error(f"Error executing command '{command}': {e}")
            return f"ERROR: Failed to execute command - {str(e)}"
    
    def _get_status(self) -> str:
        """Get application status."""
        info = self.get_system_info()
        return f"""
CURSOR BUNDLE STATUS
===================
Application: {CONFIG['APP_NAME']}
Version: {CONFIG['VERSION']}
Uptime: {info.get('uptime', 'Unknown')}
Status: Running
Python: {info.get('python_version', 'Unknown')}
Platform: {info.get('platform', 'Unknown')}
User: {info.get('user', 'Unknown')}
Bundle Directory: {CONFIG['BUNDLE_DIR']}
"""
    
    def _get_version(self) -> str:
        """Get version information."""
        return f"{CONFIG['APP_NAME']} v{CONFIG['VERSION']}"
    
    def _check_system(self) -> str:
        """Perform system checks."""
        checks = []
        
        # Check bundle directory
        if CONFIG['BUNDLE_DIR'].exists():
            checks.append("✓ Bundle directory exists")
        else:
            checks.append("✗ Bundle directory missing")
        
        # Check for AppImage files
        appimage_files = list(CONFIG['BUNDLE_DIR'].glob("*.AppImage"))
        if appimage_files:
            checks.append(f"✓ Found {len(appimage_files)} AppImage file(s)")
        else:
            checks.append("⚠ No AppImage files found")
        
        # Check log file
        log_path = Path(CONFIG['LOG_FILE'])
        if log_path.exists():
            checks.append("✓ Log file accessible")
        else:
            checks.append("⚠ Log file not found")
        
        return "SYSTEM CHECK RESULTS\n" + "=" * 20 + "\n" + "\n".join(checks)
    
    def _get_detailed_info(self) -> str:
        """Get detailed system information."""
        info = self.get_system_info()
        details = []
        
        for key, value in info.items():
            if key != 'error':
                details.append(f"{key.replace('_', ' ').title()}: {value}")
        
        return "DETAILED SYSTEM INFO\n" + "=" * 20 + "\n" + "\n".join(details)
    
    def _get_help(self) -> str:
        """Get help information."""
        return f"""
CURSOR BUNDLE WEB INTERFACE HELP
================================

Available Commands:
  status   - Show application status
  version  - Show version information  
  check    - Perform system checks
  info     - Show detailed system information
  help     - Show this help message

Security Features:
  • Only safe, read-only commands allowed
  • Input validation and sanitization
  • Command length limits
  • No arbitrary code execution
  • Secure content security policy

Version: {CONFIG['VERSION']}
Bundle Directory: {CONFIG['BUNDLE_DIR']}
"""

# Initialize the application
cursor_app = CursorWebApp()

@app.route("/", methods=["GET", "POST"])
def index():
    """Main index page."""
    system_info = cursor_app.get_system_info()
    
    context = {
        'config': CONFIG,
        'python_version': system_info.get('python_version', 'Unknown'),
        'current_time': system_info.get('current_time', 'Unknown'),
        'uptime': system_info.get('uptime', 'Unknown'),
        'output': None,
        'message': None
    }
    
    return render_template_string(HTML_TEMPLATE, **context)

@app.route("/command", methods=["POST"])
def execute_command():
    """Execute a safe command."""
    command = request.form.get("command", "").strip()
    
    if not command:
        message = {'type': 'warning', 'text': 'Please enter a command'}
        output = None
    else:
        logger.info(f"Executing command: {command}")
        output = cursor_app.execute_safe_command(command)
        message = {'type': 'success', 'text': f'Command "{command}" executed'}
    
    system_info = cursor_app.get_system_info()
    
    context = {
        'config': CONFIG,
        'python_version': system_info.get('python_version', 'Unknown'),
        'current_time': system_info.get('current_time', 'Unknown'),
        'uptime': system_info.get('uptime', 'Unknown'),
        'output': output,
        'message': message
    }
    
    return render_template_string(HTML_TEMPLATE, **context)

@app.route("/quick-action", methods=["POST"])
def quick_action():
    """Execute a quick action."""
    action = request.form.get("action", "").strip()
    
    if action in CONFIG['ALLOWED_COMMANDS']:
        return redirect(url_for('execute_command'), code=307)
    else:
        message = {'type': 'error', 'text': 'Invalid action selected'}
        
        system_info = cursor_app.get_system_info()
        context = {
            'config': CONFIG,
            'python_version': system_info.get('python_version', 'Unknown'),
            'current_time': system_info.get('current_time', 'Unknown'),
            'uptime': system_info.get('uptime', 'Unknown'),
            'output': None,
            'message': message
        }
        
        return render_template_string(HTML_TEMPLATE, **context)

@app.route("/api/status")
def api_status():
    """API endpoint for status information."""
    system_info = cursor_app.get_system_info()
    return jsonify({
        'status': 'running',
        'version': CONFIG['VERSION'],
        'uptime': system_info.get('uptime', 'Unknown'),
        'timestamp': system_info.get('current_time', 'Unknown')
    })

@app.route("/health")
def health_check():
    """Health check endpoint."""
    return jsonify({'status': 'healthy', 'timestamp': datetime.now().isoformat()})

if __name__ == "__main__":
    try:
        logger.info(f"Starting {CONFIG['APP_NAME']} v{CONFIG['VERSION']}")
        logger.info(f"Bundle directory: {CONFIG['BUNDLE_DIR']}")
        
        # Run with enhanced security settings
        app.run(
            host="127.0.0.1",  # Localhost only for security
            port=8080,
            debug=CONFIG['DEBUG'],
            threaded=True,
            use_reloader=False  # Disable reloader for production
        )
    except KeyboardInterrupt:
        logger.info("Shutting down gracefully...")
    except Exception as e:
        logger.error(f"Failed to start application: {e}")
        sys.exit(1)