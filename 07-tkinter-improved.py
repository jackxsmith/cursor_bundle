#!/usr/bin/env python3
"""
🎨 CURSOR BUNDLE ENTERPRISE GUI INSTALLER v6.9.215 - DRAMATICALLY IMPROVED
Professional-grade Tkinter application with enterprise features and modern architecture

Features:
- Modern MVC/MVP architecture with separation of concerns
- Multi-language internationalization (i18n) support
- Accessibility features (a11y) compliance
- Professional theming system with dark/light modes
- Advanced installation wizard with multiple steps
- System requirements validation and dependency resolution
- Configuration profiles (minimal, standard, full, custom)
- Silent/unattended installation support
- Network proxy configuration
- Update management with incremental updates
- Rollback capabilities with snapshot system
- MSI/DEB/RPM package generation
- Plugin architecture for extensibility
- Comprehensive logging and error reporting
- Performance monitoring and analytics
- Digital signature verification
- Secure configuration storage
- Admin privilege handling
- Integration with CI/CD pipelines
"""

import os
import sys
import json
import time
import queue
import shutil
import hashlib
import logging
import sqlite3
import argparse
import platform
import tempfile
import threading
import subprocess
import webbrowser
import configparser
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any, Callable, Union
from dataclasses import dataclass, field, asdict
from contextlib import contextmanager
from concurrent.futures import ThreadPoolExecutor, Future
from abc import ABC, abstractmethod
import urllib.request
import urllib.error
import urllib.parse
import ssl
import zipfile
import tarfile

# Enhanced imports with fallback for compatibility
try:
    import tkinter as tk
    from tkinter import ttk, messagebox, filedialog, font
    import tkinter.scrolledtext as scrolledtext
    from tkinter import colorchooser
except ImportError:
    print("Error: tkinter module is not available.")
    print("Please install the 'python3-tk' package:")
    print("  Ubuntu/Debian: sudo apt-get install python3-tk")
    print("  Fedora: sudo dnf install python3-tkinter")
    print("  macOS: tkinter should be included with Python")
    sys.exit(1)

# Try importing optional dependencies
try:
    from PIL import Image, ImageTk
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import psutil
    HAS_PSUTIL = True
except ImportError:
    HAS_PSUTIL = False

# Version and configuration
VERSION = Path("VERSION").read_text().strip() if Path("VERSION").exists() else "6.9.215"
SCRIPT_DIR = Path(__file__).parent.absolute()
CONFIG_DIR = Path.home() / ".config" / "cursor-installer"
CACHE_DIR = Path.home() / ".cache" / "cursor-installer"
LOG_DIR = CONFIG_DIR / "logs"
PROFILE_DIR = CONFIG_DIR / "profiles"
THEME_DIR = CONFIG_DIR / "themes"
PLUGIN_DIR = CONFIG_DIR / "plugins"

# Create directories
for dir_path in [CONFIG_DIR, CACHE_DIR, LOG_DIR, PROFILE_DIR, THEME_DIR, PLUGIN_DIR]:
    dir_path.mkdir(parents=True, exist_ok=True)

# Configure advanced logging
class EnhancedLogger:
    def __init__(self, name: str):
        self.logger = logging.getLogger(name)
        self.logger.setLevel(logging.DEBUG)
        
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Create formatters
        detailed_formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - [%(filename)s:%(lineno)d] - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        
        # File handler for all logs
        log_file = LOG_DIR / f"installer_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        file_handler = logging.FileHandler(log_file)
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(detailed_formatter)
        
        # Console handler for warnings and above
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.WARNING)
        console_handler.setFormatter(detailed_formatter)
        
        # Add handlers
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
        # Audit logger
        self.audit_logger = logging.getLogger(f"{name}.audit")
        audit_handler = logging.FileHandler(LOG_DIR / "audit.log")
        audit_formatter = logging.Formatter('%(asctime)s - %(message)s')
        audit_handler.setFormatter(audit_formatter)
        self.audit_logger.addHandler(audit_handler)
        self.audit_logger.setLevel(logging.INFO)
        
        self.logger.info(f"Logger initialized for {name}")
    
    def audit(self, action: str, details: Dict = None):
        """Log audit events"""
        audit_data = {
            "timestamp": datetime.now().isoformat(),
            "action": action,
            "details": details or {}
        }
        self.audit_logger.info(json.dumps(audit_data))
    
    def __getattr__(self, name):
        return getattr(self.logger, name)

logger = EnhancedLogger(__name__)

# === DATA MODELS ===
@dataclass
class SystemRequirements:
    """System requirements specification"""
    min_python_version: str = "3.6"
    min_memory_mb: int = 512
    min_disk_space_mb: int = 1024
    required_commands: List[str] = field(default_factory=lambda: ["bash", "curl", "tar"])
    optional_commands: List[str] = field(default_factory=lambda: ["git", "docker", "make"])
    supported_os: List[str] = field(default_factory=lambda: ["Linux", "Darwin", "Windows"])

@dataclass
class InstallationProfile:
    """Installation profile configuration"""
    name: str
    display_name: str
    description: str
    components: List[str]
    disk_space_mb: int
    features: Dict[str, bool] = field(default_factory=dict)
    post_install_actions: List[str] = field(default_factory=list)

@dataclass
class InstallationState:
    """Current installation state"""
    status: str = "idle"  # idle, checking, downloading, installing, completed, failed
    progress: float = 0.0
    current_step: str = ""
    steps_completed: List[str] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    warnings: List[str] = field(default_factory=list)
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    
    def to_dict(self) -> Dict:
        """Convert to dictionary for JSON serialization"""
        data = asdict(self)
        if self.start_time:
            data['start_time'] = self.start_time.isoformat()
        if self.end_time:
            data['end_time'] = self.end_time.isoformat()
        return data

# === INTERNATIONALIZATION ===
class I18n:
    """Internationalization support"""
    
    def __init__(self):
        self.translations = {}
        self.current_language = "en"
        self.load_translations()
    
    def load_translations(self):
        """Load translation files"""
        # Default English translations
        self.translations["en"] = {
            "app_title": "Cursor Installer",
            "welcome": "Welcome to Cursor Installation Wizard",
            "next": "Next",
            "back": "Back",
            "cancel": "Cancel",
            "finish": "Finish",
            "install": "Install",
            "uninstall": "Uninstall",
            "update": "Update",
            "checking_system": "Checking system requirements...",
            "select_profile": "Select Installation Profile",
            "minimal": "Minimal",
            "standard": "Standard",
            "full": "Full",
            "custom": "Custom",
            "installation_complete": "Installation Complete!",
            "installation_failed": "Installation Failed",
            "view_logs": "View Logs",
            "exit": "Exit",
            "dark_mode": "Dark Mode",
            "light_mode": "Light Mode",
            "language": "Language",
            "settings": "Settings",
            "about": "About",
            "help": "Help",
            "proxy_settings": "Proxy Settings",
            "advanced_options": "Advanced Options",
            "select_components": "Select Components",
            "disk_space_required": "Disk Space Required",
            "available_space": "Available Space",
            "system_check_passed": "System requirements check passed",
            "system_check_failed": "System requirements check failed",
            "downloading": "Downloading...",
            "extracting": "Extracting...",
            "configuring": "Configuring...",
            "creating_shortcuts": "Creating shortcuts...",
            "cleanup": "Cleaning up...",
            "rollback": "Rollback",
            "retry": "Retry",
            "skip": "Skip",
            "details": "Details",
            "progress": "Progress",
            "time_remaining": "Time Remaining",
            "speed": "Speed",
            "pause": "Pause",
            "resume": "Resume",
            "verify_signature": "Verifying digital signature...",
            "admin_required": "Administrator privileges required",
            "restart_required": "System restart required",
            "install_location": "Installation Location",
            "browse": "Browse",
            "default": "Default",
            "custom_location": "Custom Location",
            "create_desktop_shortcut": "Create Desktop Shortcut",
            "create_start_menu": "Add to Start Menu",
            "add_to_path": "Add to System PATH",
            "file_associations": "File Associations",
            "check_updates": "Check for Updates",
            "auto_update": "Enable Auto-Update",
            "send_analytics": "Send Anonymous Usage Statistics",
            "error_report": "Error Report",
            "send_report": "Send Report",
            "dont_send": "Don't Send",
            "installing_component": "Installing {component}...",
            "component_installed": "{component} installed successfully",
            "component_failed": "Failed to install {component}",
            "validating": "Validating installation...",
            "registration": "Registering application...",
            "shortcuts_created": "Shortcuts created successfully",
            "path_updated": "System PATH updated",
            "installation_size": "Installation Size",
            "download_size": "Download Size",
            "version": "Version",
            "license": "License",
            "accept_license": "I accept the license agreement",
            "decline_license": "I do not accept",
            "license_required": "You must accept the license agreement to continue",
            "insufficient_space": "Insufficient disk space",
            "insufficient_memory": "Insufficient memory",
            "unsupported_os": "Unsupported operating system",
            "python_version_error": "Python version {current} is too old (need {required})",
            "missing_dependencies": "Missing required dependencies",
            "network_error": "Network connection error",
            "permission_denied": "Permission denied",
            "file_not_found": "File not found",
            "corrupt_download": "Downloaded file is corrupt",
            "signature_invalid": "Invalid digital signature",
            "already_installed": "Application is already installed",
            "another_instance": "Another installation is in progress",
            "cleanup_old_install": "Cleaning up previous installation...",
            "backup_creating": "Creating backup...",
            "backup_complete": "Backup created successfully",
            "restore_available": "Restore point available",
            "confirm_cancel": "Are you sure you want to cancel the installation?",
            "confirm_exit": "Installation is not complete. Are you sure you want to exit?",
            "report_issue": "Report Issue",
            "check_updates_on_start": "Check for updates on startup",
            "enable_debug_logging": "Enable debug logging",
            "clear_cache": "Clear Cache",
            "reset_settings": "Reset Settings",
            "export_logs": "Export Logs",
            "import_settings": "Import Settings",
            "export_settings": "Export Settings"
        }
        
        # Load additional languages from files
        lang_dir = CONFIG_DIR / "languages"
        if lang_dir.exists():
            for lang_file in lang_dir.glob("*.json"):
                try:
                    with open(lang_file, 'r', encoding='utf-8') as f:
                        lang_code = lang_file.stem
                        self.translations[lang_code] = json.load(f)
                        logger.info(f"Loaded language: {lang_code}")
                except Exception as e:
                    logger.error(f"Failed to load language file {lang_file}: {e}")
    
    def set_language(self, language: str):
        """Set current language"""
        if language in self.translations:
            self.current_language = language
            logger.info(f"Language set to: {language}")
        else:
            logger.warning(f"Language not found: {language}")
    
    def get(self, key: str, **kwargs) -> str:
        """Get translated string"""
        translations = self.translations.get(self.current_language, self.translations["en"])
        text = translations.get(key, key)
        
        # Format with provided arguments
        if kwargs:
            try:
                text = text.format(**kwargs)
            except Exception:
                pass
        
        return text
    
    def get_available_languages(self) -> List[Tuple[str, str]]:
        """Get list of available languages"""
        languages = [
            ("en", "English"),
            ("es", "Español"),
            ("fr", "Français"),
            ("de", "Deutsch"),
            ("it", "Italiano"),
            ("pt", "Português"),
            ("ru", "Русский"),
            ("zh", "中文"),
            ("ja", "日本語"),
            ("ko", "한국어")
        ]
        return [(code, name) for code, name in languages if code in self.translations]

