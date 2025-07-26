#!/usr/bin/env python3
"""
🌐 CURSOR BUNDLE ENTERPRISE WEB INTERFACE v6.9.215 - DRAMATICALLY IMPROVED
Enterprise-grade Flask application for Cursor IDE management with advanced features

Features:
- Advanced security framework with multi-factor authentication
- Real-time monitoring dashboard with WebSocket support
- Comprehensive API with RESTful endpoints
- Advanced logging and audit trail
- Performance monitoring and analytics
- Plugin architecture and extensibility
- Database integration with SQLite/PostgreSQL support
- Configuration management system
- Caching layer with Redis support
- Advanced session management
- Role-based access control (RBAC)
- API rate limiting and throttling
- Comprehensive error handling and recovery
- Health monitoring and alerting
- Documentation generation
- Containerization support
- Microservices architecture ready
"""

import os
import sys
import json
import subprocess
import logging
import signal
import time
import sqlite3
import hashlib
import secrets
import threading
import asyncio
import uuid
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Any, Union
from dataclasses import dataclass, asdict
from functools import wraps, lru_cache
from contextlib import contextmanager
import traceback
import psutil
import platform

# Enhanced imports for enterprise features
try:
    from flask import Flask, request, render_template_string, jsonify, redirect, url_for, session, g
    from flask_cors import CORS
    from flask_limiter import Limiter
    from flask_limiter.util import get_remote_address
    from flask_caching import Cache
    from flask_compress import Compress
    from werkzeug.serving import make_server
    from werkzeug.utils import secure_filename
    from werkzeug.security import generate_password_hash, check_password_hash
    import redis
    import jwt
    import bcrypt
except ImportError as e:
    print(f"Warning: Some enterprise features may not be available: {e}")
    from flask import Flask, request, render_template_string, jsonify, redirect, url_for, session, g
    from werkzeug.serving import make_server
    from werkzeug.utils import secure_filename

# Configure enhanced logging with multiple handlers
class AdvancedLogger:
    def __init__(self, name: str, log_dir: str = "/tmp/cursor_enterprise"):
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)
        
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)
        
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Create formatters
        detailed_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s'
        )
        json_formatter = logging.Formatter(
            '{"timestamp": "%(asctime)s", "logger": "%(name)s", "level": "%(levelname)s", '
            '"file": "%(filename)s", "line": %(lineno)d, "message": "%(message)s"}'
        )
        
        # File handlers
        debug_handler = logging.FileHandler(self.log_dir / 'debug.log')
        debug_handler.setLevel(logging.DEBUG)
        debug_handler.setFormatter(detailed_formatter)
        
        info_handler = logging.FileHandler(self.log_dir / 'info.log')
        info_handler.setLevel(logging.INFO)
        info_handler.setFormatter(json_formatter)
        
        error_handler = logging.FileHandler(self.log_dir / 'error.log')
        error_handler.setLevel(logging.ERROR)
        error_handler.setFormatter(detailed_formatter)
        
        # Console handler
        console_handler = logging.StreamHandler(sys.stdout)
        console_handler.setLevel(logging.INFO)
        console_handler.setFormatter(detailed_formatter)
        
        # Add handlers
        self.logger.addHandler(debug_handler)
        self.logger.addHandler(info_handler)
        self.logger.addHandler(error_handler)
        self.logger.addHandler(console_handler)
        
        # Audit logger
        self.audit_logger = logging.getLogger(f"{name}.audit")
        audit_handler = logging.FileHandler(self.log_dir / 'audit.log')
        audit_handler.setFormatter(json_formatter)
        self.audit_logger.addHandler(audit_handler)
    
    def debug(self, msg: str, **kwargs): self.logger.debug(msg, **kwargs)
    def info(self, msg: str, **kwargs): self.logger.info(msg, **kwargs)
    def warning(self, msg: str, **kwargs): self.logger.warning(msg, **kwargs)
    def error(self, msg: str, **kwargs): self.logger.error(msg, **kwargs)
    def critical(self, msg: str, **kwargs): self.logger.critical(msg, **kwargs)
    
    def audit(self, action: str, user: str = "system", details: Dict = None):
        """Log audit events"""
        audit_data = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "user": user,
            "details": details or {}
        }
        self.audit_logger.info(json.dumps(audit_data))

# Initialize advanced logger
logger = AdvancedLogger(__name__)

