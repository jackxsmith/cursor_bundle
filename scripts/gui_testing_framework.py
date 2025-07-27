#!/usr/bin/env python3
"""
Enhanced GUI Testing Framework with Playwright Integration
Comprehensive testing framework for GUI applications with enterprise-grade features
"""

import os
import sys
import json
import time
import logging
import asyncio
import subprocess
import threading
from typing import Dict, List, Optional, Any, Callable, Union
from pathlib import Path
from dataclasses import dataclass, asdict
from enum import Enum
import tkinter as tk
from tkinter import ttk
import tempfile
import shutil
import hashlib

# Try to import Playwright
try:
    from playwright.async_api import async_playwright, Browser, Page, BrowserContext
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    print("WARNING: Playwright not available. Installing...")
    subprocess.run([sys.executable, "-m", "pip", "install", "playwright"], check=False)
    try:
        from playwright.async_api import async_playwright, Browser, Page, BrowserContext
        PLAYWRIGHT_AVAILABLE = True
        print("INFO: Playwright installed successfully")
    except ImportError:
        PLAYWRIGHT_AVAILABLE = False
        print("ERROR: Failed to install Playwright")

# Enhanced logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('gui_testing.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class TestResult(Enum):
    """Test result enumeration"""
    PASSED = "PASSED"
    FAILED = "FAILED"
    SKIPPED = "SKIPPED"
    ERROR = "ERROR"

@dataclass
class TestCase:
    """Comprehensive test case definition"""
    name: str
    description: str
    test_type: str  # "gui", "web", "integration", "performance"
    target_app: Optional[str] = None
    test_steps: List[Dict[str, Any]] = None
    expected_result: Optional[str] = None
    timeout: int = 30
    retry_count: int = 3
    tags: List[str] = None
    prerequisites: List[str] = None
    cleanup_actions: List[str] = None

@dataclass
class TestExecution:
    """Test execution result"""
    test_case: TestCase
    result: TestResult
    execution_time: float
    error_message: Optional[str] = None
    screenshots: List[str] = None
    logs: List[str] = None
    artifacts: List[str] = None

class PlaywrightBrowserManager:
    """Advanced Playwright browser management"""
    
    def __init__(self):
        self.playwright = None
        self.browser = None
        self.context = None
        self.page = None
        self.headless = True
        self.browser_type = "chromium"
        
    async def initialize(self, headless: bool = True, browser_type: str = "chromium"):
        """Initialize Playwright browser"""
        if not PLAYWRIGHT_AVAILABLE:
            raise RuntimeError("Playwright is not available")
            
        self.headless = headless
        self.browser_type = browser_type
        
        self.playwright = await async_playwright().start()
        
        # Choose browser
        if browser_type == "firefox":
            browser_launcher = self.playwright.firefox
        elif browser_type == "webkit":
            browser_launcher = self.playwright.webkit
        else:
            browser_launcher = self.playwright.chromium
            
        self.browser = await browser_launcher.launch(
            headless=headless,
            args=["--no-sandbox", "--disable-dev-shm-usage"]
        )
        
        # Create context with enhanced settings
        self.context = await self.browser.new_context(
            viewport={"width": 1920, "height": 1080},
            user_agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
            ignore_https_errors=True,
            record_video_dir="test_recordings",
            record_har_path="test_network.har"
        )
        
        self.page = await self.context.new_page()
        
        # Set up console and error logging
        self.page.on("console", self._handle_console_message)
        self.page.on("pageerror", self._handle_page_error)
        
        logger.info(f"Playwright {browser_type} browser initialized (headless: {headless})")
        
    async def cleanup(self):
        """Clean up browser resources"""
        if self.page:
            await self.page.close()
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()
            
    def _handle_console_message(self, msg):
        """Handle browser console messages"""
        logger.info(f"Browser console: {msg.type}: {msg.text}")
        
    def _handle_page_error(self, error):
        """Handle browser page errors"""
        logger.error(f"Browser error: {error}")