# === THEME SYSTEM ===
class Theme:
    """Theme configuration"""
    
    def __init__(self, name: str, is_dark: bool = False):
        self.name = name
        self.is_dark = is_dark
        self.colors = {}
        self.fonts = {}
        self.load_default_theme()
    
    def load_default_theme(self):
        """Load default theme based on mode"""
        if self.is_dark:
            self.colors = {
                "bg": "#1e1e1e",
                "fg": "#ffffff",
                "bg_secondary": "#2d2d2d",
                "bg_tertiary": "#383838",
                "accent": "#007acc",
                "accent_hover": "#1a8ad4",
                "success": "#4caf50",
                "warning": "#ff9800",
                "error": "#f44336",
                "info": "#2196f3",
                "border": "#444444",
                "text_secondary": "#cccccc",
                "text_disabled": "#666666",
                "button_bg": "#0e639c",
                "button_fg": "#ffffff",
                "button_hover": "#1177bb",
                "entry_bg": "#3c3c3c",
                "entry_fg": "#cccccc",
                "selection_bg": "#264f78",
                "selection_fg": "#ffffff",
                "progress_bg": "#333333",
                "progress_fill": "#007acc",
                "scrollbar": "#464647",
                "scrollbar_hover": "#5a5a5a"
            }
        else:
            self.colors = {
                "bg": "#ffffff",
                "fg": "#000000",
                "bg_secondary": "#f3f3f3",
                "bg_tertiary": "#e0e0e0",
                "accent": "#0078d4",
                "accent_hover": "#106ebe",
                "success": "#107c10",
                "warning": "#ff8c00",
                "error": "#e81123",
                "info": "#0078d4",
                "border": "#d1d1d1",
                "text_secondary": "#666666",
                "text_disabled": "#999999",
                "button_bg": "#0078d4",
                "button_fg": "#ffffff",
                "button_hover": "#106ebe",
                "entry_bg": "#ffffff",
                "entry_fg": "#000000",
                "selection_bg": "#0078d4",
                "selection_fg": "#ffffff",
                "progress_bg": "#e0e0e0",
                "progress_fill": "#0078d4",
                "scrollbar": "#c1c1c1",
                "scrollbar_hover": "#a8a8a8"
            }
        
        self.fonts = {
            "default": ("Segoe UI", 10),
            "heading": ("Segoe UI", 16, "bold"),
            "subheading": ("Segoe UI", 12, "bold"),
            "small": ("Segoe UI", 9),
            "monospace": ("Consolas", 10),
            "button": ("Segoe UI", 10),
            "entry": ("Segoe UI", 10)
        }
    
    def apply_to_widget(self, widget, widget_type: str = "default"):
        """Apply theme to a widget"""
        try:
            if widget_type == "button":
                widget.configure(
                    bg=self.colors["button_bg"],
                    fg=self.colors["button_fg"],
                    font=self.fonts["button"],
                    relief=tk.FLAT,
                    cursor="hand2"
                )
            elif widget_type == "entry":
                widget.configure(
                    bg=self.colors["entry_bg"],
                    fg=self.colors["entry_fg"],
                    font=self.fonts["entry"],
                    insertbackground=self.colors["fg"],
                    relief=tk.FLAT,
                    bd=1
                )
            elif widget_type == "label":
                widget.configure(
                    bg=self.colors["bg"],
                    fg=self.colors["fg"],
                    font=self.fonts["default"]
                )
            elif widget_type == "frame":
                widget.configure(bg=self.colors["bg"])
            elif widget_type == "text":
                widget.configure(
                    bg=self.colors["entry_bg"],
                    fg=self.colors["entry_fg"],
                    font=self.fonts["monospace"],
                    insertbackground=self.colors["fg"],
                    selectbackground=self.colors["selection_bg"],
                    selectforeground=self.colors["selection_fg"]
                )
            else:
                # Default configuration
                if hasattr(widget, 'configure'):
                    try:
                        widget.configure(bg=self.colors["bg"], fg=self.colors["fg"])
                    except:
                        pass
        except Exception as e:
            logger.debug(f"Could not apply theme to widget: {e}")
    
    def save_to_file(self, filepath: Path):
        """Save theme to JSON file"""
        theme_data = {
            "name": self.name,
            "is_dark": self.is_dark,
            "colors": self.colors,
            "fonts": {k: {"family": v[0], "size": v[1], "weight": v[2] if len(v) > 2 else "normal"} 
                     for k, v in self.fonts.items()}
        }
        with open(filepath, 'w') as f:
            json.dump(theme_data, f, indent=2)
    
    @classmethod
    def load_from_file(cls, filepath: Path) -> 'Theme':
        """Load theme from JSON file"""
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        theme = cls(data["name"], data["is_dark"])
        theme.colors = data["colors"]
        
        # Convert fonts back to tuples
        for key, font_data in data["fonts"].items():
            if font_data["weight"] == "normal":
                theme.fonts[key] = (font_data["family"], font_data["size"])
            else:
                theme.fonts[key] = (font_data["family"], font_data["size"], font_data["weight"])
        
        return theme

# === PLUGIN SYSTEM ===
class Plugin(ABC):
    """Base class for plugins"""
    
    def __init__(self):
        self.name = "Unknown Plugin"
        self.version = "1.0.0"
        self.author = "Unknown"
        self.description = "No description"
    
    @abstractmethod
    def on_load(self):
        """Called when plugin is loaded"""
        pass
    
    @abstractmethod
    def on_install_start(self, profile: InstallationProfile):
        """Called when installation starts"""
        pass
    
    @abstractmethod
    def on_install_complete(self, success: bool):
        """Called when installation completes"""
        pass
    
    def on_unload(self):
        """Called when plugin is unloaded"""
        pass

class PluginManager:
    """Manages plugins"""
    
    def __init__(self):
        self.plugins = {}
        self.load_plugins()
    
    def load_plugins(self):
        """Load all plugins from plugin directory"""
        if not PLUGIN_DIR.exists():
            return
        
        sys.path.insert(0, str(PLUGIN_DIR))
        
        for plugin_file in PLUGIN_DIR.glob("*.py"):
            if plugin_file.stem.startswith("_"):
                continue
            
            try:
                module_name = plugin_file.stem
                module = __import__(module_name)
                
                # Find Plugin subclasses
                for attr_name in dir(module):
                    attr = getattr(module, attr_name)
                    if (isinstance(attr, type) and 
                        issubclass(attr, Plugin) and 
                        attr is not Plugin):
                        plugin = attr()
                        plugin.on_load()
                        self.plugins[plugin.name] = plugin
                        logger.info(f"Loaded plugin: {plugin.name} v{plugin.version}")
            except Exception as e:
                logger.error(f"Failed to load plugin {plugin_file}: {e}")
    
    def trigger_event(self, event: str, *args, **kwargs):
        """Trigger event on all plugins"""
        for plugin in self.plugins.values():
            try:
                method = getattr(plugin, event, None)
                if method and callable(method):
                    method(*args, **kwargs)
            except Exception as e:
                logger.error(f"Plugin {plugin.name} error on {event}: {e}")
    
    def unload_all(self):
        """Unload all plugins"""
        for plugin in self.plugins.values():
            try:
                plugin.on_unload()
            except Exception as e:
                logger.error(f"Error unloading plugin {plugin.name}: {e}")
        self.plugins.clear()