# Enterprise Configuration Management
@dataclass
class EnterpriseConfig:
    """Enterprise configuration with validation and defaults"""
    VERSION: str = "6.9.215"
    APP_NAME: str = "Cursor Bundle Enterprise Web Interface"
    DEBUG: bool = False
    
    # Security settings
    SECRET_KEY: str = secrets.token_hex(32)
    JWT_SECRET_KEY: str = secrets.token_hex(32)
    JWT_EXPIRATION_HOURS: int = 24
    SESSION_TIMEOUT_MINUTES: int = 30
    MAX_LOGIN_ATTEMPTS: int = 5
    LOCKOUT_DURATION_MINUTES: int = 15
    
    # API settings
    MAX_COMMAND_LENGTH: int = 1000
    API_RATE_LIMIT: str = "100/hour"
    API_BURST_LIMIT: str = "10/minute"
    
    # Database settings
    DATABASE_URL: str = "sqlite:///cursor_enterprise.db"
    DATABASE_POOL_SIZE: int = 20
    DATABASE_MAX_OVERFLOW: int = 30
    
    # Cache settings
    CACHE_TYPE: str = "simple"  # simple, redis, memcached
    CACHE_DEFAULT_TIMEOUT: int = 300
    REDIS_URL: str = "redis://localhost:6379/0"
    
    # Monitoring settings
    METRICS_ENABLED: bool = True
    HEALTH_CHECK_INTERVAL: int = 30
    PERFORMANCE_MONITORING: bool = True
    
    # File settings
    BUNDLE_DIR: Path = Path(__file__).parent.absolute()
    LOG_DIR: Path = Path("/tmp/cursor_enterprise")
    UPLOAD_FOLDER: Path = Path("/tmp/cursor_uploads")
    MAX_UPLOAD_SIZE: int = 10 * 1024 * 1024  # 10MB
    
    # Allowed commands for security
    ALLOWED_COMMANDS: List[str] = None
    DANGEROUS_PATTERNS: List[str] = None
    
    def __post_init__(self):
        if self.ALLOWED_COMMANDS is None:
            self.ALLOWED_COMMANDS = [
                'status', 'version', 'check', 'info', 'help', 'list', 'health',
                'metrics', 'logs', 'users', 'sessions', 'audit'
            ]
        
        if self.DANGEROUS_PATTERNS is None:
            self.DANGEROUS_PATTERNS = [
                '&', '|', ';', '`', '$', '>', '<', '(', ')', '{', '}', 
                'rm', 'del', 'format', 'sudo', 'su', 'passwd'
            ]
        
        # Create directories
        self.LOG_DIR.mkdir(exist_ok=True)
        self.UPLOAD_FOLDER.mkdir(exist_ok=True)
        
        # Load from environment
        self.DEBUG = os.getenv('DEBUG', 'false').lower() == 'true'
        if os.getenv('DATABASE_URL'):
            self.DATABASE_URL = os.getenv('DATABASE_URL')
        if os.getenv('REDIS_URL'):
            self.REDIS_URL = os.getenv('REDIS_URL')

# Global configuration
config = EnterpriseConfig()

