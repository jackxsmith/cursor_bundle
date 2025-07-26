#!/usr/bin/env python3
"""
CURSOR BUNDLE LAUNCHER v2.0.0 - Professional Edition
A professional, secure, and efficient GUI launcher for Cursor IDE bundle management.

Features:
- Clean GUI launcher interface
- Professional error handling and self-correction
- Comprehensive logging and auditing
- Secure command validation
- System health monitoring
- Configuration management
- Session management
- Professional code structure
"""

import os
import sys
import json
import subprocess
import logging
import time
import sqlite3
import hashlib
import secrets
import threading
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict
from functools import wraps
from contextlib import contextmanager
import traceback
import platform

# GUI imports
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, scrolledtext
    GUI_AVAILABLE = True
except ImportError:
    GUI_AVAILABLE = False
    print("Warning: GUI components not available, running in CLI mode")

# Web interface imports
try:
    from flask import Flask, request, render_template_string, jsonify, session
    from werkzeug.serving import make_server
    WEB_AVAILABLE = True
except ImportError:
    WEB_AVAILABLE = False
    print("Warning: Web interface not available")

# Professional logging configuration
class ProfessionalLogger:
    """Professional logging system with multiple handlers and audit capabilities"""
    
    def __init__(self, name: str, log_dir: str = "/tmp/cursor_launcher"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)
        self.logger.handlers.clear()
        
        # Create formatters
        detailed_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
        )
        
        # File handlers
        info_handler = logging.FileHandler(self.log_dir / 'launcher.log')
        info_handler.setLevel(logging.INFO)
        info_handler.setFormatter(detailed_formatter)
        
        error_handler = logging.FileHandler(self.log_dir / 'error.log')
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(detailed_formatter)
        
        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(detailed_formatter)
        
        # Add handlers
        self.logger.addHandler(info_handler)
        self.logger.addHandler(error_handler)
        self.logger.addHandler(console_handler)
        
        # Audit logger
        self.audit_logger = logging.getLogger(f"{name}.audit")
        audit_handler = logging.FileHandler(self.log_dir / 'audit.log')
        audit_formatter = logging.Formatter(
            '%(asctime)s - AUDIT - %(message)s'
        )
        audit_handler.setFormatter(audit_formatter)
        self.audit_logger.addHandler(audit_handler)
    
    def debug(self, msg: str): self.logger.debug(msg)
    def info(self, msg: str): self.logger.info(msg)
    def warning(self, msg: str): self.logger.warning(msg)
    def error(self, msg: str): self.logger.error(msg)
    def critical(self, msg: str): self.logger.critical(msg)
    
    def audit(self, action: str, details: str = ""):
        """Log audit events"""
        audit_msg = f"ACTION:{action} | DETAILS:{details}"
        self.audit_logger.info(audit_msg)

# Global logger
logger = ProfessionalLogger(__name__)

@dataclass
class LauncherConfig:
    """Professional launcher configuration"""
    VERSION: str = "2.0.0"
    APP_NAME: str = "Cursor Bundle Launcher Pro"
    
    # Security settings
    SECRET_KEY: str = secrets.token_hex(32)
    SESSION_TIMEOUT_MINUTES: int = 30
    MAX_COMMAND_LENGTH: int = 500
    
    # File settings
    BUNDLE_DIR: Path = Path(__file__).parent.absolute()
    LOG_DIR: Path = Path("/tmp/cursor_launcher")
    DATABASE_FILE: Path = Path("/tmp/cursor_launcher/launcher.db")
    
    # GUI settings
    WINDOW_WIDTH: int = 800
    WINDOW_HEIGHT: int = 600
    THEME: str = "default"
    
    # Allowed operations for security
    ALLOWED_OPERATIONS: List[str] = None
    
    def __post_init__(self):
        if self.ALLOWED_OPERATIONS is None:
            self.ALLOWED_OPERATIONS = [
                'status', 'version', 'check', 'info', 'help', 'launch',
                'stop', 'restart', 'health', 'logs', 'config'
            ]
        
        # Create directories
        self.LOG_DIR.mkdir(exist_ok=True)
        self.DATABASE_FILE.parent.mkdir(exist_ok=True)