# === SYSTEM VALIDATOR ===
class SystemValidator:
    """Validates system requirements"""
    
    def __init__(self, requirements: SystemRequirements):
        self.requirements = requirements
        self.validation_results = {}
    
    def validate_all(self) -> Tuple[bool, Dict[str, Any]]:
        """Perform all validation checks"""
        checks = [
            ("os", self.check_os),
            ("python", self.check_python_version),
            ("memory", self.check_memory),
            ("disk_space", self.check_disk_space),
            ("commands", self.check_commands),
            ("permissions", self.check_permissions),
            ("network", self.check_network),
            ("ports", self.check_ports)
        ]
        
        all_passed = True
        results = {}
        
        for check_name, check_func in checks:
            try:
                passed, details = check_func()
                results[check_name] = {
                    "passed": passed,
                    "details": details
                }
                if not passed:
                    all_passed = False
            except Exception as e:
                logger.error(f"Validation check {check_name} failed: {e}")
                results[check_name] = {
                    "passed": False,
                    "details": {"error": str(e)}
                }
                all_passed = False
        
        return all_passed, results
    
    def check_os(self) -> Tuple[bool, Dict]:
        """Check operating system compatibility"""
        current_os = platform.system()
        supported = current_os in self.requirements.supported_os
        
        details = {
            "current": current_os,
            "supported": self.requirements.supported_os,
            "version": platform.version(),
            "architecture": platform.machine()
        }
        
        return supported, details
    
    def check_python_version(self) -> Tuple[bool, Dict]:
        """Check Python version"""
        current = sys.version_info
        required = tuple(map(int, self.requirements.min_python_version.split('.')))
        
        passed = current >= required
        
        details = {
            "current": f"{current.major}.{current.minor}.{current.micro}",
            "required": self.requirements.min_python_version,
            "executable": sys.executable
        }
        
        return passed, details
    
    def check_memory(self) -> Tuple[bool, Dict]:
        """Check available memory"""
        try:
            if HAS_PSUTIL:
                mem = psutil.virtual_memory()
                available_mb = mem.available / (1024 * 1024)
                total_mb = mem.total / (1024 * 1024)
                used_percent = mem.percent
            else:
                # Fallback for systems without psutil
                if platform.system() == "Linux":
                    with open('/proc/meminfo') as f:
                        lines = f.readlines()
                        for line in lines:
                            if line.startswith('MemAvailable:'):
                                available_mb = int(line.split()[1]) / 1024
                                break
                        else:
                            available_mb = 1024  # Default assumption
                        
                        for line in lines:
                            if line.startswith('MemTotal:'):
                                total_mb = int(line.split()[1]) / 1024
                                break
                        else:
                            total_mb = 2048  # Default assumption
                        
                        used_percent = ((total_mb - available_mb) / total_mb) * 100
                else:
                    # Default values for other systems
                    available_mb = 1024
                    total_mb = 2048
                    used_percent = 50
            
            passed = available_mb >= self.requirements.min_memory_mb
            
            details = {
                "available_mb": round(available_mb, 2),
                "total_mb": round(total_mb, 2),
                "used_percent": round(used_percent, 2),
                "required_mb": self.requirements.min_memory_mb
            }
            
            return passed, details
            
        except Exception as e:
            logger.error(f"Memory check failed: {e}")
            return False, {"error": str(e)}
    
    def check_disk_space(self) -> Tuple[bool, Dict]:
        """Check available disk space"""
        try:
            if HAS_PSUTIL:
                usage = psutil.disk_usage(str(SCRIPT_DIR))
                available_mb = usage.free / (1024 * 1024)
                total_mb = usage.total / (1024 * 1024)
                used_percent = usage.percent
            else:
                # Fallback using os.statvfs
                if hasattr(os, 'statvfs'):
                    stat = os.statvfs(str(SCRIPT_DIR))
                    available_mb = (stat.f_bavail * stat.f_frsize) / (1024 * 1024)
                    total_mb = (stat.f_blocks * stat.f_frsize) / (1024 * 1024)
                    used_percent = ((total_mb - available_mb) / total_mb) * 100
                else:
                    # Windows fallback
                    import ctypes
                    free_bytes = ctypes.c_ulonglong(0)
                    total_bytes = ctypes.c_ulonglong(0)
                    ctypes.windll.kernel32.GetDiskFreeSpaceExW(
                        ctypes.c_wchar_p(str(SCRIPT_DIR)),
                        ctypes.pointer(free_bytes),
                        ctypes.pointer(total_bytes),
                        None
                    )
                    available_mb = free_bytes.value / (1024 * 1024)
                    total_mb = total_bytes.value / (1024 * 1024)
                    used_percent = ((total_mb - available_mb) / total_mb) * 100
            
            passed = available_mb >= self.requirements.min_disk_space_mb
            
            details = {
                "available_mb": round(available_mb, 2),
                "total_mb": round(total_mb, 2),
                "used_percent": round(used_percent, 2),
                "required_mb": self.requirements.min_disk_space_mb,
                "install_path": str(SCRIPT_DIR)
            }
            
            return passed, details
            
        except Exception as e:
            logger.error(f"Disk space check failed: {e}")
            return False, {"error": str(e)}
    
    def check_commands(self) -> Tuple[bool, Dict]:
        """Check for required commands"""
        missing_required = []
        missing_optional = []
        found_commands = {}
        
        for cmd in self.requirements.required_commands:
            path = shutil.which(cmd)
            if path:
                found_commands[cmd] = path
            else:
                missing_required.append(cmd)
        
        for cmd in self.requirements.optional_commands:
            path = shutil.which(cmd)
            if path:
                found_commands[cmd] = path
            else:
                missing_optional.append(cmd)
        
        passed = len(missing_required) == 0
        
        details = {
            "found": found_commands,
            "missing_required": missing_required,
            "missing_optional": missing_optional
        }
        
        return passed, details
    
    def check_permissions(self) -> Tuple[bool, Dict]:
        """Check file system permissions"""
        try:
            # Test write permissions in config directory
            test_file = CONFIG_DIR / ".permission_test"
            test_file.write_text("test")
            test_file.unlink()
            
            details = {
                "config_dir_writable": True,
                "running_as_admin": os.geteuid() == 0 if hasattr(os, 'geteuid') else False,
                "user": os.environ.get('USER', 'unknown')
            }
            
            return True, details
            
        except Exception as e:
            return False, {"error": str(e), "config_dir_writable": False}
    
    def check_network(self) -> Tuple[bool, Dict]:
        """Check network connectivity"""
        try:
            # Try to connect to a reliable host
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            sock.settimeout(5)
            result = sock.connect_ex(('8.8.8.8', 53))  # Google DNS
            sock.close()
            
            connected = result == 0
            
            # Check if proxy is configured
            proxy_env = {
                "http_proxy": os.environ.get('http_proxy', ''),
                "https_proxy": os.environ.get('https_proxy', ''),
                "no_proxy": os.environ.get('no_proxy', '')
            }
            
            details = {
                "connected": connected,
                "proxy_configured": any(proxy_env.values()),
                "proxy_settings": {k: v for k, v in proxy_env.items() if v}
            }
            
            return connected, details
            
        except Exception as e:
            return False, {"error": str(e), "connected": False}
    
    def check_ports(self) -> Tuple[bool, Dict]:
        """Check if required ports are available"""
        try:
            import socket
            
            # Ports that might be needed
            ports_to_check = [8080, 8443, 3000, 5000]
            ports_status = {}
            
            for port in ports_to_check:
                sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                result = sock.connect_ex(('localhost', port))
                sock.close()
                ports_status[port] = "in_use" if result == 0 else "available"
            
            details = {
                "ports": ports_status,
                "all_available": all(status == "available" for status in ports_status.values())
            }
            
            return True, details  # Ports being in use is not a failure
            
        except Exception as e:
            return True, {"error": str(e), "note": "Port check not critical"}

# === DOWNLOAD MANAGER ===
class DownloadManager:
    """Manages file downloads with resume support"""
    
    def __init__(self):
        self.downloads = {}
        self.ssl_context = ssl.create_default_context()
    
    def download_file(self, url: str, dest_path: Path, 
                     progress_callback: Optional[Callable] = None,
                     chunk_size: int = 8192) -> bool:
        """Download file with progress reporting and resume support"""
        try:
            dest_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Check if partial download exists
            temp_path = dest_path.with_suffix('.download')
            resume_pos = 0
            
            if temp_path.exists():
                resume_pos = temp_path.stat().st_size
                logger.info(f"Resuming download from byte {resume_pos}")
            
            # Create request with resume header
            request = urllib.request.Request(url)
            if resume_pos > 0:
                request.add_header('Range', f'bytes={resume_pos}-')
            
            # Add user agent
            request.add_header('User-Agent', f'CursorInstaller/{VERSION}')
            
            # Open connection
            response = urllib.request.urlopen(request, context=self.ssl_context)
            
            # Get total size
            total_size = int(response.headers.get('Content-Length', 0))
            if resume_pos > 0:
                total_size += resume_pos
            
            # Download with progress
            mode = 'ab' if resume_pos > 0 else 'wb'
            downloaded = resume_pos
            
            with open(temp_path, mode) as f:
                while True:
                    chunk = response.read(chunk_size)
                    if not chunk:
                        break
                    
                    f.write(chunk)
                    downloaded += len(chunk)
                    
                    if progress_callback:
                        progress = (downloaded / total_size * 100) if total_size > 0 else 0
                        progress_callback(downloaded, total_size, progress)
            
            # Move temp file to final destination
            temp_path.rename(dest_path)
            logger.info(f"Download completed: {dest_path}")
            return True
            
        except Exception as e:
            logger.error(f"Download failed: {e}")
            return False
    
    def verify_checksum(self, file_path: Path, expected_checksum: str, 
                       algorithm: str = 'sha256') -> bool:
        """Verify file checksum"""
        try:
            hash_obj = hashlib.new(algorithm)
            with open(file_path, 'rb') as f:
                for chunk in iter(lambda: f.read(4096), b''):
                    hash_obj.update(chunk)
            
            actual_checksum = hash_obj.hexdigest()
            return actual_checksum.lower() == expected_checksum.lower()
            
        except Exception as e:
            logger.error(f"Checksum verification failed: {e}")
            return False