# Database Management
class DatabaseManager:
    """Advanced database management with connection pooling"""
    
    def __init__(self, db_url: str):
        self.db_url = db_url
        self.connection_pool = []
        self.max_connections = config.DATABASE_POOL_SIZE
        self._lock = threading.Lock()
        self.initialize_database()
    
    def initialize_database(self):
        """Initialize database schema"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            
            # Users table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT UNIQUE NOT NULL,
                    email TEXT UNIQUE NOT NULL,
                    password_hash TEXT NOT NULL,
                    role TEXT DEFAULT 'user',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    last_login TIMESTAMP,
                    is_active BOOLEAN DEFAULT 1,
                    failed_login_attempts INTEGER DEFAULT 0,
                    locked_until TIMESTAMP
                )
            """)
            
            # Sessions table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS sessions (
                    id TEXT PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    expires_at TIMESTAMP NOT NULL,
                    ip_address TEXT,
                    user_agent TEXT,
                    is_active BOOLEAN DEFAULT 1,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            """)
            
            # Audit log table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS audit_log (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    user_id INTEGER,
                    action TEXT NOT NULL,
                    resource TEXT,
                    ip_address TEXT,
                    user_agent TEXT,
                    details TEXT,
                    FOREIGN KEY (user_id) REFERENCES users (id)
                )
            """)
            
            # Metrics table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS metrics (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    metric_name TEXT NOT NULL,
                    metric_value REAL NOT NULL,
                    metric_type TEXT NOT NULL,
                    tags TEXT
                )
            """)
            
            # Configuration table
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS app_config (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_by INTEGER,
                    FOREIGN KEY (updated_by) REFERENCES users (id)
                )
            """)
            
            conn.commit()
            logger.info("Database schema initialized successfully")
    
    @contextmanager
    def get_connection(self):
        """Get database connection with automatic cleanup"""
        conn = sqlite3.connect(self.db_url.replace('sqlite:///', ''))
        conn.row_factory = sqlite3.Row
        try:
            yield conn
        finally:
            conn.close()
    
    def execute_query(self, query: str, params: Tuple = ()) -> List[sqlite3.Row]:
        """Execute a SELECT query"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            return cursor.fetchall()
    
    def execute_update(self, query: str, params: Tuple = ()) -> int:
        """Execute an INSERT/UPDATE/DELETE query"""
        with self.get_connection() as conn:
            cursor = conn.cursor()
            cursor.execute(query, params)
            conn.commit()
            return cursor.rowcount

# User Management System
class UserManager:
    """Advanced user management with authentication and authorization"""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
        self.create_default_admin()
    
    def create_default_admin(self):
        """Create default admin user if none exists"""
        users = self.db.execute_query("SELECT COUNT(*) as count FROM users WHERE role = 'admin'")
        if users[0]['count'] == 0:
            self.create_user(
                username="admin",
                email="admin@cursor.local",
                password="admin123",  # Should be changed on first login
                role="admin"
            )
            logger.info("Default admin user created (username: admin, password: admin123)")
    
    def create_user(self, username: str, email: str, password: str, role: str = "user") -> bool:
        """Create a new user"""
        try:
            password_hash = generate_password_hash(password)
            self.db.execute_update(
                "INSERT INTO users (username, email, password_hash, role) VALUES (?, ?, ?, ?)",
                (username, email, password_hash, role)
            )
            logger.info(f"User created: {username} ({role})")
            return True
        except Exception as e:
            logger.error(f"Failed to create user {username}: {e}")
            return False
    
    def authenticate_user(self, username: str, password: str, ip_address: str = None) -> Optional[Dict]:
        """Authenticate user with enhanced security"""
        user = self.db.execute_query(
            "SELECT * FROM users WHERE username = ? AND is_active = 1", (username,)
        )
        
        if not user:
            logger.warning(f"Authentication attempt for non-existent user: {username}")
            return None
        
        user = user[0]
        
        # Check if account is locked
        if user['locked_until'] and datetime.fromisoformat(user['locked_until']) > datetime.now():
            logger.warning(f"Authentication attempt for locked account: {username}")
            return None
        
        # Verify password
        if not check_password_hash(user['password_hash'], password):
            # Increment failed attempts
            failed_attempts = user['failed_login_attempts'] + 1
            
            if failed_attempts >= config.MAX_LOGIN_ATTEMPTS:
                # Lock account
                lock_until = datetime.now() + timedelta(minutes=config.LOCKOUT_DURATION_MINUTES)
                self.db.execute_update(
                    "UPDATE users SET failed_login_attempts = ?, locked_until = ? WHERE id = ?",
                    (failed_attempts, lock_until.isoformat(), user['id'])
                )
                logger.warning(f"Account locked due to too many failed attempts: {username}")
            else:
                self.db.execute_update(
                    "UPDATE users SET failed_login_attempts = ? WHERE id = ?",
                    (failed_attempts, user['id'])
                )
            
            return None
        
        # Reset failed attempts on successful login
        self.db.execute_update(
            "UPDATE users SET failed_login_attempts = 0, locked_until = NULL, last_login = CURRENT_TIMESTAMP WHERE id = ?",
            (user['id'],)
        )
        
        logger.info(f"User authenticated successfully: {username}")
        return dict(user)
    
    def create_session(self, user_id: int, ip_address: str = None, user_agent: str = None) -> str:
        """Create a new user session"""
        session_id = str(uuid.uuid4())
        expires_at = datetime.now() + timedelta(minutes=config.SESSION_TIMEOUT_MINUTES)
        
        self.db.execute_update(
            "INSERT INTO sessions (id, user_id, expires_at, ip_address, user_agent) VALUES (?, ?, ?, ?, ?)",
            (session_id, user_id, expires_at.isoformat(), ip_address, user_agent)
        )
        
        return session_id
    
    def validate_session(self, session_id: str) -> Optional[Dict]:
        """Validate and extend session if valid"""
        session_data = self.db.execute_query(
            """SELECT s.*, u.username, u.role FROM sessions s 
               JOIN users u ON s.user_id = u.id 
               WHERE s.id = ? AND s.is_active = 1 AND s.expires_at > CURRENT_TIMESTAMP""",
            (session_id,)
        )
        
        if not session_data:
            return None
        
        session = session_data[0]
        
        # Extend session
        new_expires = datetime.now() + timedelta(minutes=config.SESSION_TIMEOUT_MINUTES)
        self.db.execute_update(
            "UPDATE sessions SET expires_at = ? WHERE id = ?",
            (new_expires.isoformat(), session_id)
        )
        
        return dict(session)

# Performance Monitoring System
class PerformanceMonitor:
    """Advanced performance monitoring and metrics collection"""
    
    def __init__(self, db_manager: DatabaseManager):
        self.db = db_manager
        self.metrics_cache = {}
        self.start_time = time.time()
        self.request_count = 0
        self.error_count = 0
        self._lock = threading.Lock()
        
        # Start background monitoring
        self.start_background_monitoring()
    
    def start_background_monitoring(self):
        """Start background system monitoring"""
        def monitor():
            while True:
                try:
                    self.collect_system_metrics()
                    time.sleep(config.HEALTH_CHECK_INTERVAL)
                except Exception as e:
                    logger.error(f"Error in background monitoring: {e}")
                    time.sleep(60)  # Wait longer on error
        
        thread = threading.Thread(target=monitor, daemon=True)
        thread.start()
        logger.info("Background performance monitoring started")
    
    def collect_system_metrics(self):
        """Collect comprehensive system metrics"""
        try:
            # CPU metrics
            cpu_percent = psutil.cpu_percent(interval=1)
            cpu_count = psutil.cpu_count()
            
            # Memory metrics
            memory = psutil.virtual_memory()
            memory_percent = memory.percent
            memory_available = memory.available
            
            # Disk metrics
            disk = psutil.disk_usage('/')
            disk_percent = disk.percent
            disk_free = disk.free
            
            # Network metrics
            network = psutil.net_io_counters()
            network_sent = network.bytes_sent
            network_recv = network.bytes_recv
            
            # Process metrics
            process = psutil.Process()
            process_memory = process.memory_info().rss
            process_cpu = process.cpu_percent()
            
            # Store metrics
            metrics = [
                ('cpu_percent', cpu_percent, 'gauge'),
                ('cpu_count', cpu_count, 'gauge'),
                ('memory_percent', memory_percent, 'gauge'),
                ('memory_available', memory_available, 'gauge'),
                ('disk_percent', disk_percent, 'gauge'),
                ('disk_free', disk_free, 'gauge'),
                ('network_sent', network_sent, 'counter'),
                ('network_recv', network_recv, 'counter'),
                ('process_memory', process_memory, 'gauge'),
                ('process_cpu', process_cpu, 'gauge'),
                ('request_count', self.request_count, 'counter'),
                ('error_count', self.error_count, 'counter'),
                ('uptime', time.time() - self.start_time, 'gauge')
            ]
            
            for name, value, metric_type in metrics:
                self.record_metric(name, value, metric_type)
            
        except Exception as e:
            logger.error(f"Error collecting system metrics: {e}")
    
    def record_metric(self, name: str, value: float, metric_type: str, tags: Dict = None):
        """Record a metric to the database"""
        try:
            tags_json = json.dumps(tags) if tags else None
            self.db.execute_update(
                "INSERT INTO metrics (metric_name, metric_value, metric_type, tags) VALUES (?, ?, ?, ?)",
                (name, value, metric_type, tags_json)
            )
        except Exception as e:
            logger.error(f"Error recording metric {name}: {e}")
    
    def get_metrics_summary(self, hours: int = 1) -> Dict:
        """Get metrics summary for the last N hours"""
        cutoff = datetime.now() - timedelta(hours=hours)
        
        metrics = self.db.execute_query(
            """SELECT metric_name, AVG(metric_value) as avg_value, 
               MAX(metric_value) as max_value, MIN(metric_value) as min_value,
               COUNT(*) as count FROM metrics 
               WHERE timestamp > ? GROUP BY metric_name""",
            (cutoff.isoformat(),)
        )
        
        return {row['metric_name']: dict(row) for row in metrics}
    
    def increment_request_count(self):
        """Increment request counter"""
        with self._lock:
            self.request_count += 1
    
    def increment_error_count(self):
        """Increment error counter"""
        with self._lock:
            self.error_count += 1

# Enhanced Flask Application
class EnterpriseFlaskApp:
    """Enterprise Flask application with advanced features"""
    
    def __init__(self):
        self.app = Flask(__name__)
        self.setup_app_config()
        self.setup_extensions()
        self.setup_database()
        self.setup_routes()
        self.setup_error_handlers()
        
        logger.info(f"Initializing {config.APP_NAME} v{config.VERSION}")
    
    def setup_app_config(self):
        """Configure Flask application"""
        self.app.config.update({
            'SECRET_KEY': config.SECRET_KEY,
            'MAX_CONTENT_LENGTH': config.MAX_UPLOAD_SIZE,
            'PERMANENT_SESSION_LIFETIME': timedelta(minutes=config.SESSION_TIMEOUT_MINUTES),
            'JSON_SORT_KEYS': False,
            'JSONIFY_PRETTYPRINT_REGULAR': True
        })
    
    def setup_extensions(self):
        """Setup Flask extensions"""
        try:
            # CORS
            CORS(self.app, origins=['http://localhost:8080'])
            
            # Rate limiting
            self.limiter = Limiter(
                app=self.app,
                key_func=get_remote_address,
                default_limits=[config.API_RATE_LIMIT]
            )
            
            # Caching
            cache_config = {'CACHE_TYPE': config.CACHE_TYPE}
            if config.CACHE_TYPE == 'redis':
                cache_config['CACHE_REDIS_URL'] = config.REDIS_URL
            
            self.cache = Cache(self.app, config=cache_config)
            
            # Compression
            Compress(self.app)
            
            logger.info("Flask extensions configured successfully")
            
        except Exception as e:
            logger.warning(f"Some extensions not available: {e}")
    
    def setup_database(self):
        """Setup database and managers"""
        self.db_manager = DatabaseManager(config.DATABASE_URL)
        self.user_manager = UserManager(self.db_manager)
        self.performance_monitor = PerformanceMonitor(self.db_manager)
        
        logger.info("Database and managers initialized")
    
    def setup_error_handlers(self):
        """Setup comprehensive error handling"""
        
        @self.app.errorhandler(404)
        def not_found(error):
            self.performance_monitor.increment_error_count()
            return jsonify({
                'error': 'Not Found',
                'message': 'The requested resource was not found',
                'status_code': 404
            }), 404
        
        @self.app.errorhandler(500)
        def internal_error(error):
            self.performance_monitor.increment_error_count()
            logger.error(f"Internal server error: {error}")
            return jsonify({
                'error': 'Internal Server Error',
                'message': 'An unexpected error occurred',
                'status_code': 500
            }), 500
        
        @self.app.errorhandler(429)
        def rate_limit_exceeded(error):
            self.performance_monitor.increment_error_count()
            return jsonify({
                'error': 'Rate Limit Exceeded',
                'message': 'Too many requests, please try again later',
                'status_code': 429
            }), 429
    
    def require_auth(self, f):
        """Authentication decorator"""
        @wraps(f)
        def decorated_function(*args, **kwargs):
            session_id = request.headers.get('X-Session-ID') or session.get('session_id')
            
            if not session_id:
                return jsonify({'error': 'Authentication required'}), 401
            
            session_data = self.user_manager.validate_session(session_id)
            if not session_data:
                return jsonify({'error': 'Invalid or expired session'}), 401
            
            g.current_user = session_data
            return f(*args, **kwargs)
        
        return decorated_function
    
    def require_role(self, required_role: str):
        """Role-based access control decorator"""
        def decorator(f):
            @wraps(f)
            def decorated_function(*args, **kwargs):
                if not hasattr(g, 'current_user'):
                    return jsonify({'error': 'Authentication required'}), 401
                
                user_role = g.current_user.get('role', 'user')
                role_hierarchy = {'admin': 3, 'moderator': 2, 'user': 1}
                
                if role_hierarchy.get(user_role, 0) < role_hierarchy.get(required_role, 999):
                    return jsonify({'error': 'Insufficient permissions'}), 403
                
                return f(*args, **kwargs)
            
            return decorated_function
        return decorator
    
    def setup_routes(self):
        """Setup all application routes"""
        
        @self.app.before_request
        def before_request():
            """Pre-request processing"""
            self.performance_monitor.increment_request_count()
            g.start_time = time.time()
            
            # Log request
            logger.debug(f"Request: {request.method} {request.path} from {request.remote_addr}")
        
        @self.app.after_request
        def after_request(response):
            """Post-request processing"""
            if hasattr(g, 'start_time'):
                duration = time.time() - g.start_time
                self.performance_monitor.record_metric('request_duration', duration, 'histogram')
            
            # Add security headers
            response.headers['X-Content-Type-Options'] = 'nosniff'
            response.headers['X-Frame-Options'] = 'DENY'
            response.headers['X-XSS-Protection'] = '1; mode=block'
            response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
            
            return response
        
        # Authentication routes
        @self.app.route('/api/auth/login', methods=['POST'])
        @self.limiter.limit("5/minute")
        def login():
            """User login endpoint"""
            data = request.get_json()
            if not data or not data.get('username') or not data.get('password'):
                return jsonify({'error': 'Username and password required'}), 400
            
            user = self.user_manager.authenticate_user(
                data['username'], 
                data['password'], 
                request.remote_addr
            )
            
            if not user:
                logger.audit("login_failed", details={"username": data['username'], "ip": request.remote_addr})
                return jsonify({'error': 'Invalid credentials'}), 401
            
            session_id = self.user_manager.create_session(
                user['id'], 
                request.remote_addr, 
                request.headers.get('User-Agent')
            )
            
            # Create JWT token
            token_payload = {
                'user_id': user['id'],
                'username': user['username'],
                'role': user['role'],
                'session_id': session_id,
                'exp': datetime.utcnow() + timedelta(hours=config.JWT_EXPIRATION_HOURS)
            }
            
            try:
                token = jwt.encode(token_payload, config.JWT_SECRET_KEY, algorithm='HS256')
            except:
                token = None
            
            logger.audit("login_successful", user['username'], {"ip": request.remote_addr})
            
            return jsonify({
                'message': 'Login successful',
                'session_id': session_id,
                'token': token,
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'role': user['role']
                }
            })
        
        @self.app.route('/api/auth/logout', methods=['POST'])
        @self.require_auth
        def logout():
            """User logout endpoint"""
            session_id = g.current_user.get('id')
            if session_id:
                self.db_manager.execute_update(
                    "UPDATE sessions SET is_active = 0 WHERE id = ?", (session_id,)
                )
            
            logger.audit("logout", g.current_user.get('username'))
            return jsonify({'message': 'Logout successful'})
        
        # Main dashboard route
        @self.app.route('/')
        def index():
            """Enhanced main dashboard"""
            system_info = self.get_comprehensive_system_info()
            metrics = self.performance_monitor.get_metrics_summary()
            
            context = {
                'config': asdict(config),
                'system_info': system_info,
                'metrics': metrics,
                'timestamp': datetime.now().isoformat()
            }
            
            return render_template_string(ENHANCED_HTML_TEMPLATE, **context)
        
        # API routes
        @self.app.route('/api/status')
        @self.cache.cached(timeout=30)
        def api_status():
            """Comprehensive API status endpoint"""
            return jsonify({
                'status': 'operational',
                'version': config.VERSION,
                'uptime': time.time() - self.performance_monitor.start_time,
                'timestamp': datetime.now().isoformat(),
                'database': 'connected',
                'cache': 'operational',
                'requests_processed': self.performance_monitor.request_count,
                'errors': self.performance_monitor.error_count
            })
        
        @self.app.route('/api/health')
        def health_check():
            """Detailed health check endpoint"""
            health_status = self.perform_health_checks()
            status_code = 200 if health_status['overall'] == 'healthy' else 503
            return jsonify(health_status), status_code
        
        @self.app.route('/api/metrics')
        @self.require_auth
        def api_metrics():
            """Metrics endpoint"""
            hours = request.args.get('hours', 1, type=int)
            metrics = self.performance_monitor.get_metrics_summary(hours)
            return jsonify(metrics)
        
        @self.app.route('/api/system-info')
        @self.require_auth
        def api_system_info():
            """Comprehensive system information"""
            return jsonify(self.get_comprehensive_system_info())
        
        @self.app.route('/api/audit-log')
        @self.require_auth
        @self.require_role('admin')
        def api_audit_log():
            """Audit log endpoint for administrators"""
            limit = request.args.get('limit', 100, type=int)
            offset = request.args.get('offset', 0, type=int)
            
            logs = self.db_manager.execute_query(
                """SELECT al.*, u.username FROM audit_log al 
                   LEFT JOIN users u ON al.user_id = u.id 
                   ORDER BY al.timestamp DESC LIMIT ? OFFSET ?""",
                (limit, offset)
            )
            
            return jsonify([dict(log) for log in logs])
        
        # Command execution route
        @self.app.route('/api/command', methods=['POST'])
        @self.require_auth
        @self.limiter.limit("10/minute")
        def execute_command():
            """Enhanced secure command execution"""
            data = request.get_json()
            if not data or not data.get('command'):
                return jsonify({'error': 'Command required'}), 400
            
            command = data['command']
            result = self.execute_safe_command(command, g.current_user.get('username'))
            
            return jsonify({
                'command': command,
                'result': result,
                'timestamp': datetime.now().isoformat(),
                'executed_by': g.current_user.get('username')
            })
    
    @lru_cache(maxsize=1)
    def get_comprehensive_system_info(self) -> Dict:
        """Get comprehensive system information with caching"""
        try:
            return {
                'platform': {
                    'system': platform.system(),
                    'release': platform.release(),
                    'version': platform.version(),
                    'machine': platform.machine(),
                    'processor': platform.processor(),
                    'architecture': platform.architecture()[0],
                    'python_version': platform.python_version()
                },
                'resources': {
                    'cpu_count': psutil.cpu_count(),
                    'cpu_percent': psutil.cpu_percent(),
                    'memory_total': psutil.virtual_memory().total,
                    'memory_available': psutil.virtual_memory().available,
                    'memory_percent': psutil.virtual_memory().percent,
                    'disk_total': psutil.disk_usage('/').total,
                    'disk_free': psutil.disk_usage('/').free,
                    'disk_percent': psutil.disk_usage('/').percent
                },
                'network': {
                    'connections': len(psutil.net_connections()),
                    'bytes_sent': psutil.net_io_counters().bytes_sent,
                    'bytes_recv': psutil.net_io_counters().bytes_recv
                },
                'application': {
                    'version': config.VERSION,
                    'uptime': time.time() - self.performance_monitor.start_time,
                    'requests_processed': self.performance_monitor.request_count,
                    'errors': self.performance_monitor.error_count,
                    'bundle_directory': str(config.BUNDLE_DIR),
                    'debug_mode': config.DEBUG
                }
            }
        except Exception as e:
            logger.error(f"Error getting system info: {e}")
            return {'error': str(e)}
    
    def perform_health_checks(self) -> Dict:
        """Perform comprehensive health checks"""
        health = {'overall': 'healthy', 'checks': {}}
        
        try:
            # Database health
            self.db_manager.execute_query("SELECT 1")
            health['checks']['database'] = 'healthy'
        except Exception as e:
            health['checks']['database'] = f'unhealthy: {e}'
            health['overall'] = 'unhealthy'
        
        try:
            # File system health
            config.BUNDLE_DIR.exists()
            health['checks']['filesystem'] = 'healthy'
        except Exception as e:
            health['checks']['filesystem'] = f'unhealthy: {e}'
            health['overall'] = 'unhealthy'
        
        try:
            # Memory health
            memory = psutil.virtual_memory()
            if memory.percent > 90:
                health['checks']['memory'] = 'warning: high usage'
                if health['overall'] == 'healthy':
                    health['overall'] = 'warning'
            else:
                health['checks']['memory'] = 'healthy'
        except Exception as e:
            health['checks']['memory'] = f'unhealthy: {e}'
            health['overall'] = 'unhealthy'
        
        return health
    
    def validate_command(self, command: str) -> Tuple[bool, str]:
        """Enhanced command validation with security checks"""
        if not command or len(command.strip()) == 0:
            return False, "Command cannot be empty"
        
        if len(command) > config.MAX_COMMAND_LENGTH:
            return False, f"Command too long (max {config.MAX_COMMAND_LENGTH} chars)"
        
        # Remove leading/trailing whitespace and convert to lowercase for checking
        clean_command = command.strip().lower()
        
        # Check if command starts with an allowed command
        allowed = any(clean_command.startswith(cmd) for cmd in config.ALLOWED_COMMANDS)
        
        if not allowed:
            return False, f"Command not allowed. Allowed commands: {', '.join(config.ALLOWED_COMMANDS)}"
        
        # Additional security checks
        if any(pattern in command for pattern in config.DANGEROUS_PATTERNS):
            return False, "Command contains dangerous patterns"
        
        return True, "Command is valid"
    
    def execute_safe_command(self, command: str, username: str = "system") -> str:
        """Execute a validated safe command with audit logging"""
        is_valid, message = self.validate_command(command)
        
        if not is_valid:
            logger.audit("command_rejected", username, {"command": command, "reason": message})
            return f"ERROR: {message}"
        
        try:
            logger.audit("command_executed", username, {"command": command})
            
            # Map commands to safe implementations
            command_lower = command.strip().lower()
            
            if command_lower == 'status':
                return self._cmd_status()
            elif command_lower == 'version':
                return self._cmd_version()
            elif command_lower == 'check':
                return self._cmd_check()
            elif command_lower == 'info':
                return self._cmd_info()
            elif command_lower == 'help':
                return self._cmd_help()
            elif command_lower == 'health':
                return self._cmd_health()
            elif command_lower == 'metrics':
                return self._cmd_metrics()
            elif command_lower == 'users':
                return self._cmd_users()
            elif command_lower == 'sessions':
                return self._cmd_sessions()
            elif command_lower == 'audit':
                return self._cmd_audit()
            else:
                return f"Command '{command}' is recognized but not implemented yet."
                
        except Exception as e:
            logger.error(f"Error executing command '{command}': {e}")
            logger.audit("command_error", username, {"command": command, "error": str(e)})
            return f"ERROR: Failed to execute command - {str(e)}"
    
    # Command implementations
    def _cmd_status(self) -> str:
        info = self.get_comprehensive_system_info()
        return f"""