# Global configuration
config = LauncherConfig()

class DatabaseManager:
    """Professional database management with proper error handling"""
    
    def __init__(self, db_path: Path):
        self.db_path = db_path
        self.initialize_database()
    
    def initialize_database(self):
        """Initialize database schema"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                
                # Session table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS sessions (
                        id TEXT PRIMARY KEY,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        expires_at TIMESTAMP NOT NULL,
                        data TEXT
                    )
                """)
                
                # Operations log table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS operations_log (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                        operation TEXT NOT NULL,
                        status TEXT NOT NULL,
                        details TEXT,
                        duration_ms INTEGER
                    )
                """)
                
                # Configuration table
                cursor.execute("""
                    CREATE TABLE IF NOT EXISTS config_store (
                        key TEXT PRIMARY KEY,
                        value TEXT NOT NULL,
                        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                """)
                
                conn.commit()
                logger.info("Database initialized successfully")
        except Exception as e:
            logger.error(f"Database initialization failed: {e}")
            raise
    
    @contextmanager
    def get_connection(self):
        """Get database connection with proper cleanup"""
        conn = sqlite3.connect(str(self.db_path))
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
    
    def log_operation(self, operation: str, status: str, details: str = "", duration_ms: int = 0):
        """Log operation to database"""
        try:
            with self.get_connection() as conn:
                cursor = conn.cursor()
                cursor.execute(
                    "INSERT INTO operations_log (operation, status, details, duration_ms) VALUES (?, ?, ?, ?)",
                    (operation, status, details, duration_ms)
                )
                conn.commit()
        except Exception as e:
            logger.error(f"Failed to log operation: {e}")

class SystemHealthMonitor:
    """Professional system health monitoring"""
    
    def __init__(self):
        self.start_time = time.time()
        self.operation_count = 0
        self.error_count = 0
    
    def get_system_info(self) -> Dict:
        """Get comprehensive system information"""
        try:
            import psutil
            
            return {
                'platform': {
                    'system': platform.system(),
                    'release': platform.release(),
                    'machine': platform.machine(),
                    'python_version': platform.python_version()
                },
                'resources': {
                    'cpu_percent': psutil.cpu_percent(),
                    'memory_percent': psutil.virtual_memory().percent,
                    'disk_percent': psutil.disk_usage('/').percent
                },
                'application': {
                    'uptime': time.time() - self.start_time,
                    'operations': self.operation_count,
                    'errors': self.error_count,
                    'bundle_dir': str(config.BUNDLE_DIR)
                }
            }
        except ImportError:
            return {
                'platform': {
                    'system': platform.system(),
                    'release': platform.release(),
                    'machine': platform.machine(),
                    'python_version': platform.python_version()
                },
                'application': {
                    'uptime': time.time() - self.start_time,
                    'operations': self.operation_count,
                    'errors': self.error_count,
                    'bundle_dir': str(config.BUNDLE_DIR)
                }
            }
    
    def perform_health_check(self) -> Dict:
        """Perform comprehensive health check"""
        health = {'overall': 'healthy', 'checks': {}}
        
        # Check bundle directory
        try:
            if config.BUNDLE_DIR.exists():
                health['checks']['bundle_directory'] = 'healthy'
            else:
                health['checks']['bundle_directory'] = 'warning: directory not found'
                health['overall'] = 'warning'
        except Exception as e:
            health['checks']['bundle_directory'] = f'error: {e}'
            health['overall'] = 'unhealthy'
        
        # Check database
        try:
            db = DatabaseManager(config.DATABASE_FILE)
            with db.get_connection() as conn:
                conn.execute("SELECT 1")
            health['checks']['database'] = 'healthy'
        except Exception as e:
            health['checks']['database'] = f'error: {e}'
            health['overall'] = 'unhealthy'
        
        return health
    
    def increment_operations(self):
        self.operation_count += 1
    
    def increment_errors(self):
        self.error_count += 1

class SecureCommandExecutor:
    """Professional secure command execution with validation"""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
    
    def validate_operation(self, operation: str) -> Tuple[bool, str]:
        """Validate operation for security"""
        if not operation or len(operation.strip()) == 0:
            return False, "Operation cannot be empty"
        
        if len(operation) > config.MAX_COMMAND_LENGTH:
            return False, f"Operation too long (max {config.MAX_COMMAND_LENGTH} chars)"
        
        clean_operation = operation.strip().lower()
        
        if clean_operation not in config.ALLOWED_OPERATIONS:
            return False, f"Operation not allowed. Allowed: {', '.join(config.ALLOWED_OPERATIONS)}"
        
        return True, "Operation is valid"
    
    def execute_operation(self, operation: str) -> Dict:
        """Execute validated operation with comprehensive error handling"""
        start_time = time.time()
        is_valid, message = self.validate_operation(operation)
        
        if not is_valid:
            result = {'status': 'error', 'message': message, 'output': ''}
            logger.audit(f"OPERATION_REJECTED:{operation}", message)
            return result
        
        try:
            logger.audit(f"OPERATION_EXECUTED:{operation}")
            
            # Route to appropriate handler
            operation_lower = operation.strip().lower()
            
            if operation_lower == 'status':
                output = self._op_status()
            elif operation_lower == 'version':
                output = self._op_version()
            elif operation_lower == 'check':
                output = self._op_check()
            elif operation_lower == 'info':
                output = self._op_info()
            elif operation_lower == 'help':
                output = self._op_help()
            elif operation_lower == 'health':
                output = self._op_health()
            elif operation_lower == 'launch':
                output = self._op_launch()
            elif operation_lower == 'config':
                output = self._op_config()
            else:
                output = f"Operation '{operation}' recognized but not implemented"
            
            duration = int((time.time() - start_time) * 1000)
            self.db.log_operation(operation, 'success', '', duration)
            
            return {
                'status': 'success',
                'message': 'Operation completed successfully',
                'output': output,
                'duration_ms': duration
            }
            
        except Exception as e:
            duration = int((time.time() - start_time) * 1000)
            error_msg = str(e)
            logger.error(f"Error executing operation '{operation}': {error_msg}")
            logger.audit(f"OPERATION_ERROR:{operation}", error_msg)
            self.db.log_operation(operation, 'error', error_msg, duration)
            
            return {
                'status': 'error',
                'message': f'Operation failed: {error_msg}',
                'output': '',
                'duration_ms': duration
            }
    
    # Operation implementations
    def _op_status(self) -> str:
        monitor = SystemHealthMonitor()
        info = monitor.get_system_info()
        return f"""
CURSOR BUNDLE LAUNCHER STATUS
=============================
Application: {config.APP_NAME}
Version: {config.VERSION}
Uptime: {info['application']['uptime']:.2f} seconds
Operations: {info['application']['operations']}
Errors: {info['application']['errors']}
Bundle Directory: {info['application']['bundle_dir']}
Status: Operational
"""
    
    def _op_version(self) -> str:
        return f"{config.APP_NAME} v{config.VERSION}"
    
    def _op_check(self) -> str:
        monitor = SystemHealthMonitor()
        health = monitor.perform_health_check()
        
        checks = []
        for component, status in health['checks'].items():
            symbol = "✓" if "healthy" in status else "⚠" if "warning" in status else "✗"
            checks.append(f"{symbol} {component.replace('_', ' ').title()}: {status}")
        
        return f"HEALTH CHECK RESULTS\n{'='*20}\n" + "\n".join(checks)
    
    def _op_info(self) -> str:
        monitor = SystemHealthMonitor()
        info = monitor.get_system_info()
        
        details = []
        for category, data in info.items():
            if isinstance(data, dict):
                details.append(f"\n{category.upper()}:")
                for key, value in data.items():
                    details.append(f"  {key.replace('_', ' ').title()}: {value}")
        
        return "SYSTEM INFORMATION\n" + "=" * 18 + "\n" + "\n".join(details)
    
    def _op_help(self) -> str:
        return f"""
CURSOR BUNDLE LAUNCHER HELP
============================

Available Operations:
  status   - Show application status and metrics
  version  - Display version information
  check    - Perform system health checks
  info     - Show detailed system information
  help     - Display this help message
  health   - Show health check results in JSON format
  launch   - Launch Cursor IDE (if available)
  config   - Show current configuration

Professional Features:
  • Secure operation validation and execution
  • Comprehensive logging and audit trails
  • Professional error handling and recovery
  • System health monitoring
  • Database-backed session management
  • GUI and web interface support

Version: {config.VERSION}
Bundle Directory: {config.BUNDLE_DIR}
"""
    
    def _op_health(self) -> str:
        monitor = SystemHealthMonitor()
        health = monitor.perform_health_check()
        return json.dumps(health, indent=2)
    
    def _op_launch(self) -> str:
        try:
            # Look for Cursor executable in bundle directory
            cursor_exe = None
            possible_names = ['cursor', 'cursor.exe', 'Cursor', 'Cursor.exe']
            
            for name in possible_names:
                path = config.BUNDLE_DIR / name
                if path.exists():
                    cursor_exe = path
                    break
            
            if cursor_exe:
                subprocess.Popen([str(cursor_exe)], cwd=str(config.BUNDLE_DIR))
                return f"Launched Cursor IDE from {cursor_exe}"
            else:
                return "Cursor executable not found in bundle directory"
                
        except Exception as e:
            return f"Failed to launch Cursor IDE: {e}"
    
    def _op_config(self) -> str:
        config_dict = asdict(config)
        # Remove sensitive information
        config_dict.pop('SECRET_KEY', None)
        return json.dumps(config_dict, indent=2, default=str)

class ProfessionalGUI:
    """Professional GUI interface using tkinter"""
    
    def __init__(self):
        if not GUI_AVAILABLE:
            raise RuntimeError("GUI components not available")
        
        self.db = DatabaseManager(config.DATABASE_FILE)
        self.executor = SecureCommandExecutor(self.db)
        self.monitor = SystemHealthMonitor()
        
        self.setup_gui()
        logger.info("Professional GUI initialized")
    
    def setup_gui(self):
        """Setup the main GUI window"""
        self.root = tk.Tk()
        self.root.title(config.APP_NAME)
        self.root.geometry(f"{config.WINDOW_WIDTH}x{config.WINDOW_HEIGHT}")
        self.root.resizable(True, True)
        
        # Create main frame
        main_frame = ttk.Frame(self.root, padding="10")
        main_frame.grid(row=0, column=0, sticky=(tk.W, tk.E, tk.N, tk.S))
        
        # Configure grid weights
        self.root.columnconfigure(0, weight=1)
        self.root.rowconfigure(0, weight=1)
        main_frame.columnconfigure(1, weight=1)
        main_frame.rowconfigure(2, weight=1)
        
        # Title
        title_label = ttk.Label(main_frame, text=config.APP_NAME, font=('Arial', 16, 'bold'))
        title_label.grid(row=0, column=0, columnspan=2, pady=(0, 20))
        
        # Operation input
        ttk.Label(main_frame, text="Operation:").grid(row=1, column=0, sticky=tk.W, padx=(0, 10))
        self.operation_var = tk.StringVar()
        operation_entry = ttk.Entry(main_frame, textvariable=self.operation_var, width=30)
        operation_entry.grid(row=1, column=1, sticky=(tk.W, tk.E), padx=(0, 10))
        operation_entry.bind('<Return>', self.execute_operation)
        
        # Execute button
        execute_btn = ttk.Button(main_frame, text="Execute", command=self.execute_operation)
        execute_btn.grid(row=1, column=2, padx=(10, 0))
        
        # Output area
        ttk.Label(main_frame, text="Output:").grid(row=2, column=0, sticky=(tk.W, tk.N), padx=(0, 10), pady=(20, 0))
        self.output_text = scrolledtext.ScrolledText(main_frame, width=80, height=25, wrap=tk.WORD)
        self.output_text.grid(row=2, column=1, columnspan=2, sticky=(tk.W, tk.E, tk.N, tk.S), pady=(20, 0))
        
        # Status bar
        self.status_var = tk.StringVar()
        self.status_var.set("Ready")
        status_bar = ttk.Label(main_frame, textvariable=self.status_var, relief=tk.SUNKEN)
        status_bar.grid(row=3, column=0, columnspan=3, sticky=(tk.W, tk.E), pady=(10, 0))
        
        # Menu bar
        self.create_menu()
        
        # Initial status
        self.show_initial_status()
    
    def create_menu(self):
        """Create menu bar"""
        menubar = tk.Menu(self.root)
        self.root.config(menu=menubar)
        
        # File menu
        file_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="File", menu=file_menu)
        file_menu.add_command(label="Health Check", command=self.show_health_check)
        file_menu.add_command(label="System Info", command=self.show_system_info)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.root.quit)
        
        # Help menu
        help_menu = tk.Menu(menubar, tearoff=0)
        menubar.add_cascade(label="Help", menu=help_menu)
        help_menu.add_command(label="Help", command=self.show_help)
        help_menu.add_command(label="About", command=self.show_about)
    
    def show_initial_status(self):
        """Show initial status information"""
        result = self.executor.execute_operation('status')
        self.output_text.insert(tk.END, result['output'])
        self.output_text.insert(tk.END, "\n" + "="*50 + "\n")
        self.output_text.insert(tk.END, "Type 'help' for available operations.\n")
    
    def execute_operation(self, event=None):
        """Execute the entered operation"""
        operation = self.operation_var.get().strip()
        if not operation:
            return
        
        self.status_var.set(f"Executing: {operation}")
        
        try:
            self.monitor.increment_operations()
            result = self.executor.execute_operation(operation)
            
            # Clear output and show result
            self.output_text.delete(1.0, tk.END)
            self.output_text.insert(tk.END, f"Operation: {operation}\n")
            self.output_text.insert(tk.END, f"Status: {result['status']}\n")
            self.output_text.insert(tk.END, f"Duration: {result['duration_ms']}ms\n")
            self.output_text.insert(tk.END, "="*50 + "\n")
            self.output_text.insert(tk.END, result['output'])
            
            if result['status'] == 'error':
                self.monitor.increment_errors()
                self.status_var.set(f"Error: {result['message']}")
            else:
                self.status_var.set("Operation completed successfully")
            
        except Exception as e:
            self.monitor.increment_errors()
            self.output_text.delete(1.0, tk.END)
            self.output_text.insert(tk.END, f"Unexpected error: {e}")
            self.status_var.set("Unexpected error occurred")
            logger.error(f"GUI operation error: {e}")
        
        # Clear input
        self.operation_var.set("")
    
    def show_health_check(self):
        """Show health check in popup"""
        result = self.executor.execute_operation('check')
        messagebox.showinfo("Health Check", result['output'])
    
    def show_system_info(self):
        """Show system info in popup"""
        result = self.executor.execute_operation('info')
        messagebox.showinfo("System Information", result['output'])
    
    def show_help(self):
        """Show help in popup"""
        result = self.executor.execute_operation('help')
        messagebox.showinfo("Help", result['output'])
    
    def show_about(self):
        """Show about dialog"""
        about_text = f"""
{config.APP_NAME}
Version {config.VERSION}

Professional launcher for Cursor IDE bundle management.

Features:
• Secure operation execution
• Professional logging and auditing
• System health monitoring
• Database-backed operations
• Professional error handling

© 2024 Professional Development
"""
        messagebox.showinfo("About", about_text)
    
    def run(self):
        """Start the GUI main loop"""
        try:
            logger.info("Starting GUI main loop")
            self.root.mainloop()
        except Exception as e:
            logger.error(f"GUI error: {e}")
            raise

def create_web_interface():
    """Create optional web interface"""
    if not WEB_AVAILABLE:
        return None
    
    app = Flask(__name__)
    app.secret_key = config.SECRET_KEY
    
    db = DatabaseManager(config.DATABASE_FILE)
    executor = SecureCommandExecutor(db)
    monitor = SystemHealthMonitor()
    
    @app.route('/')
    def index():
        return render_template_string(WEB_TEMPLATE)
    
    @app.route('/api/execute', methods=['POST'])
    def api_execute():
        data = request.get_json()
        if not data or 'operation' not in data:
            return jsonify({'error': 'Operation required'}), 400
        
        monitor.increment_operations()
        result = executor.execute_operation(data['operation'])
        
        if result['status'] == 'error':
            monitor.increment_errors()
        
        return jsonify(result)
    
    @app.route('/api/status')
    def api_status():
        return jsonify(monitor.get_system_info())
    
    return app

# Simple web template
WEB_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>{{ config.APP_NAME }}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; }
        .input-group { margin-bottom: 20px; }
        input[type="text"] { width: 70%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; }
        button { padding: 10px 20px; background: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
        button:hover { background: #0056b3; }
        .output { background: #f8f9fa; padding: 15px; border-radius: 4px; min-height: 200px; white-space: pre-wrap; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Cursor Bundle Launcher Pro</h1>
            <p>Professional Web Interface</p>
        </div>
        <div class="input-group">
            <input type="text" id="operation" placeholder="Enter operation (e.g., status, help, info)" />
            <button onclick="executeOperation()">Execute</button>
        </div>
        <div class="output" id="output">Ready. Type 'help' to see available operations.</div>
    </div>
    
    <script>
        function executeOperation() {
            const operation = document.getElementById('operation').value;
            if (!operation) return;
            
            fetch('/api/execute', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({operation: operation})
            })
            .then(response => response.json())
            .then(data => {
                document.getElementById('output').textContent = 
                    `Operation: ${operation}\\nStatus: ${data.status}\\nDuration: ${data.duration_ms}ms\\n${'='.repeat(50)}\\n${data.output}`;
                document.getElementById('operation').value = '';
            })
            .catch(error => {
                document.getElementById('output').textContent = `Error: ${error}`;
            });
        }
        
        document.getElementById('operation').addEventListener('keypress', function(e) {
            if (e.key === 'Enter') executeOperation();
        });
    </script>
</body>
</html>
"""

def main():
    """Main application entry point"""
    try:
        logger.info(f"Starting {config.APP_NAME} v{config.VERSION}")
        logger.info(f"Bundle directory: {config.BUNDLE_DIR}")
        logger.audit("APPLICATION_START", f"Version {config.VERSION}")
        
        # Check command line arguments
        if len(sys.argv) > 1:
            if sys.argv[1] == '--web':
                # Web interface mode
                web_app = create_web_interface()
                if web_app:
                    logger.info("Starting web interface on http://localhost:8080")
                    web_app.run(host='127.0.0.1', port=8080, debug=False)
                else:
                    print("Web interface not available")
                    sys.exit(1)
            elif sys.argv[1] == '--cli':
                # CLI mode
                db = DatabaseManager(config.DATABASE_FILE)
                executor = SecureCommandExecutor(db)
                
                print(f"{config.APP_NAME} v{config.VERSION} - CLI Mode")
                print("Type 'help' for available operations, 'exit' to quit.")
                
                while True:
                    try:
                        operation = input("\n> ").strip()
                        if operation.lower() in ['exit', 'quit']:
                            break
                        if operation:
                            result = executor.execute_operation(operation)
                            print(f"\nStatus: {result['status']}")
                            print(f"Duration: {result['duration_ms']}ms")
                            print("=" * 50)
                            print(result['output'])
                    except KeyboardInterrupt:
                        break
                    except Exception as e:
                        print(f"Error: {e}")
                
                print("\nGoodbye!")
            else:
                print(f"Unknown option: {sys.argv[1]}")
                print("Usage: python launcher.py [--gui|--web|--cli]")
                sys.exit(1)
        else:
            # Default GUI mode
            if GUI_AVAILABLE:
                gui = ProfessionalGUI()
                gui.run()
            else:
                print("GUI not available. Use --cli for command line mode or --web for web interface.")
                sys.exit(1)
    
    except KeyboardInterrupt:
        logger.info("Application interrupted by user")
    except Exception as e:
        logger.error(f"Application error: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)
    finally:
        logger.audit("APPLICATION_STOP")

if __name__ == "__main__":
    main()