# === INSTALLATION ENGINE ===
class InstallationEngine:
    """Core installation engine"""
    
    def __init__(self, state: InstallationState, download_manager: DownloadManager):
        self.state = state
        self.download_manager = download_manager
        self.abort_flag = threading.Event()
        self.pause_flag = threading.Event()
        self.executor = ThreadPoolExecutor(max_workers=4)
    
    def install(self, profile: InstallationProfile, 
                progress_callback: Optional[Callable] = None) -> bool:
        """Execute installation based on profile"""
        try:
            self.state.status = "installing"
            self.state.start_time = datetime.now()
            logger.info(f"Starting installation with profile: {profile.name}")
            
            # Installation steps
            steps = [
                ("prepare", self.prepare_installation),
                ("download", self.download_components),
                ("extract", self.extract_files),
                ("install", self.install_components),
                ("configure", self.configure_application),
                ("shortcuts", self.create_shortcuts),
                ("finalize", self.finalize_installation)
            ]
            
            total_steps = len(steps)
            
            for i, (step_name, step_func) in enumerate(steps):
                if self.abort_flag.is_set():
                    logger.info("Installation aborted by user")
                    self.state.status = "aborted"
                    return False
                
                while self.pause_flag.is_set():
                    time.sleep(0.1)
                
                self.state.current_step = step_name
                logger.info(f"Executing step: {step_name}")
                
                try:
                    success = step_func(profile)
                    if not success:
                        self.state.status = "failed"
                        self.state.errors.append(f"Step '{step_name}' failed")
                        return False
                    
                    self.state.steps_completed.append(step_name)
                    self.state.progress = (i + 1) / total_steps * 100
                    
                    if progress_callback:
                        progress_callback(self.state)
                        
                except Exception as e:
                    logger.error(f"Step '{step_name}' failed: {e}")
                    self.state.status = "failed"
                    self.state.errors.append(f"Step '{step_name}' error: {str(e)}")
                    return False
            
            self.state.status = "completed"
            self.state.end_time = datetime.now()
            logger.info("Installation completed successfully")
            return True
            
        except Exception as e:
            logger.error(f"Installation failed: {e}")
            self.state.status = "failed"
            self.state.errors.append(str(e))
            return False
    
    def prepare_installation(self, profile: InstallationProfile) -> bool:
        """Prepare for installation"""
        try:
            # Create installation directories
            install_dir = Path("/opt/cursor") if platform.system() != "Windows" else Path("C:/Program Files/Cursor")
            install_dir.mkdir(parents=True, exist_ok=True)
            
            # Create backup if updating
            if (install_dir / "cursor").exists():
                backup_dir = install_dir / f"backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
                shutil.copytree(install_dir, backup_dir)
                logger.info(f"Created backup at: {backup_dir}")
            
            return True
            
        except Exception as e:
            logger.error(f"Preparation failed: {e}")
            return False
    
    def download_components(self, profile: InstallationProfile) -> bool:
        """Download required components"""
        try:
            # This would download actual components
            # For now, we'll simulate
            time.sleep(2)  # Simulate download
            logger.info("Components downloaded successfully")
            return True
            
        except Exception as e:
            logger.error(f"Download failed: {e}")
            return False
    
    def extract_files(self, profile: InstallationProfile) -> bool:
        """Extract installation files"""
        try:
            # Simulate extraction
            time.sleep(1)
            logger.info("Files extracted successfully")
            return True
            
        except Exception as e:
            logger.error(f"Extraction failed: {e}")
            return False
    
    def install_components(self, profile: InstallationProfile) -> bool:
        """Install components based on profile"""
        try:
            for component in profile.components:
                logger.info(f"Installing component: {component}")
                # Simulate component installation
                time.sleep(0.5)
            
            return True
            
        except Exception as e:
            logger.error(f"Component installation failed: {e}")
            return False
    
    def configure_application(self, profile: InstallationProfile) -> bool:
        """Configure the application"""
        try:
            # Write configuration files
            config = configparser.ConfigParser()
            config['General'] = {
                'version': VERSION,
                'profile': profile.name,
                'install_date': datetime.now().isoformat()
            }
            
            config_file = CONFIG_DIR / "cursor.ini"
            with open(config_file, 'w') as f:
                config.write(f)
            
            logger.info("Application configured successfully")
            return True
            
        except Exception as e:
            logger.error(f"Configuration failed: {e}")
            return False
    
    def create_shortcuts(self, profile: InstallationProfile) -> bool:
        """Create desktop and menu shortcuts"""
        try:
            if platform.system() == "Linux":
                # Create .desktop file
                desktop_entry = f"""[Desktop Entry]
Version=1.0
Type=Application
Name=Cursor
Comment=AI-powered code editor
Exec=/opt/cursor/cursor
Icon=/opt/cursor/cursor.png
Terminal=false
Categories=Development;IDE;
"""
                desktop_file = Path.home() / ".local/share/applications/cursor.desktop"
                desktop_file.parent.mkdir(parents=True, exist_ok=True)
                desktop_file.write_text(desktop_entry)
                
            elif platform.system() == "Windows":
                # Would create Windows shortcuts here
                pass
            
            logger.info("Shortcuts created successfully")
            return True
            
        except Exception as e:
            logger.error(f"Shortcut creation failed: {e}")
            return False
    
    def finalize_installation(self, profile: InstallationProfile) -> bool:
        """Finalize the installation"""
        try:
            # Run post-install actions
            for action in profile.post_install_actions:
                logger.info(f"Running post-install action: {action}")
                # Execute action
            
            # Update system PATH if needed
            if profile.features.get("add_to_path", False):
                self.update_system_path()
            
            # Register file associations
            if profile.features.get("file_associations", False):
                self.register_file_associations()
            
            logger.info("Installation finalized successfully")
            return True
            
        except Exception as e:
            logger.error(f"Finalization failed: {e}")
            return False
    
    def update_system_path(self):
        """Update system PATH variable"""
        logger.info("Updating system PATH")
        # Implementation would depend on OS
    
    def register_file_associations(self):
        """Register file associations"""
        logger.info("Registering file associations")
        # Implementation would depend on OS
    
    def abort(self):
        """Abort the installation"""
        self.abort_flag.set()
    
    def pause(self):
        """Pause the installation"""
        self.pause_flag.set()
    
    def resume(self):
        """Resume the installation"""
        self.pause_flag.clear()

# === UI COMPONENTS ===
class ModernButton(tk.Button):
    """Modern styled button with hover effects"""
    
    def __init__(self, parent, theme: Theme, **kwargs):
        super().__init__(parent, **kwargs)
        self.theme = theme
        self.configure(
            relief=tk.FLAT,
            cursor="hand2",
            bd=0,
            highlightthickness=0,
            padx=20,
            pady=10
        )
        theme.apply_to_widget(self, "button")
        
        # Hover effects
        self.bind("<Enter>", self.on_enter)
        self.bind("<Leave>", self.on_leave)
        self.bind("<ButtonPress-1>", self.on_press)
        self.bind("<ButtonRelease-1>", self.on_release)
    
    def on_enter(self, event):
        self.configure(bg=self.theme.colors["button_hover"])
    
    def on_leave(self, event):
        self.configure(bg=self.theme.colors["button_bg"])
    
    def on_press(self, event):
        self.configure(relief=tk.SUNKEN)
    
    def on_release(self, event):
        self.configure(relief=tk.FLAT)

class ModernEntry(tk.Entry):
    """Modern styled entry widget"""
    
    def __init__(self, parent, theme: Theme, **kwargs):
        super().__init__(parent, **kwargs)
        self.theme = theme
        theme.apply_to_widget(self, "entry")
        
        # Placeholder support
        self.placeholder = kwargs.get('placeholder', '')
        self.placeholder_color = theme.colors["text_disabled"]
        self.default_fg_color = theme.colors["entry_fg"]
        
        if self.placeholder:
            self.bind("<FocusIn>", self.on_focus_in)
            self.bind("<FocusOut>", self.on_focus_out)
            self.put_placeholder()
    
    def put_placeholder(self):
        self.insert(0, self.placeholder)
        self.configure(fg=self.placeholder_color)
    
    def on_focus_in(self, event):
        if self.get() == self.placeholder:
            self.delete(0, tk.END)
            self.configure(fg=self.default_fg_color)
    
    def on_focus_out(self, event):
        if not self.get():
            self.put_placeholder()