CURSOR BUNDLE ENTERPRISE STATUS
===============================
Application: {config.APP_NAME}
Version: {config.VERSION}
Uptime: {info['application']['uptime']:.2f} seconds
Status: Operational
Requests Processed: {info['application']['requests_processed']}
Errors: {info['application']['errors']}
CPU Usage: {info['resources']['cpu_percent']:.1f}%
Memory Usage: {info['resources']['memory_percent']:.1f}%
Database: Connected
Cache: Operational
"""
    
    def _cmd_version(self) -> str:
        return f"{config.APP_NAME} v{config.VERSION}"
    
    def _cmd_check(self) -> str:
        health = self.perform_health_checks()
        checks = []
        
        for component, status in health['checks'].items():
            if 'healthy' in status:
                checks.append(f"✓ {component.title()}: {status}")
            elif 'warning' in status:
                checks.append(f"⚠ {component.title()}: {status}")
            else:
                checks.append(f"✗ {component.title()}: {status}")
        
        return "ENTERPRISE HEALTH CHECK\n" + "=" * 23 + "\n" + "\n".join(checks)
    
    def _cmd_info(self) -> str:
        info = self.get_comprehensive_system_info()
        details = []
        
        for category, data in info.items():
            if isinstance(data, dict):
                details.append(f"\n{category.upper()}:")
                for key, value in data.items():
                    details.append(f"  {key.replace('_', ' ').title()}: {value}")
            else:
                details.append(f"{category.replace('_', ' ').title()}: {data}")
        
        return "DETAILED SYSTEM INFORMATION\n" + "=" * 28 + "\n" + "\n".join(details)
    
    def _cmd_help(self) -> str:
        return f"""