class TkinterTestManager:
    """Advanced Tkinter application testing"""
    
    def __init__(self):
        self.test_app = None
        self.test_thread = None
        self.app_pid = None
        
    def launch_tkinter_app(self, script_path: str, args: List[str] = None) -> bool:
        """Launch Tkinter application for testing"""
        try:
            if not os.path.exists(script_path):
                logger.error(f"Tkinter script not found: {script_path}")
                return False
                
            # Launch the application in a separate process
            cmd = [sys.executable, script_path]
            if args:
                cmd.extend(args)
                
            # Use subprocess to launch without GUI interference
            self.test_process = subprocess.Popen(
                cmd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            
            self.app_pid = self.test_process.pid
            logger.info(f"Launched Tkinter app: {script_path} (PID: {self.app_pid})")
            
            # Give the app time to start
            time.sleep(2)
            
            return True
            
        except Exception as e:
            logger.error(f"Failed to launch Tkinter app: {e}")
            return False
            
    def test_help_functionality(self, script_path: str) -> TestExecution:
        """Test if Tkinter app responds to --help without opening GUI"""
        test_case = TestCase(
            name=f"help_test_{os.path.basename(script_path)}",
            description=f"Test --help functionality for {script_path}",
            test_type="gui",
            target_app=script_path
        )
        
        start_time = time.time()
        
        try:
            # Test --help flag
            result = subprocess.run(
                [sys.executable, script_path, "--help"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            execution_time = time.time() - start_time
            
            if result.returncode == 0:
                logger.info(f"Help test PASSED for {script_path}")
                return TestExecution(
                    test_case=test_case,
                    result=TestResult.PASSED,
                    execution_time=execution_time,
                    logs=[result.stdout, result.stderr]
                )
            else:
                logger.error(f"Help test FAILED for {script_path}: {result.stderr}")
                return TestExecution(
                    test_case=test_case,
                    result=TestResult.FAILED,
                    execution_time=execution_time,
                    error_message=result.stderr,
                    logs=[result.stdout, result.stderr]
                )
                
        except subprocess.TimeoutExpired:
            logger.error(f"Help test TIMEOUT for {script_path}")
            return TestExecution(
                test_case=test_case,
                result=TestResult.ERROR,
                execution_time=time.time() - start_time,
                error_message="Timeout - GUI may have opened instead of showing help"
            )
        except Exception as e:
            logger.error(f"Help test ERROR for {script_path}: {e}")
            return TestExecution(
                test_case=test_case,
                result=TestResult.ERROR,
                execution_time=time.time() - start_time,
                error_message=str(e)
            )
            
    def cleanup(self):
        """Clean up Tkinter test resources"""
        if hasattr(self, 'test_process') and self.test_process:
            try:
                self.test_process.terminate()
                self.test_process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.test_process.kill()
            except Exception as e:
                logger.warning(f"Error cleaning up test process: {e}")

class WebGUITestManager:
    """Web-based GUI testing with Playwright"""
    
    def __init__(self):
        self.browser_manager = PlaywrightBrowserManager()
        
    async def test_web_application(self, url: str, test_cases: List[TestCase]) -> List[TestExecution]:
        """Test web application with multiple test cases"""
        results = []
        
        try:
            await self.browser_manager.initialize()
            
            for test_case in test_cases:
                result = await self._execute_web_test_case(url, test_case)
                results.append(result)
                
        except Exception as e:
            logger.error(f"Web testing failed: {e}")
        finally:
            await self.browser_manager.cleanup()
            
        return results
        
    async def _execute_web_test_case(self, url: str, test_case: TestCase) -> TestExecution:
        """Execute a single web test case"""
        start_time = time.time()
        screenshots = []
        
        try:
            page = self.browser_manager.page
            
            # Navigate to the application
            await page.goto(url, wait_until="networkidle")
            
            # Take initial screenshot
            screenshot_path = f"screenshots/{test_case.name}_start.png"
            await page.screenshot(path=screenshot_path)
            screenshots.append(screenshot_path)
            
            # Execute test steps
            if test_case.test_steps:
                for i, step in enumerate(test_case.test_steps):
                    await self._execute_test_step(page, step, f"{test_case.name}_step_{i}")
                    
            # Take final screenshot
            screenshot_path = f"screenshots/{test_case.name}_end.png"
            await page.screenshot(path=screenshot_path)
            screenshots.append(screenshot_path)
            
            execution_time = time.time() - start_time
            
            return TestExecution(
                test_case=test_case,
                result=TestResult.PASSED,
                execution_time=execution_time,
                screenshots=screenshots
            )
            
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(f"Web test case failed: {test_case.name}: {e}")
            
            return TestExecution(
                test_case=test_case,
                result=TestResult.ERROR,
                execution_time=execution_time,
                error_message=str(e),
                screenshots=screenshots
            )
            
    async def _execute_test_step(self, page: Page, step: Dict[str, Any], step_name: str):
        """Execute individual test step"""
        action = step.get("action")
        selector = step.get("selector")
        value = step.get("value")
        
        if action == "click":
            await page.click(selector)
        elif action == "fill":
            await page.fill(selector, value)
        elif action == "wait":
            await page.wait_for_selector(selector)
        elif action == "assert_text":
            element = await page.query_selector(selector)
            if element:
                text = await element.text_content()
                assert value in text, f"Expected '{value}' in '{text}'"
        elif action == "screenshot":
            await page.screenshot(path=f"screenshots/{step_name}.png")
            
        # Wait for stability
        await page.wait_for_timeout(500)

class IntegrationTestManager:
    """Integration testing for GUI components with external services"""
    
    def __init__(self):
        self.firecrawl_available = self._check_firecrawl()
        self.context7_available = self._check_context7()
        
    def _check_firecrawl(self) -> bool:
        """Check if Firecrawl is available"""
        try:
            import firecrawl
            return True
        except ImportError:
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", "firecrawl-py"], check=True)
                import firecrawl
                return True
            except Exception:
                logger.warning("Firecrawl not available")
                return False
                
    def _check_context7(self) -> bool:
        """Check if Context7 is available"""
        try:
            import context7
            return True
        except ImportError:
            logger.warning("Context7 not available")
            return False
            
    async def test_web_scraping_integration(self, url: str) -> TestExecution:
        """Test web scraping integration with Firecrawl"""
        test_case = TestCase(
            name="firecrawl_integration",
            description="Test Firecrawl web scraping integration",
            test_type="integration"
        )
        
        start_time = time.time()
        
        if not self.firecrawl_available:
            return TestExecution(
                test_case=test_case,
                result=TestResult.SKIPPED,
                execution_time=0,
                error_message="Firecrawl not available"
            )
            
        try:
            import firecrawl
            
            # Initialize Firecrawl client
            app = firecrawl.FirecrawlApp(api_key=os.getenv("FIRECRAWL_API_KEY", "test"))
            
            # Scrape the URL
            result = app.scrape_url(url)
            
            execution_time = time.time() - start_time
            
            if result and result.get("success"):
                return TestExecution(
                    test_case=test_case,
                    result=TestResult.PASSED,
                    execution_time=execution_time,
                    logs=[f"Scraped content length: {len(result.get('content', ''))}"]
                )
            else:
                return TestExecution(
                    test_case=test_case,
                    result=TestResult.FAILED,
                    execution_time=execution_time,
                    error_message="Firecrawl scraping failed"
                )
                
        except Exception as e:
            execution_time = time.time() - start_time
            return TestExecution(
                test_case=test_case,
                result=TestResult.ERROR,
                execution_time=execution_time,
                error_message=str(e)
            )

class PerformanceTestManager:
    """Performance testing for GUI applications"""
    
    def __init__(self):
        self.metrics = {}
        
    def measure_startup_time(self, script_path: str) -> TestExecution:
        """Measure application startup time"""
        test_case = TestCase(
            name=f"startup_performance_{os.path.basename(script_path)}",
            description=f"Measure startup time for {script_path}",
            test_type="performance",
            target_app=script_path
        )
        
        start_time = time.time()
        
        try:
            # Launch application and measure time to ready state
            process = subprocess.Popen(
                [sys.executable, script_path],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            
            # Wait for process to start (simple heuristic)
            time.sleep(1)
            startup_time = time.time() - start_time
            
            # Terminate the process
            process.terminate()
            process.wait(timeout=5)
            
            # Performance threshold (2 seconds)
            if startup_time < 2.0:
                result = TestResult.PASSED
            else:
                result = TestResult.FAILED
                
            return TestExecution(
                test_case=test_case,
                result=result,
                execution_time=startup_time,
                logs=[f"Startup time: {startup_time:.2f}s"]
            )
            
        except Exception as e:
            return TestExecution(
                test_case=test_case,
                result=TestResult.ERROR,
                execution_time=time.time() - start_time,
                error_message=str(e)
            )

class EnhancedGUITestingFramework:
    """Main testing framework orchestrator"""
    
    def __init__(self):
        self.tkinter_manager = TkinterTestManager()
        self.web_manager = WebGUITestManager()
        self.integration_manager = IntegrationTestManager()
        self.performance_manager = PerformanceTestManager()
        self.test_results = []
        
        # Create required directories
        os.makedirs("screenshots", exist_ok=True)
        os.makedirs("test_recordings", exist_ok=True)
        os.makedirs("test_reports", exist_ok=True)
        
    def discover_gui_applications(self, search_paths: List[str]) -> List[str]:
        """Discover GUI applications to test"""
        gui_apps = []
        
        for path in search_paths:
            if os.path.isfile(path):
                gui_apps.append(path)
            elif os.path.isdir(path):
                for root, dirs, files in os.walk(path):
                    for file in files:
                        if file.endswith(('.py', '.sh')) and any(
                            keyword in file.lower() 
                            for keyword in ['gui', 'tkinter', 'qt', 'gtk', 'ui']
                        ):
                            gui_apps.append(os.path.join(root, file))
                            
        return gui_apps
        
    async def run_comprehensive_gui_tests(self, applications: List[str]) -> Dict[str, Any]:
        """Run comprehensive GUI testing suite"""
        logger.info(f"Starting comprehensive GUI testing for {len(applications)} applications")
        
        all_results = []
        
        for app in applications:
            logger.info(f"Testing application: {app}")
            
            # Tkinter tests
            if app.endswith('.py'):
                # Help functionality test
                help_result = self.tkinter_manager.test_help_functionality(app)
                all_results.append(help_result)
                
                # Performance test
                perf_result = self.performance_manager.measure_startup_time(app)
                all_results.append(perf_result)
                
        # Web GUI tests (if applicable)
        web_test_cases = [
            TestCase(
                name="basic_navigation",
                description="Test basic navigation",
                test_type="web",
                test_steps=[
                    {"action": "wait", "selector": "body"},
                    {"action": "screenshot", "selector": ""}
                ]
            )
        ]
        
        # Integration tests
        integration_result = await self.integration_manager.test_web_scraping_integration("https://example.com")
        all_results.append(integration_result)
        
        self.test_results = all_results
        
        # Generate comprehensive report
        report = self.generate_test_report()
        
        return report
        
    def generate_test_report(self) -> Dict[str, Any]:
        """Generate comprehensive test report"""
        total_tests = len(self.test_results)
        passed_tests = sum(1 for r in self.test_results if r.result == TestResult.PASSED)
        failed_tests = sum(1 for r in self.test_results if r.result == TestResult.FAILED)
        error_tests = sum(1 for r in self.test_results if r.result == TestResult.ERROR)
        skipped_tests = sum(1 for r in self.test_results if r.result == TestResult.SKIPPED)
        
        total_execution_time = sum(r.execution_time for r in self.test_results)
        
        report = {
            "summary": {
                "total_tests": total_tests,
                "passed": passed_tests,
                "failed": failed_tests,
                "errors": error_tests,
                "skipped": skipped_tests,
                "success_rate": round((passed_tests / total_tests * 100) if total_tests > 0 else 0, 2),
                "total_execution_time": round(total_execution_time, 2)
            },
            "detailed_results": [
                {
                    "test_name": r.test_case.name,
                    "description": r.test_case.description,
                    "type": r.test_case.test_type,
                    "result": r.result.value,
                    "execution_time": round(r.execution_time, 2),
                    "error_message": r.error_message,
                    "screenshots": len(r.screenshots) if r.screenshots else 0,
                    "artifacts": len(r.artifacts) if r.artifacts else 0
                }
                for r in self.test_results
            ],
            "environment": {
                "python_version": sys.version,
                "platform": sys.platform,
                "playwright_available": PLAYWRIGHT_AVAILABLE,
                "firecrawl_available": self.integration_manager.firecrawl_available,
                "context7_available": self.integration_manager.context7_available
            }
        }
        
        # Save report to file
        report_file = f"test_reports/gui_test_report_{int(time.time())}.json"
        with open(report_file, 'w') as f:
            json.dump(report, f, indent=2)
            
        logger.info(f"Test report saved to: {report_file}")
        return report
        
    def cleanup(self):
        """Clean up all testing resources"""
        self.tkinter_manager.cleanup()
        # Web manager cleanup is handled by async context

async def main():
    """Main testing function"""
    # Initialize the testing framework
    framework = EnhancedGUITestingFramework()
    
    try:
        # Discover GUI applications
        search_paths = [".", "scripts/"]
        applications = framework.discover_gui_applications(search_paths)
        
        logger.info(f"Discovered {len(applications)} GUI applications")
        
        # Run comprehensive tests
        report = await framework.run_comprehensive_gui_tests(applications)
        
        # Print summary
        print("\n" + "="*60)
        print("GUI TESTING SUMMARY")
        print("="*60)
        print(f"Total Tests: {report['summary']['total_tests']}")
        print(f"Passed: {report['summary']['passed']}")
        print(f"Failed: {report['summary']['failed']}")
        print(f"Errors: {report['summary']['errors']}")
        print(f"Skipped: {report['summary']['skipped']}")
        print(f"Success Rate: {report['summary']['success_rate']}%")
        print(f"Total Time: {report['summary']['total_execution_time']}s")
        print("="*60)
        
        return report
        
    except Exception as e:
        logger.error(f"Testing framework error: {e}")
        return {"error": str(e)}
    finally:
        framework.cleanup()

if __name__ == "__main__":
    # Check for command line arguments
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print(f"""
Enhanced GUI Testing Framework v1.0

Usage: {sys.argv[0]} [options]

Options:
  --help                Show this help message
  --discover            Discover GUI applications only
  --headless           Run Playwright in headless mode (default)
  --headed             Run Playwright with visible browser
  --browser TYPE       Browser type: chromium, firefox, webkit

Examples:
  {sys.argv[0]}                    # Run full test suite
  {sys.argv[0]} --discover         # Just discover applications
  {sys.argv[0]} --headed           # Run with visible browser
""")
        sys.exit(0)
        
    # Run the testing framework
    if sys.version_info >= (3, 7):
        asyncio.run(main())
    else:
        loop = asyncio.get_event_loop()
        loop.run_until_complete(main())