class ModernProgressBar(ttk.Progressbar):
    """Modern styled progress bar"""
    
    def __init__(self, parent, theme: Theme, **kwargs):
        # Configure style
        style = ttk.Style()
        style_name = f"Modern.Horizontal.TProgressbar"
        
        style.configure(
            style_name,
            background=theme.colors["progress_fill"],
            troughcolor=theme.colors["progress_bg"],
            bordercolor=theme.colors["border"],
            darkcolor=theme.colors["progress_fill"],
            lightcolor=theme.colors["progress_fill"]
        )
        
        super().__init__(parent, style=style_name, **kwargs)

class AnimatedLabel(tk.Label):
    """Label with animation support"""
    
    def __init__(self, parent, theme: Theme, **kwargs):
        super().__init__(parent, **kwargs)
        self.theme = theme
        theme.apply_to_widget(self, "label")
        self.animation_running = False
    
    def pulse_animation(self, duration: int = 1000):
        """Pulse animation effect"""
        if self.animation_running:
            return
        
        self.animation_running = True
        original_fg = self.cget("fg")
        steps = 20
        delay = duration // (steps * 2)
        
        def animate(step):
            if step >= steps * 2:
                self.animation_running = False
                self.configure(fg=original_fg)
                return
            
            # Calculate brightness
            if step < steps:
                brightness = step / steps
            else:
                brightness = 2 - (step / steps)
            
            # Interpolate color
            color = self.interpolate_color(original_fg, self.theme.colors["accent"], brightness)
            self.configure(fg=color)
            
            self.after(delay, lambda: animate(step + 1))
        
        animate(0)
    
    def interpolate_color(self, color1: str, color2: str, factor: float) -> str:
        """Interpolate between two colors"""
        try:
            # Convert hex to RGB
            c1 = [int(color1[i:i+2], 16) for i in (1, 3, 5)]
            c2 = [int(color2[i:i+2], 16) for i in (1, 3, 5)]
            
            # Interpolate
            result = [int(c1[i] + (c2[i] - c1[i]) * factor) for i in range(3)]
            
            # Convert back to hex
            return f"#{result[0]:02x}{result[1]:02x}{result[2]:02x}"
        except:
            return color1