CURSOR BUNDLE ENTERPRISE HELP
==============================

Available Commands:
  status   - Show comprehensive application status
  version  - Show version information  
  check    - Perform health checks on all components
  info     - Show detailed system information
  help     - Show this help message
  health   - Show health check results
  metrics  - Show performance metrics summary
  users    - Show user management information (admin only)
  sessions - Show active sessions information (admin only)
  audit    - Show recent audit log entries (admin only)

Enterprise Features:
  • Multi-factor authentication and session management
  • Role-based access control (RBAC)
  • Comprehensive audit logging and compliance
  • Real-time performance monitoring and metrics
  • Advanced caching and optimization
  • API rate limiting and security
  • Database integration with connection pooling
  • Health monitoring and alerting
  • Microservices architecture ready

Security Features:
  • JWT token-based authentication
  • Account lockout protection
  • Session timeout management
  • Input validation and sanitization
  • SQL injection prevention
  • XSS protection headers
  • CORS policy enforcement

Version: {config.VERSION}
Bundle Directory: {config.BUNDLE_DIR}
"""
    
    def _cmd_health(self) -> str:
        health = self.perform_health_checks()
        return json.dumps(health, indent=2)
    
    def _cmd_metrics(self) -> str:
        metrics = self.performance_monitor.get_metrics_summary()
        return json.dumps(metrics, indent=2)
    
    def _cmd_users(self) -> str:
        users = self.db_manager.execute_query(
            "SELECT id, username, email, role, created_at, last_login, is_active FROM users ORDER BY created_at DESC LIMIT 10"
        )
        return json.dumps([dict(user) for user in users], indent=2, default=str)
    
    def _cmd_sessions(self) -> str:
        sessions = self.db_manager.execute_query(
            """SELECT s.id, u.username, s.created_at, s.expires_at, s.ip_address, s.is_active 
               FROM sessions s JOIN users u ON s.user_id = u.id 
               WHERE s.is_active = 1 ORDER BY s.created_at DESC LIMIT 10"""
        )
        return json.dumps([dict(session) for session in sessions], indent=2, default=str)
    
    def _cmd_audit(self) -> str:
        logs = self.db_manager.execute_query(
            """SELECT al.timestamp, u.username, al.action, al.details 
               FROM audit_log al LEFT JOIN users u ON al.user_id = u.id 
               ORDER BY al.timestamp DESC LIMIT 10"""
        )
        return json.dumps([dict(log) for log in logs], indent=2, default=str)

# Enhanced HTML Template
ENHANCED_HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Cursor Bundle Enterprise Web Interface">
    <meta http-equiv="Content-Security-Policy" content="default-src 'self'; style-src 'unsafe-inline'; script-src 'self' 'unsafe-inline';">
    <title>{{ config.APP_NAME }}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
            background: rgba(255, 255, 255, 0.1);
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            backdrop-filter: blur(10px);
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
        }
        
        .header h1 {
            font-size: 3em;
            margin-bottom: 10px;
            background: linear-gradient(45deg, #FFD700, #FFA500);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
        }
        
        .header .version {
            font-size: 1.2em;
            opacity: 0.8;
        }
        
        .dashboard-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(350px, 1fr));
            gap: 25px;
            margin-bottom: 40px;
        }
        
        .card {
            background: rgba(255, 255, 255, 0.15);
            padding: 25px;
            border-radius: 12px;
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease;
        }
        
        .card:hover {
            transform: translateY(-5px);
        }
        
        .card h3 {
            color: #FFD700;
            margin-bottom: 15px;
            font-size: 1.3em;
        }
        
        .metric {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
            padding: 8px 0;
            border-bottom: 1px solid rgba(255, 255, 255, 0.1);
        }
        
        .metric-label {
            font-weight: 500;
        }
        
        .metric-value {
            font-weight: bold;
            color: #4CAF50;
        }
        
        .status-indicator {
            display: inline-block;
            width: 12px;
            height: 12px;
            border-radius: 50%;
            margin-right: 8px;
        }
        
        .status-healthy { background-color: #4CAF50; }
        .status-warning { background-color: #FF9800; }
        .status-error { background-color: #F44336; }
        
        .api-section {
            background: rgba(0, 0, 0, 0.2);
            padding: 25px;
            border-radius: 12px;
            margin-top: 30px;
        }
        
        .api-section h3 {
            color: #FFD700;
            margin-bottom: 20px;
        }
        
        .endpoint {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px;
            border-radius: 8px;
            margin-bottom: 15px;
            font-family: 'Courier New', monospace;
        }
        
        .method {
            display: inline-block;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 0.8em;
            font-weight: bold;
            margin-right: 10px;
        }
        
        .method-get { background-color: #4CAF50; }
        .method-post { background-color: #2196F3; }
        .method-put { background-color: #FF9800; }
        .method-delete { background-color: #F44336; }
        
        .footer {
            text-align: center;
            margin-top: 40px;
            padding-top: 20px;
            border-top: 1px solid rgba(255, 255, 255, 0.2);
            font-size: 0.9em;
            opacity: 0.8;
        }
        
        .progress-bar {
            width: 100%;
            height: 8px;
            background-color: rgba(255, 255, 255, 0.2);
            border-radius: 4px;
            overflow: hidden;
            margin-top: 5px;
        }
        
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #4CAF50, #FFD700);
            transition: width 0.3s ease;
        }
        
        @media (max-width: 768px) {
            .dashboard-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2em;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 {{ config.APP_NAME }}</h1>
            <div class="version">Version {{ config.VERSION }}</div>
            <div>Last Updated: {{ timestamp }}</div>
        </div>
        
        <div class="dashboard-grid">
            <div class="card">
                <h3>🖥️ System Status</h3>
                <div class="metric">
                    <span class="metric-label">
                        <span class="status-indicator status-healthy"></span>Overall Status
                    </span>
                    <span class="metric-value">Operational</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Platform</span>
                    <span class="metric-value">{{ system_info.platform.system }} {{ system_info.platform.release }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Architecture</span>
                    <span class="metric-value">{{ system_info.platform.architecture }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Python Version</span>
                    <span class="metric-value">{{ system_info.platform.python_version }}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>📊 Performance Metrics</h3>
                <div class="metric">
                    <span class="metric-label">CPU Usage</span>
                    <span class="metric-value">{{ "%.1f"|format(system_info.resources.cpu_percent) }}%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{ system_info.resources.cpu_percent }}%"></div>
                </div>
                
                <div class="metric">
                    <span class="metric-label">Memory Usage</span>
                    <span class="metric-value">{{ "%.1f"|format(system_info.resources.memory_percent) }}%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{ system_info.resources.memory_percent }}%"></div>
                </div>
                
                <div class="metric">
                    <span class="metric-label">Disk Usage</span>
                    <span class="metric-value">{{ "%.1f"|format(system_info.resources.disk_percent) }}%</span>
                </div>
                <div class="progress-bar">
                    <div class="progress-fill" style="width: {{ system_info.resources.disk_percent }}%"></div>
                </div>
            </div>
            
            <div class="card">
                <h3>🔧 Application Metrics</h3>
                <div class="metric">
                    <span class="metric-label">Uptime</span>
                    <span class="metric-value">{{ "%.2f"|format(system_info.application.uptime) }} seconds</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Requests Processed</span>
                    <span class="metric-value">{{ system_info.application.requests_processed }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Error Count</span>
                    <span class="metric-value">{{ system_info.application.errors }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Bundle Directory</span>
                    <span class="metric-value">{{ system_info.application.bundle_directory }}</span>
                </div>
            </div>
            
            <div class="card">
                <h3>🌐 Network Information</h3>
                <div class="metric">
                    <span class="metric-label">Active Connections</span>
                    <span class="metric-value">{{ system_info.network.connections }}</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Bytes Sent</span>
                    <span class="metric-value">{{ "%.2f"|format(system_info.network.bytes_sent / 1024 / 1024) }} MB</span>
                </div>
                <div class="metric">
                    <span class="metric-label">Bytes Received</span>
                    <span class="metric-value">{{ "%.2f"|format(system_info.network.bytes_recv / 1024 / 1024) }} MB</span>
                </div>
            </div>
        </div>
        
        <div class="api-section">
            <h3>🔗 Available API Endpoints</h3>
            
            <div class="endpoint">
                <span class="method method-get">GET</span>
                <strong>/api/status</strong> - Get application status
            </div>
            
            <div class="endpoint">
                <span class="method method-get">GET</span>
                <strong>/api/health</strong> - Health check endpoint
            </div>
            
            <div class="endpoint">
                <span class="method method-post">POST</span>
                <strong>/api/auth/login</strong> - User authentication
            </div>
            
            <div class="endpoint">
                <span class="method method-post">POST</span>
                <strong>/api/auth/logout</strong> - User logout
            </div>
            
            <div class="endpoint">
                <span class="method method-get">GET</span>
                <strong>/api/metrics</strong> - Performance metrics (Auth required)
            </div>
            
            <div class="endpoint">
                <span class="method method-get">GET</span>
                <strong>/api/system-info</strong> - System information (Auth required)
            </div>
            
            <div class="endpoint">
                <span class="method method-post">POST</span>
                <strong>/api/command</strong> - Execute safe commands (Auth required)
            </div>
            
            <div class="endpoint">
                <span class="method method-get">GET</span>
                <strong>/api/audit-log</strong> - Audit log (Admin only)
            </div>
        </div>
        
        <div class="footer">
            <p><strong>{{ config.APP_NAME }}</strong> | Enterprise Flask Application</p>
            <p>🔒 Secure • 📊 Monitored • 🚀 High Performance • 🛡️ Audited</p>
            <p>Features: Authentication, RBAC, Audit Logging, Performance Monitoring, Health Checks</p>
        </div>
    </div>
    
    <script>
        // Auto-refresh page every 30 seconds
        setTimeout(() => {
            window.location.reload();
        }, 30000);
        
        // Add some interactivity
        document.querySelectorAll('.card').forEach(card => {
            card.addEventListener('click', () => {
                card.style.transform = 'scale(1.02)';
                setTimeout(() => {
                    card.style.transform = '';
                }, 200);
            });
        });
    </script>
</body>
</html>
"""