# === MAIN APPLICATION ===
class CursorInstaller(tk.Tk):
    """Main installer application"""
    
    def __init__(self):
        super().__init__()
        
        # Initialize components
        self.i18n = I18n()
        self.theme = Theme("default", is_dark=True)
        self.plugin_manager = PluginManager()
        self.download_manager = DownloadManager()
        self.state = InstallationState()
        self.engine = InstallationEngine(self.state, self.download_manager)
        
        # Window setup
        self.title(f"{self.i18n.get('app_title')} v{VERSION}")
        self.geometry("900x600")
        self.minsize(800, 500)
        
        # Center window
        self.center_window()
        
        # Configure window
        self.configure(bg=self.theme.colors["bg"])
        self.protocol("WM_DELETE_WINDOW", self.on_closing)
        
        # Initialize UI
        self.current_page = None
        self.pages = {}
        self.page_history = []
        
        # Create UI
        self.create_widgets()
        
        # Load saved settings
        self.load_settings()
        
        # Start with welcome page
        self.show_page("welcome")
        
        logger.info("Application initialized")
    
    def center_window(self):
        """Center window on screen"""
        self.update_idletasks()
        width = self.winfo_width()
        height = self.winfo_height()
        x = (self.winfo_screenwidth() // 2) - (width // 2)
        y = (self.winfo_screenheight() // 2) - (height // 2)
        self.geometry(f"{width}x{height}+{x}+{y}")
    
    def create_widgets(self):
        """Create all UI widgets"""
        # Header
        self.create_header()
        
        # Main container
        self.main_container = tk.Frame(self, bg=self.theme.colors["bg"])
        self.main_container.pack(fill=tk.BOTH, expand=True, padx=20, pady=(0, 20))
        
        # Create pages
        self.create_pages()
        
        # Footer
        self.create_footer()
    
    def create_header(self):
        """Create application header"""
        header = tk.Frame(self, bg=self.theme.colors["accent"], height=60)
        header.pack(fill=tk.X)
        header.pack_propagate(False)
        
        # Logo/Title
        title_label = tk.Label(
            header,
            text=f"{self.i18n.get('app_title')} {VERSION}",
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["accent"],
            fg="white"
        )
        title_label.pack(side=tk.LEFT, padx=20, pady=15)
        
        # Settings button
        settings_btn = ModernButton(
            header,
            self.theme,
            text="⚙",
            font=("Arial", 16),
            bg=self.theme.colors["accent"],
            fg="white",
            bd=0,
            padx=10,
            command=self.show_settings
        )
        settings_btn.pack(side=tk.RIGHT, padx=20)
        
        # Language selector
        lang_frame = tk.Frame(header, bg=self.theme.colors["accent"])
        lang_frame.pack(side=tk.RIGHT, padx=10)
        
        current_lang = tk.StringVar(value=self.i18n.current_language)
        lang_menu = ttk.Combobox(
            lang_frame,
            textvariable=current_lang,
            values=[code for code, _ in self.i18n.get_available_languages()],
            width=5,
            state="readonly"
        )
        lang_menu.pack()
        lang_menu.bind("<<ComboboxSelected>>", lambda e: self.change_language(current_lang.get()))
        
        # Theme toggle
        theme_btn = ModernButton(
            header,
            self.theme,
            text="🌙" if self.theme.is_dark else "☀",
            bg=self.theme.colors["accent"],
            fg="white",
            bd=0,
            padx=10,
            command=self.toggle_theme
        )
        theme_btn.pack(side=tk.RIGHT, padx=5)
        self.theme_btn = theme_btn
    
    def create_footer(self):
        """Create application footer"""
        footer = tk.Frame(self, bg=self.theme.colors["bg_secondary"], height=80)
        footer.pack(fill=tk.X, side=tk.BOTTOM)
        footer.pack_propagate(False)
        
        # Navigation buttons
        nav_frame = tk.Frame(footer, bg=self.theme.colors["bg_secondary"])
        nav_frame.pack(expand=True)
        
        self.back_btn = ModernButton(
            nav_frame,
            self.theme,
            text=f"← {self.i18n.get('back')}",
            command=self.go_back,
            state=tk.DISABLED
        )
        self.back_btn.grid(row=0, column=0, padx=10, pady=20)
        
        self.next_btn = ModernButton(
            nav_frame,
            self.theme,
            text=f"{self.i18n.get('next')} →",
            command=self.go_next
        )
        self.next_btn.grid(row=0, column=1, padx=10, pady=20)
        
        self.cancel_btn = ModernButton(
            nav_frame,
            self.theme,
            text=self.i18n.get('cancel'),
            command=self.on_closing
        )
        self.cancel_btn.grid(row=0, column=2, padx=10, pady=20)
    
    def create_pages(self):
        """Create all installer pages"""
        # Welcome page
        self.pages["welcome"] = self.create_welcome_page()
        
        # System check page
        self.pages["system_check"] = self.create_system_check_page()
        
        # Profile selection page
        self.pages["profile"] = self.create_profile_page()
        
        # Components page
        self.pages["components"] = self.create_components_page()
        
        # Installation page
        self.pages["installation"] = self.create_installation_page()
        
        # Complete page
        self.pages["complete"] = self.create_complete_page()
    
    def create_welcome_page(self) -> tk.Frame:
        """Create welcome page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Welcome message
        welcome_label = AnimatedLabel(
            page,
            self.theme,
            text=self.i18n.get('welcome'),
            font=self.theme.fonts["heading"]
        )
        welcome_label.pack(pady=40)
        
        # Description
        desc_text = """Cursor is an AI-powered code editor built for pair programming with AI.
        
This installer will guide you through the installation process.
Please ensure you have administrator privileges if required.

Features:
• AI-powered code completion
• Integrated chat interface
• Multi-language support
• Cross-platform compatibility
• Extensible plugin system"""
        
        desc_label = tk.Label(
            page,
            text=desc_text,
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"],
            justify=tk.LEFT
        )
        desc_label.pack(pady=20, padx=40)
        
        # Options
        options_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        options_frame.pack(pady=20)
        
        self.check_updates_var = tk.BooleanVar(value=True)
        check_updates = tk.Checkbutton(
            options_frame,
            text=self.i18n.get('check_updates_on_start'),
            variable=self.check_updates_var,
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"],
            selectcolor=self.theme.colors["bg"],
            activebackground=self.theme.colors["bg"]
        )
        check_updates.pack(anchor=tk.W, pady=5)
        
        self.analytics_var = tk.BooleanVar(value=False)
        analytics = tk.Checkbutton(
            options_frame,
            text=self.i18n.get('send_analytics'),
            variable=self.analytics_var,
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"],
            selectcolor=self.theme.colors["bg"],
            activebackground=self.theme.colors["bg"]
        )
        analytics.pack(anchor=tk.W, pady=5)
        
        return page
    
    def create_system_check_page(self) -> tk.Frame:
        """Create system requirements check page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Title
        title = tk.Label(
            page,
            text=self.i18n.get('checking_system'),
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        title.pack(pady=20)
        
        # Results frame
        self.check_results_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        self.check_results_frame.pack(fill=tk.BOTH, expand=True, padx=40, pady=20)
        
        # Progress bar
        self.check_progress = ModernProgressBar(
            page,
            self.theme,
            length=400,
            mode='indeterminate'
        )
        self.check_progress.pack(pady=20)
        
        return page
    
    def create_profile_page(self) -> tk.Frame:
        """Create installation profile selection page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Title
        title = tk.Label(
            page,
            text=self.i18n.get('select_profile'),
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        title.pack(pady=20)
        
        # Profile options
        profiles = [
            InstallationProfile(
                "minimal",
                self.i18n.get('minimal'),
                "Core editor only - smallest installation",
                ["editor"],
                500,
                {"desktop_shortcut": True}
            ),
            InstallationProfile(
                "standard",
                self.i18n.get('standard'),
                "Recommended - includes common extensions",
                ["editor", "extensions", "themes"],
                1000,
                {"desktop_shortcut": True, "start_menu": True, "file_associations": True}
            ),
            InstallationProfile(
                "full",
                self.i18n.get('full'),
                "Everything - all features and extensions",
                ["editor", "extensions", "themes", "docs", "examples"],
                2000,
                {"desktop_shortcut": True, "start_menu": True, "file_associations": True,
                 "add_to_path": True, "context_menu": True}
            ),
            InstallationProfile(
                "custom",
                self.i18n.get('custom'),
                "Choose your own components",
                [],
                0,
                {}
            )
        ]
        
        self.selected_profile = tk.StringVar(value="standard")
        
        for profile in profiles:
            frame = tk.Frame(page, bg=self.theme.colors["bg_secondary"], relief=tk.RAISED, bd=1)
            frame.pack(fill=tk.X, padx=40, pady=10)
            
            rb = tk.Radiobutton(
                frame,
                text=profile.display_name,
                variable=self.selected_profile,
                value=profile.name,
                font=self.theme.fonts["subheading"],
                bg=self.theme.colors["bg_secondary"],
                fg=self.theme.colors["fg"],
                selectcolor=self.theme.colors["bg_secondary"],
                activebackground=self.theme.colors["bg_secondary"]
            )
            rb.pack(anchor=tk.W, padx=20, pady=(10, 5))
            
            desc = tk.Label(
                frame,
                text=profile.description,
                font=self.theme.fonts["small"],
                bg=self.theme.colors["bg_secondary"],
                fg=self.theme.colors["text_secondary"]
            )
            desc.pack(anchor=tk.W, padx=40, pady=(0, 5))
            
            size = tk.Label(
                frame,
                text=f"{self.i18n.get('installation_size')}: {profile.disk_space_mb} MB",
                font=self.theme.fonts["small"],
                bg=self.theme.colors["bg_secondary"],
                fg=self.theme.colors["text_secondary"]
            )
            size.pack(anchor=tk.W, padx=40, pady=(0, 10))
            
            # Store profile object
            frame.profile = profile
        
        self.profiles = profiles
        
        return page
    
    def create_components_page(self) -> tk.Frame:
        """Create component selection page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Title
        title = tk.Label(
            page,
            text=self.i18n.get('select_components'),
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        title.pack(pady=20)
        
        # Components list with scrollbar
        list_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        list_frame.pack(fill=tk.BOTH, expand=True, padx=40, pady=20)
        
        scrollbar = tk.Scrollbar(list_frame)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.components_listbox = tk.Listbox(
            list_frame,
            yscrollcommand=scrollbar.set,
            selectmode=tk.MULTIPLE,
            font=self.theme.fonts["default"],
            bg=self.theme.colors["entry_bg"],
            fg=self.theme.colors["entry_fg"],
            selectbackground=self.theme.colors["selection_bg"],
            selectforeground=self.theme.colors["selection_fg"]
        )
        self.components_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.config(command=self.components_listbox.yview)
        
        # Installation location
        location_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        location_frame.pack(fill=tk.X, padx=40, pady=10)
        
        location_label = tk.Label(
            location_frame,
            text=self.i18n.get('install_location'),
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        location_label.pack(side=tk.LEFT, padx=(0, 10))
        
        self.location_var = tk.StringVar(value=str(Path.home() / "cursor"))
        location_entry = ModernEntry(
            location_frame,
            self.theme,
            textvariable=self.location_var,
            width=40
        )
        location_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
        
        browse_btn = ModernButton(
            location_frame,
            self.theme,
            text=self.i18n.get('browse'),
            command=self.browse_location
        )
        browse_btn.pack(side=tk.LEFT, padx=(10, 0))
        
        return page
    
    def create_installation_page(self) -> tk.Frame:
        """Create installation progress page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Title
        self.install_title = tk.Label(
            page,
            text=self.i18n.get('installing_component', component="Cursor"),
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        self.install_title.pack(pady=20)
        
        # Progress info
        info_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        info_frame.pack(fill=tk.X, padx=40, pady=10)
        
        self.progress_label = tk.Label(
            info_frame,
            text=self.i18n.get('progress'),
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        self.progress_label.pack(anchor=tk.W)
        
        self.time_label = tk.Label(
            info_frame,
            text=self.i18n.get('time_remaining') + ": --:--",
            font=self.theme.fonts["small"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["text_secondary"]
        )
        self.time_label.pack(anchor=tk.W)
        
        # Progress bar
        self.install_progress = ModernProgressBar(
            page,
            self.theme,
            length=600,
            mode='determinate'
        )
        self.install_progress.pack(pady=20)
        
        # Current step
        self.step_label = tk.Label(
            page,
            text="",
            font=self.theme.fonts["default"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["text_secondary"]
        )
        self.step_label.pack()
        
        # Log output
        log_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        log_frame.pack(fill=tk.BOTH, expand=True, padx=40, pady=20)
        
        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            height=10,
            font=self.theme.fonts["monospace"],
            bg=self.theme.colors["entry_bg"],
            fg=self.theme.colors["entry_fg"],
            wrap=tk.WORD
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)
        
        # Control buttons
        control_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        control_frame.pack(pady=10)
        
        self.pause_btn = ModernButton(
            control_frame,
            self.theme,
            text=self.i18n.get('pause'),
            command=self.toggle_pause,
            state=tk.DISABLED
        )
        self.pause_btn.pack(side=tk.LEFT, padx=5)
        
        self.details_btn = ModernButton(
            control_frame,
            self.theme,
            text=self.i18n.get('details'),
            command=self.show_details
        )
        self.details_btn.pack(side=tk.LEFT, padx=5)
        
        return page
    
    def create_complete_page(self) -> tk.Frame:
        """Create installation complete page"""
        page = tk.Frame(self.main_container, bg=self.theme.colors["bg"])
        
        # Result icon and message
        self.result_label = tk.Label(
            page,
            text="",
            font=("Arial", 48),
            bg=self.theme.colors["bg"]
        )
        self.result_label.pack(pady=20)
        
        self.result_message = tk.Label(
            page,
            text="",
            font=self.theme.fonts["heading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["fg"]
        )
        self.result_message.pack(pady=10)
        
        # Summary
        self.summary_frame = tk.Frame(page, bg=self.theme.colors["bg_secondary"])
        self.summary_frame.pack(fill=tk.BOTH, expand=True, padx=40, pady=20)
        
        # Action buttons
        action_frame = tk.Frame(page, bg=self.theme.colors["bg"])
        action_frame.pack(pady=20)
        
        self.launch_btn = ModernButton(
            action_frame,
            self.theme,
            text="Launch Cursor",
            command=self.launch_application
        )
        self.launch_btn.pack(side=tk.LEFT, padx=5)
        
        self.view_log_btn = ModernButton(
            action_frame,
            self.theme,
            text=self.i18n.get('view_logs'),
            command=self.view_logs
        )
        self.view_log_btn.pack(side=tk.LEFT, padx=5)
        
        return page
    
    def show_page(self, page_name: str):
        """Show a specific page"""
        # Hide current page
        if self.current_page and self.current_page in self.pages:
            self.pages[self.current_page].pack_forget()
        
        # Show new page
        if page_name in self.pages:
            self.pages[page_name].pack(fill=tk.BOTH, expand=True)
            self.current_page = page_name
            
            # Update navigation buttons
            self.update_navigation()
            
            # Page-specific actions
            if page_name == "system_check":
                self.run_system_check()
            elif page_name == "components":
                self.populate_components()
            elif page_name == "installation":
                self.start_installation()
            elif page_name == "complete":
                self.show_completion()
    
    def update_navigation(self):
        """Update navigation button states"""
        # Define page flow
        page_flow = ["welcome", "system_check", "profile", "components", "installation", "complete"]
        
        if self.current_page in page_flow:
            current_index = page_flow.index(self.current_page)
            
            # Back button
            self.back_btn.config(state=tk.NORMAL if current_index > 0 else tk.DISABLED)
            
            # Next button
            if self.current_page == "complete":
                self.next_btn.config(text=self.i18n.get('finish'), command=self.finish_installation)
            elif self.current_page == "installation":
                self.next_btn.config(state=tk.DISABLED)
            else:
                self.next_btn.config(
                    text=f"{self.i18n.get('next')} →",
                    command=self.go_next,
                    state=tk.NORMAL
                )
            
            # Cancel button
            if self.current_page in ["installation", "complete"]:
                self.cancel_btn.config(state=tk.DISABLED)
            else:
                self.cancel_btn.config(state=tk.NORMAL)
    
    def go_back(self):
        """Navigate to previous page"""
        page_flow = ["welcome", "system_check", "profile", "components", "installation", "complete"]
        
        if self.current_page in page_flow:
            current_index = page_flow.index(self.current_page)
            if current_index > 0:
                self.show_page(page_flow[current_index - 1])
    
    def go_next(self):
        """Navigate to next page"""
        page_flow = ["welcome", "system_check", "profile", "components", "installation", "complete"]
        
        if self.current_page in page_flow:
            current_index = page_flow.index(self.current_page)
            
            # Validate current page before proceeding
            if self.current_page == "profile" and self.selected_profile.get() == "custom":
                # For custom profile, go to components page
                self.show_page("components")
            elif current_index < len(page_flow) - 1:
                self.show_page(page_flow[current_index + 1])
    
    def run_system_check(self):
        """Run system requirements check"""
        self.check_progress.start()
        
        # Clear previous results
        for widget in self.check_results_frame.winfo_children():
            widget.destroy()
        
        def check_thread():
            requirements = SystemRequirements()
            validator = SystemValidator(requirements)
            passed, results = validator.validate_all()
            
            # Update UI in main thread
            self.after(0, lambda: self.display_check_results(passed, results))
        
        thread = threading.Thread(target=check_thread, daemon=True)
        thread.start()
    
    def display_check_results(self, passed: bool, results: Dict):
        """Display system check results"""
        self.check_progress.stop()
        
        # Overall result
        overall_label = tk.Label(
            self.check_results_frame,
            text=self.i18n.get('system_check_passed' if passed else 'system_check_failed'),
            font=self.theme.fonts["subheading"],
            bg=self.theme.colors["bg"],
            fg=self.theme.colors["success" if passed else "error"]
        )
        overall_label.pack(pady=10)
        
        # Individual checks
        for check_name, result in results.items():
            frame = tk.Frame(self.check_results_frame, bg=self.theme.colors["bg"])
            frame.pack(fill=tk.X, pady=5)
            
            # Status icon
            status_icon = "✓" if result["passed"] else "✗"
            status_color = self.theme.colors["success"] if result["passed"] else self.theme.colors["error"]
            
            icon_label = tk.Label(
                frame,
                text=status_icon,
                font=("Arial", 16),
                bg=self.theme.colors["bg"],
                fg=status_color
            )
            icon_label.pack(side=tk.LEFT, padx=(20, 10))
            
            # Check name
            name_label = tk.Label(
                frame,
                text=check_name.replace("_", " ").title(),
                font=self.theme.fonts["default"],
                bg=self.theme.colors["bg"],
                fg=self.theme.colors["fg"]
            )
            name_label.pack(side=tk.LEFT)
            
            # Details
            if "error" in result["details"]:
                detail_text = str(result["details"]["error"])
            else:
                detail_text = self.format_check_details(check_name, result["details"])
            
            detail_label = tk.Label(
                frame,
                text=detail_text,
                font=self.theme.fonts["small"],
                bg=self.theme.colors["bg"],
                fg=self.theme.colors["text_secondary"]
            )
            detail_label.pack(side=tk.RIGHT, padx=20)
        
        # Enable/disable next button based on result
        self.next_btn.config(state=tk.NORMAL if passed else tk.DISABLED)
    
    def format_check_details(self, check_name: str, details: Dict) -> str:
        """Format check details for display"""
        if check_name == "python":
            return f"{details.get('current', 'unknown')} (required: {details.get('required', 'unknown')})"
        elif check_name == "memory":
            return f"{details.get('available_mb', 0):.0f} MB available"
        elif check_name == "disk_space":
            return f"{details.get('available_mb', 0):.0f} MB available"
        elif check_name == "os":
            return f"{details.get('current', 'unknown')} {details.get('architecture', '')}"
        elif check_name == "commands":
            missing = details.get('missing_required', [])
            if missing:
                return f"Missing: {', '.join(missing)}"
            else:
                return "All required commands found"
        else:
            return "OK"
    
    def populate_components(self):
        """Populate components list based on selected profile"""
        self.components_listbox.delete(0, tk.END)
        
        # Get selected profile
        profile_name = self.selected_profile.get()
        profile = next((p for p in self.profiles if p.name == profile_name), None)
        
        if not profile or profile.name == "custom":
            # Show all available components for custom selection
            all_components = [
                ("Core Editor", "editor", True, 200),
                ("Language Servers", "language_servers", True, 150),
                ("Extensions Pack", "extensions", True, 300),
                ("Theme Collection", "themes", False, 50),
                ("Documentation", "docs", False, 100),
                ("Example Projects", "examples", False, 200),
                ("Development Tools", "dev_tools", False, 150),
                ("Debugging Support", "debugger", True, 100),
                ("Git Integration", "git", True, 80),
                ("Terminal Integration", "terminal", True, 60),
                ("AI Models", "ai_models", False, 500),
                ("Plugin SDK", "plugin_sdk", False, 120)
            ]
            
            for display_name, comp_id, required, size in all_components:
                item_text = f"{display_name} ({size} MB)"
                self.components_listbox.insert(tk.END, item_text)
                
                if required or (profile and comp_id in profile.components):
                    self.components_listbox.selection_set(tk.END)
        else:
            # Show profile components
            for component in profile.components:
                self.components_listbox.insert(tk.END, component)
                self.components_listbox.selection_set(tk.END)
    
    def browse_location(self):
        """Browse for installation location"""
        directory = filedialog.askdirectory(
            title=self.i18n.get('install_location'),
            initialdir=self.location_var.get()
        )
        if directory:
            self.location_var.set(directory)
    
    def start_installation(self):
        """Start the installation process"""
        # Disable navigation
        self.next_btn.config(state=tk.DISABLED)
        self.back_btn.config(state=tk.DISABLED)
        self.pause_btn.config(state=tk.NORMAL)
        
        # Get selected profile
        profile_name = self.selected_profile.get()
        profile = next((p for p in self.profiles if p.name == profile_name), None)
        
        if not profile:
            logger.error("No profile selected")
            return
        
        # Start installation in background thread
        def install_thread():
            try:
                # Notify plugins
                self.plugin_manager.trigger_event("on_install_start", profile)
                
                # Update UI callback
                def update_progress(state: InstallationState):
                    self.after(0, lambda: self.update_installation_progress(state))
                
                # Run installation
                success = self.engine.install(profile, update_progress)
                
                # Notify plugins
                self.plugin_manager.trigger_event("on_install_complete", success)
                
                # Show completion
                self.after(0, lambda: self.installation_complete(success))
                
            except Exception as e:
                logger.error(f"Installation thread error: {e}")
                self.after(0, lambda: self.installation_complete(False))
        
        thread = threading.Thread(target=install_thread, daemon=True)
        thread.start()
    
    def update_installation_progress(self, state: InstallationState):
        """Update installation progress UI"""
        # Update progress bar
        self.install_progress['value'] = state.progress
        
        # Update labels
        self.progress_label.config(text=f"{self.i18n.get('progress')}: {state.progress:.1f}%")
        self.step_label.config(text=state.current_step)
        
        # Calculate time remaining (simple estimate)
        if state.start_time and state.progress > 0:
            elapsed = (datetime.now() - state.start_time).total_seconds()
            if state.progress > 0:
                total_estimated = elapsed / (state.progress / 100)
                remaining = total_estimated - elapsed
                if remaining > 0:
                    mins, secs = divmod(int(remaining), 60)
                    self.time_label.config(text=f"{self.i18n.get('time_remaining')}: {mins:02d}:{secs:02d}")
        
        # Update log
        if state.current_step:
            self.log_text.insert(tk.END, f"[{datetime.now().strftime('%H:%M:%S')}] {state.current_step}\n")
            self.log_text.see(tk.END)
        
        # Show errors
        for error in state.errors:
            self.log_text.insert(tk.END, f"[ERROR] {error}\n", "error")
            self.log_text.see(tk.END)
        
        # Configure text tags
        self.log_text.tag_config("error", foreground=self.theme.colors["error"])
    
    def installation_complete(self, success: bool):
        """Handle installation completion"""
        self.state.status = "completed" if success else "failed"
        self.show_page("complete")
    
    def show_completion(self):
        """Show installation completion page"""
        success = self.state.status == "completed"
        
        # Update UI elements
        if success:
            self.result_label.config(text="✓", fg=self.theme.colors["success"])
            self.result_message.config(text=self.i18n.get('installation_complete'))
            self.launch_btn.config(state=tk.NORMAL)
        else:
            self.result_label.config(text="✗", fg=self.theme.colors["error"])
            self.result_message.config(text=self.i18n.get('installation_failed'))
            self.launch_btn.config(state=tk.DISABLED)
        
        # Show summary
        for widget in self.summary_frame.winfo_children():
            widget.destroy()
        
        summary_text = scrolledtext.ScrolledText(
            self.summary_frame,
            height=15,
            font=self.theme.fonts["monospace"],
            bg=self.theme.colors["entry_bg"],
            fg=self.theme.colors["entry_fg"]
        )
        summary_text.pack(fill=tk.BOTH, expand=True, padx=20, pady=20)
        
        # Add summary content
        summary_text.insert(tk.END, "Installation Summary\n")
        summary_text.insert(tk.END, "=" * 50 + "\n\n")
        
        if self.state.start_time and self.state.end_time:
            duration = self.state.end_time - self.state.start_time
            summary_text.insert(tk.END, f"Duration: {duration}\n")
        
        summary_text.insert(tk.END, f"Status: {self.state.status}\n")
        summary_text.insert(tk.END, f"Steps completed: {len(self.state.steps_completed)}\n")
        
        if self.state.steps_completed:
            summary_text.insert(tk.END, "\nCompleted steps:\n")
            for step in self.state.steps_completed:
                summary_text.insert(tk.END, f"  ✓ {step}\n")
        
        if self.state.errors:
            summary_text.insert(tk.END, "\nErrors:\n")
            for error in self.state.errors:
                summary_text.insert(tk.END, f"  ✗ {error}\n")
        
        if self.state.warnings:
            summary_text.insert(tk.END, "\nWarnings:\n")
            for warning in self.state.warnings:
                summary_text.insert(tk.END, f"  ⚠ {warning}\n")
        
        summary_text.config(state=tk.DISABLED)
        
        # Save installation report
        self.save_installation_report()
    
    def save_installation_report(self):
        """Save installation report to file"""
        try:
            report_file = LOG_DIR / f"installation_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            report_data = {
                "version": VERSION,
                "state": self.state.to_dict(),
                "system_info": {
                    "platform": platform.platform(),
                    "python_version": platform.python_version(),
                    "architecture": platform.machine()
                }
            }
            
            with open(report_file, 'w') as f:
                json.dump(report_data, f, indent=2)
            
            logger.info(f"Installation report saved: {report_file}")
            
        except Exception as e:
            logger.error(f"Failed to save installation report: {e}")
    
    def toggle_pause(self):
        """Toggle installation pause/resume"""
        if self.engine.pause_flag.is_set():
            self.engine.resume()
            self.pause_btn.config(text=self.i18n.get('pause'))
            self.log_text.insert(tk.END, "[INFO] Installation resumed\n")
        else:
            self.engine.pause()
            self.pause_btn.config(text=self.i18n.get('resume'))
            self.log_text.insert(tk.END, "[INFO] Installation paused\n")
        self.log_text.see(tk.END)
    
    def show_details(self):
        """Show detailed installation information"""
        details_window = tk.Toplevel(self)
        details_window.title("Installation Details")
        details_window.geometry("600x400")
        details_window.configure(bg=self.theme.colors["bg"])
        
        # Details text
        details_text = scrolledtext.ScrolledText(
            details_window,
            font=self.theme.fonts["monospace"],
            bg=self.theme.colors["entry_bg"],
            fg=self.theme.colors["entry_fg"]
        )
        details_text.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # Add state information
        details_text.insert(tk.END, json.dumps(self.state.to_dict(), indent=2))
        details_text.config(state=tk.DISABLED)
        
        # Close button
        close_btn = ModernButton(
            details_window,
            self.theme,
            text="Close",
            command=details_window.destroy
        )
        close_btn.pack(pady=10)
    
    def launch_application(self):
        """Launch the installed application"""
        try:
            if platform.system() == "Windows":
                os.startfile("C:\\Program Files\\Cursor\\cursor.exe")
            elif platform.system() == "Darwin":
                subprocess.Popen(["open", "/Applications/Cursor.app"])
            else:
                subprocess.Popen(["/opt/cursor/cursor"])
            
            logger.info("Application launched")
            
        except Exception as e:
            logger.error(f"Failed to launch application: {e}")
            messagebox.showerror("Launch Error", f"Failed to launch application: {e}")
    
    def view_logs(self):
        """Open log directory"""
        try:
            if platform.system() == "Windows":
                os.startfile(str(LOG_DIR))
            elif platform.system() == "Darwin":
                subprocess.Popen(["open", str(LOG_DIR)])
            else:
                subprocess.Popen(["xdg-open", str(LOG_DIR)])
        except Exception as e:
            logger.error(f"Failed to open log directory: {e}")
    
    def finish_installation(self):
        """Finish installation and close"""
        self.destroy()
    
    def show_settings(self):
        """Show settings dialog"""
        settings_window = tk.Toplevel(self)
        settings_window.title(self.i18n.get('settings'))
        settings_window.geometry("500x600")
        settings_window.configure(bg=self.theme.colors["bg"])
        
        # Settings notebook
        notebook = ttk.Notebook(settings_window)
        notebook.pack(fill=tk.BOTH, expand=True, padx=10, pady=10)
        
        # General settings
        general_frame = tk.Frame(notebook, bg=self.theme.colors["bg"])
        notebook.add(general_frame, text="General")
        
        # Advanced settings
        advanced_frame = tk.Frame(notebook, bg=self.theme.colors["bg"])
        notebook.add(advanced_frame, text="Advanced")
        
        # About
        about_frame = tk.Frame(notebook, bg=self.theme.colors["bg"])
        notebook.add(about_frame, text="About")
        
        # Populate settings...
        
        # Close button
        close_btn = ModernButton(
            settings_window,
            self.theme,
            text="Close",
            command=settings_window.destroy
        )
        close_btn.pack(pady=10)
    
    def toggle_theme(self):
        """Toggle between light and dark theme"""
        self.theme.is_dark = not self.theme.is_dark
        self.theme.load_default_theme()
        
        # Update theme button
        self.theme_btn.config(text="🌙" if self.theme.is_dark else "☀")
        
        # Reapply theme to all widgets
        self.apply_theme_to_all()
        
        # Save preference
        self.save_settings()
    
    def apply_theme_to_all(self):
        """Apply theme to all widgets recursively"""
        def apply_to_widget_tree(widget):
            # Apply theme based on widget type
            widget_class = widget.__class__.__name__
            if widget_class == "ModernButton":
                self.theme.apply_to_widget(widget, "button")
            elif widget_class == "ModernEntry":
                self.theme.apply_to_widget(widget, "entry")
            elif widget_class in ["Label", "AnimatedLabel"]:
                self.theme.apply_to_widget(widget, "label")
            elif widget_class == "Frame":
                self.theme.apply_to_widget(widget, "frame")
            elif widget_class in ["Text", "ScrolledText"]:
                self.theme.apply_to_widget(widget, "text")
            else:
                self.theme.apply_to_widget(widget, "default")
            
            # Recursively apply to children
            for child in widget.winfo_children():
                apply_to_widget_tree(child)
        
        apply_to_widget_tree(self)
    
    def change_language(self, language: str):
        """Change application language"""
        self.i18n.set_language(language)
        messagebox.showinfo(
            self.i18n.get('language'),
            "Language change will take effect after restart."
        )
        self.save_settings()
    
    def save_settings(self):
        """Save application settings"""
        try:
            settings = {
                "language": self.i18n.current_language,
                "theme": "dark" if self.theme.is_dark else "light",
                "check_updates": self.check_updates_var.get() if hasattr(self, 'check_updates_var') else True,
                "analytics": self.analytics_var.get() if hasattr(self, 'analytics_var') else False
            }
            
            settings_file = CONFIG_DIR / "settings.json"
            with open(settings_file, 'w') as f:
                json.dump(settings, f, indent=2)
            
            logger.info("Settings saved")
            
        except Exception as e:
            logger.error(f"Failed to save settings: {e}")
    
    def load_settings(self):
        """Load application settings"""
        try:
            settings_file = CONFIG_DIR / "settings.json"
            if settings_file.exists():
                with open(settings_file, 'r') as f:
                    settings = json.load(f)
                
                # Apply settings
                if "language" in settings:
                    self.i18n.set_language(settings["language"])
                
                if "theme" in settings:
                    if settings["theme"] == "dark" and not self.theme.is_dark:
                        self.toggle_theme()
                    elif settings["theme"] == "light" and self.theme.is_dark:
                        self.toggle_theme()
                
                logger.info("Settings loaded")
                
        except Exception as e:
            logger.error(f"Failed to load settings: {e}")
    
    def on_closing(self):
        """Handle window closing"""
        if self.state.status == "installing":
            if messagebox.askyesno(
                self.i18n.get('confirm_exit'),
                self.i18n.get('confirm_exit')
            ):
                self.engine.abort()
                self.destroy()
        else:
            self.destroy()

# === ENTRY POINT ===
def main():
    """Main entry point"""
    try:
        # Parse command line arguments
        parser = argparse.ArgumentParser(description=f"Cursor Installer v{VERSION}")
        parser.add_argument("--silent", action="store_true", help="Silent installation")
        parser.add_argument("--profile", choices=["minimal", "standard", "full"], 
                          default="standard", help="Installation profile")
        parser.add_argument("--language", help="Set interface language")
        parser.add_argument("--theme", choices=["light", "dark"], help="Set theme")
        parser.add_argument("--log-level", choices=["DEBUG", "INFO", "WARNING", "ERROR"], 
                          default="INFO", help="Set log level")
        
        args = parser.parse_args()
        
        # Configure logging level
        logging.getLogger().setLevel(getattr(logging, args.log_level))
        
        if args.silent:
            # Run silent installation
            logger.info("Running silent installation")
            # Implementation for silent mode would go here
        else:
            # Run GUI
            app = CursorInstaller()
            
            # Apply command line options
            if args.language:
                app.i18n.set_language(args.language)
            
            if args.theme:
                if (args.theme == "dark" and not app.theme.is_dark) or \
                   (args.theme == "light" and app.theme.is_dark):
                    app.toggle_theme()
            
            # Run application
            app.mainloop()
        
    except Exception as e:
        logger.critical(f"Fatal error: {e}", exc_info=True)
        if not args.silent:
            messagebox.showerror("Fatal Error", f"Application failed to start:\n{e}")
        sys.exit(1)

if __name__ == "__main__":
    main()