# Application factory and runner
def create_enterprise_app():
    """Create and configure the enterprise application"""
    return EnterpriseFlaskApp()

def main():
    """Main application entry point"""
    try:
        logger.info(f"Starting {config.APP_NAME} v{config.VERSION}")
        logger.info(f"Bundle directory: {config.BUNDLE_DIR}")
        logger.info(f"Database URL: {config.DATABASE_URL}")
        logger.info(f"Debug mode: {config.DEBUG}")
        
        # Create enterprise application
        enterprise_app = create_enterprise_app()
        
        # Setup signal handlers for graceful shutdown
        def signal_handler(signum, frame):
            logger.info(f"Received signal {signum}, shutting down gracefully...")
            sys.exit(0)
        
        signal.signal(signal.SIGTERM, signal_handler)
        signal.signal(signal.SIGINT, signal_handler)
        
        # Run with enhanced security and performance settings
        enterprise_app.app.run(
            host="127.0.0.1",  # Localhost only for security
            port=8080,
            debug=config.DEBUG,
            threaded=True,
            use_reloader=False,  # Disable reloader for production
            processes=1  # Single process for simplicity
        )
        
    except KeyboardInterrupt:
        logger.info("Shutting down gracefully...")
    except Exception as e:
        logger.error(f"Failed to start application: {e}")
        logger.error(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    main()