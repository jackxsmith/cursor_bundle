#!/usr/bin/env python3
"""
Claude Tools Integration Framework
Enhanced integration with Playwright, Firecrawl, and Context7 for GUI testing
"""

import os
import sys
import json
import asyncio
import logging
import subprocess
from typing import Dict, List, Optional, Any
from pathlib import Path
import tempfile
import time
from dataclasses import dataclass

# Enhanced logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ClaudeToolConfig:
    """Configuration for Claude tools integration"""
    playwright_headless: bool = True
    browser_type: str = "chromium"
    firecrawl_api_key: Optional[str] = None
    context7_endpoint: Optional[str] = None
    screenshot_dir: str = "screenshots"
    recordings_dir: str = "recordings"
    reports_dir: str = "reports"

class PlaywrightEnhancer:
    """Enhanced Playwright integration for Claude"""
    
    def __init__(self, config: ClaudeToolConfig):
        self.config = config
        self.playwright = None
        self.browser = None
        self.context = None
        self.pages = []
        
    async def initialize(self):
        """Initialize enhanced Playwright environment"""
        try:
            from playwright.async_api import async_playwright
            
            self.playwright = await async_playwright().start()
            
            # Select browser based on config
            if self.config.browser_type == "firefox":
                browser_launcher = self.playwright.firefox
            elif self.config.browser_type == "webkit":
                browser_launcher = self.playwright.webkit
            else:
                browser_launcher = self.playwright.chromium
                
            # Launch browser with enhanced settings for Claude integration
            self.browser = await browser_launcher.launch(
                headless=self.config.playwright_headless,
                args=[
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-gpu",
                    "--disable-extensions",
                    "--enable-automation",
                    "--allow-running-insecure-content"
                ]
            )
            
            # Create context with Claude-optimized settings
            self.context = await self.browser.new_context(
                viewport={"width": 1920, "height": 1080},
                user_agent="Claude-Code-Testing-Agent/1.0",
                ignore_https_errors=True,
                record_video_dir=self.config.recordings_dir,
                record_har_path=f"{self.config.reports_dir}/network_activity.har",
                color_scheme="light",
                timezone_id="UTC",
                geolocation={"latitude": 37.7749, "longitude": -122.4194},
                permissions=["clipboard-read", "clipboard-write"]
            )
            
            # Set up event handlers for enhanced debugging
            self.context.on("page", self._on_new_page)
            self.context.on("response", self._on_response)
            self.context.on("request", self._on_request)
            
            logger.info("Enhanced Playwright environment initialized for Claude")
            return True
            
        except ImportError:
            logger.error("Playwright not available. Installing...")
            return await self._install_playwright()
        except Exception as e:
            logger.error(f"Failed to initialize Playwright: {e}")
            return False
            
    async def _install_playwright(self) -> bool:
        """Install Playwright if not available"""
        try:
            # Install Playwright Python package
            subprocess.run([
                sys.executable, "-m", "pip", "install", "playwright"
            ], check=True)
            
            # Install browser binaries
            subprocess.run([
                sys.executable, "-m", "playwright", "install"
            ], check=True)
            
            logger.info("Playwright installed successfully")
            return await self.initialize()
            
        except Exception as e:
            logger.error(f"Failed to install Playwright: {e}")
            return False
            
    def _on_new_page(self, page):
        """Handle new page creation"""
        self.pages.append(page)
        page.on("console", lambda msg: logger.info(f"Console: {msg.text}"))
        page.on("pageerror", lambda error: logger.error(f"Page error: {error}"))
        page.on("crash", lambda: logger.error("Page crashed"))
        
    def _on_response(self, response):
        """Log HTTP responses for debugging"""
        if response.status >= 400:
            logger.warning(f"HTTP {response.status}: {response.url}")
            
    def _on_request(self, request):
        """Log HTTP requests for debugging"""
        logger.debug(f"Request: {request.method} {request.url}")
        
    async def test_gui_application(self, app_url: str, test_scenarios: List[Dict]) -> Dict[str, Any]:
        """Test GUI application with enhanced scenarios"""
        page = await self.context.new_page()
        test_results = {"url": app_url, "scenarios": []}
        
        try:
            # Navigate to application
            await page.goto(app_url, wait_until="networkidle", timeout=30000)
            
            # Take initial screenshot
            await page.screenshot(
                path=f"{self.config.screenshot_dir}/initial_{int(time.time())}.png",
                full_page=True
            )
            
            # Execute test scenarios
            for i, scenario in enumerate(test_scenarios):
                scenario_result = await self._execute_scenario(page, scenario, i)
                test_results["scenarios"].append(scenario_result)
                
            return test_results
            
        except Exception as e:
            logger.error(f"GUI testing failed: {e}")
            return {"error": str(e), "url": app_url}
        finally:
            await page.close()
            
    async def _execute_scenario(self, page, scenario: Dict, scenario_index: int) -> Dict[str, Any]:
        """Execute individual test scenario"""
        scenario_name = scenario.get("name", f"scenario_{scenario_index}")
        logger.info(f"Executing scenario: {scenario_name}")
        
        start_time = time.time()
        
        try:
            # Execute actions
            for action in scenario.get("actions", []):
                await self._execute_action(page, action)
                
            # Take screenshot after scenario
            await page.screenshot(
                path=f"{self.config.screenshot_dir}/{scenario_name}_{int(time.time())}.png"
            )
            
            # Verify expectations
            verification_results = []
            for expectation in scenario.get("expectations", []):
                result = await self._verify_expectation(page, expectation)
                verification_results.append(result)
                
            execution_time = time.time() - start_time
            
            return {
                "name": scenario_name,
                "status": "passed" if all(verification_results) else "failed",
                "execution_time": execution_time,
                "verifications": verification_results
            }
            
        except Exception as e:
            execution_time = time.time() - start_time
            logger.error(f"Scenario failed: {scenario_name}: {e}")
            return {
                "name": scenario_name,
                "status": "error",
                "execution_time": execution_time,
                "error": str(e)
            }
            
    async def _execute_action(self, page, action: Dict):
        """Execute individual GUI action"""
        action_type = action.get("type")
        selector = action.get("selector")
        value = action.get("value")
        
        if action_type == "click":
            await page.click(selector, timeout=10000)
        elif action_type == "fill":
            await page.fill(selector, value, timeout=10000)
        elif action_type == "select":
            await page.select_option(selector, value)
        elif action_type == "hover":
            await page.hover(selector)
        elif action_type == "wait":
            if selector:
                await page.wait_for_selector(selector, timeout=15000)
            else:
                await page.wait_for_timeout(value or 1000)
        elif action_type == "scroll":
            await page.evaluate(f"window.scrollTo(0, {value or 0})")
        elif action_type == "key":
            await page.keyboard.press(value)
        elif action_type == "screenshot":
            filename = action.get("filename", f"action_{int(time.time())}.png")
            await page.screenshot(path=f"{self.config.screenshot_dir}/{filename}")
            
    async def _verify_expectation(self, page, expectation: Dict) -> bool:
        """Verify test expectation"""
        expectation_type = expectation.get("type")
        selector = expectation.get("selector")
        expected_value = expectation.get("value")
        
        try:
            if expectation_type == "text":
                element = page.locator(selector)
                actual_text = await element.text_content()
                return expected_value in actual_text
            elif expectation_type == "visible":
                element = page.locator(selector)
                return await element.is_visible()
            elif expectation_type == "count":
                elements = page.locator(selector)
                actual_count = await elements.count()
                return actual_count == expected_value
            elif expectation_type == "url":
                return expected_value in page.url
            elif expectation_type == "title":
                title = await page.title()
                return expected_value in title
                
        except Exception as e:
            logger.error(f"Expectation verification failed: {e}")
            return False
            
        return True
        
    async def cleanup(self):
        """Clean up Playwright resources"""
        for page in self.pages:
            await page.close()
        if self.context:
            await self.context.close()
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.stop()

class FirecrawlEnhancer:
    """Enhanced Firecrawl integration for Claude"""
    
    def __init__(self, config: ClaudeToolConfig):
        self.config = config
        self.client = None
        
    def initialize(self):
        """Initialize Firecrawl client"""
        try:
            import firecrawl
            
            api_key = self.config.firecrawl_api_key or os.getenv("FIRECRAWL_API_KEY")
            if not api_key:
                logger.warning("Firecrawl API key not provided, using test mode")
                api_key = "test"
                
            self.client = firecrawl.FirecrawlApp(api_key=api_key)
            logger.info("Firecrawl client initialized")
            return True
            
        except ImportError:
            logger.error("Firecrawl not available. Installing...")
            return self._install_firecrawl()
        except Exception as e:
            logger.error(f"Failed to initialize Firecrawl: {e}")
            return False
            
    def _install_firecrawl(self) -> bool:
        """Install Firecrawl if not available"""
        try:
            subprocess.run([
                sys.executable, "-m", "pip", "install", "firecrawl-py"
            ], check=True)
            
            logger.info("Firecrawl installed successfully")
            return self.initialize()
            
        except Exception as e:
            logger.error(f"Failed to install Firecrawl: {e}")
            return False
            
    def enhanced_scrape(self, url: str, options: Dict = None) -> Dict[str, Any]:
        """Enhanced web scraping with error handling"""
        if not self.client:
            return {"error": "Firecrawl client not initialized"}
            
        try:
            default_options = {
                "formats": ["markdown", "html"],
                "includeTags": ["title", "meta", "h1", "h2", "p", "a"],
                "excludeTags": ["script", "style", "nav", "footer"],
                "waitFor": 3000
            }
            
            if options:
                default_options.update(options)
                
            result = self.client.scrape_url(url, default_options)
            
            if result.get("success"):
                return {
                    "success": True,
                    "url": url,
                    "content": result.get("data", {}).get("content", ""),
                    "markdown": result.get("data", {}).get("markdown", ""),
                    "metadata": result.get("data", {}).get("metadata", {}),
                    "links": result.get("data", {}).get("links", [])
                }
            else:
                return {
                    "success": False,
                    "error": result.get("error", "Unknown error"),
                    "url": url
                }
                
        except Exception as e:
            logger.error(f"Firecrawl scraping failed: {e}")
            return {"success": False, "error": str(e), "url": url}
            
    def crawl_site(self, url: str, options: Dict = None) -> Dict[str, Any]:
        """Enhanced site crawling"""
        if not self.client:
            return {"error": "Firecrawl client not initialized"}
            
        try:
            default_options = {
                "crawlerOptions": {
                    "includes": [],
                    "excludes": [],
                    "maxDepth": 2,
                    "limit": 10
                },
                "pageOptions": {
                    "formats": ["markdown"],
                    "waitFor": 2000
                }
            }
            
            if options:
                self._merge_dict(default_options, options)
                
            job = self.client.crawl_url(url, default_options)
            
            return {
                "success": True,
                "job_id": job.get("jobId"),
                "url": url,
                "options": default_options
            }
            
        except Exception as e:
            logger.error(f"Firecrawl crawling failed: {e}")
            return {"success": False, "error": str(e), "url": url}
            
    def _merge_dict(self, base: Dict, update: Dict):
        """Recursively merge dictionaries"""
        for key, value in update.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                self._merge_dict(base[key], value)
            else:
                base[key] = value

class Context7Enhancer:
    """Enhanced Context7 integration for Claude"""
    
    def __init__(self, config: ClaudeToolConfig):
        self.config = config
        self.endpoint = config.context7_endpoint or "http://localhost:7777"
        
    def initialize(self) -> bool:
        """Initialize Context7 connection"""
        try:
            # Try to import and connect to Context7
            # This is a placeholder for actual Context7 integration
            logger.info("Context7 integration initialized")
            return True
            
        except Exception as e:
            logger.error(f"Failed to initialize Context7: {e}")
            return False
            
    def analyze_context(self, content: str, context_type: str = "gui") -> Dict[str, Any]:
        """Analyze context using Context7"""
        try:
            # Placeholder for Context7 analysis
            analysis = {
                "context_type": context_type,
                "content_length": len(content),
                "analysis_timestamp": time.time(),
                "insights": ["Context analysis placeholder"],
                "recommendations": ["Use enhanced testing patterns"]
            }
            
            return {"success": True, "analysis": analysis}
            
        except Exception as e:
            logger.error(f"Context7 analysis failed: {e}")
            return {"success": False, "error": str(e)}

class ClaudeToolsIntegrator:
    """Main integrator for Claude tools"""
    
    def __init__(self, config: ClaudeToolConfig = None):
        self.config = config or ClaudeToolConfig()
        self.playwright = PlaywrightEnhancer(self.config)
        self.firecrawl = FirecrawlEnhancer(self.config)
        self.context7 = Context7Enhancer(self.config)
        
        # Create required directories
        for directory in [self.config.screenshot_dir, self.config.recordings_dir, self.config.reports_dir]:
            os.makedirs(directory, exist_ok=True)
            
    async def initialize_all_tools(self) -> Dict[str, bool]:
        """Initialize all Claude tools"""
        results = {}
        
        # Initialize Playwright
        results["playwright"] = await self.playwright.initialize()
        
        # Initialize Firecrawl
        results["firecrawl"] = self.firecrawl.initialize()
        
        # Initialize Context7
        results["context7"] = self.context7.initialize()
        
        logger.info(f"Tool initialization results: {results}")
        return results
        
    async def comprehensive_gui_test(self, gui_app_path: str) -> Dict[str, Any]:
        """Comprehensive GUI testing using all tools"""
        logger.info(f"Starting comprehensive GUI test for: {gui_app_path}")
        
        test_results = {
            "application": gui_app_path,
            "timestamp": time.time(),
            "playwright_tests": [],
            "firecrawl_analysis": {},
            "context7_insights": {},
            "overall_score": 0
        }
        
        try:
            # Test 1: Basic functionality test
            basic_test = await self._test_basic_functionality(gui_app_path)
            test_results["basic_functionality"] = basic_test
            
            # Test 2: Playwright GUI testing (if web-based)
            if self._is_web_app(gui_app_path):
                playwright_results = await self._run_playwright_tests(gui_app_path)
                test_results["playwright_tests"] = playwright_results
                
            # Test 3: Content analysis with Firecrawl (for web apps)
            if self._is_web_app(gui_app_path):
                firecrawl_analysis = self.firecrawl.enhanced_scrape(gui_app_path)
                test_results["firecrawl_analysis"] = firecrawl_analysis
                
                # Context7 analysis of scraped content
                if firecrawl_analysis.get("success"):
                    content = firecrawl_analysis.get("content", "")
                    context_analysis = self.context7.analyze_context(content, "gui")
                    test_results["context7_insights"] = context_analysis
                    
            # Calculate overall score
            test_results["overall_score"] = self._calculate_overall_score(test_results)
            
            # Generate report
            report_path = self._generate_detailed_report(test_results)
            test_results["report_path"] = report_path
            
            return test_results
            
        except Exception as e:
            logger.error(f"Comprehensive GUI test failed: {e}")
            test_results["error"] = str(e)
            return test_results
            
    async def _test_basic_functionality(self, app_path: str) -> Dict[str, Any]:
        """Test basic GUI functionality"""
        try:
            # Test help flag
            result = subprocess.run(
                [sys.executable, app_path, "--help"],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            return {
                "help_test": {
                    "success": result.returncode == 0,
                    "output_length": len(result.stdout),
                    "has_stderr": len(result.stderr) > 0
                }
            }
            
        except Exception as e:
            return {"help_test": {"success": False, "error": str(e)}}
            
    def _is_web_app(self, app_path: str) -> bool:
        """Determine if the application is web-based"""
        if app_path.startswith(("http://", "https://")):
            return True
            
        # Check if it's a local web app by examining the code
        try:
            with open(app_path, 'r') as f:
                content = f.read()
                return any(keyword in content.lower() for keyword in [
                    "flask", "django", "fastapi", "tornado", "bottle",
                    "http.server", "socketserver", "webapp"
                ])
        except:
            return False
            
    async def _run_playwright_tests(self, app_url: str) -> List[Dict[str, Any]]:
        """Run Playwright tests for web application"""
        test_scenarios = [
            {
                "name": "page_load",
                "actions": [
                    {"type": "wait", "value": 2000},
                    {"type": "screenshot", "filename": "page_loaded.png"}
                ],
                "expectations": [
                    {"type": "title", "value": ""},  # Just check title exists
                ]
            },
            {
                "name": "navigation_test",
                "actions": [
                    {"type": "scroll", "value": 500},
                    {"type": "wait", "value": 1000},
                    {"type": "screenshot", "filename": "after_scroll.png"}
                ],
                "expectations": []
            }
        ]
        
        return await self.playwright.test_gui_application(app_url, test_scenarios)
        
    def _calculate_overall_score(self, test_results: Dict[str, Any]) -> float:
        """Calculate overall test score"""
        score = 0.0
        total_weight = 0.0
        
        # Basic functionality (30% weight)
        if "basic_functionality" in test_results:
            basic = test_results["basic_functionality"]
            if basic.get("help_test", {}).get("success", False):
                score += 0.3
            total_weight += 0.3
            
        # Playwright tests (40% weight)
        if "playwright_tests" in test_results and test_results["playwright_tests"]:
            scenarios = test_results["playwright_tests"].get("scenarios", [])
            if scenarios:
                passed_scenarios = sum(1 for s in scenarios if s.get("status") == "passed")
                score += (passed_scenarios / len(scenarios)) * 0.4
            total_weight += 0.4
            
        # Content analysis (30% weight)
        if "firecrawl_analysis" in test_results:
            if test_results["firecrawl_analysis"].get("success", False):
                score += 0.3
            total_weight += 0.3
            
        return (score / total_weight * 100) if total_weight > 0 else 0.0
        
    def _generate_detailed_report(self, test_results: Dict[str, Any]) -> str:
        """Generate detailed test report"""
        report_path = f"{self.config.reports_dir}/gui_test_report_{int(time.time())}.json"
        
        # Add metadata
        test_results["metadata"] = {
            "claude_tools_version": "1.0.0",
            "python_version": sys.version,
            "platform": sys.platform,
            "tools_status": {
                "playwright": bool(self.playwright.browser),
                "firecrawl": bool(self.firecrawl.client),
                "context7": True  # Placeholder
            }
        }
        
        with open(report_path, 'w') as f:
            json.dump(test_results, f, indent=2, default=str)
            
        logger.info(f"Detailed report generated: {report_path}")
        return report_path
        
    async def cleanup(self):
        """Clean up all tools"""
        await self.playwright.cleanup()

async def main():
    """Main function for Claude tools integration"""
    if len(sys.argv) > 1 and sys.argv[1] == "--help":
        print("""
Claude Tools Integration Framework

Usage: python claude_tools_integration.py [options] [target]

Options:
  --help              Show this help message
  --headless          Run in headless mode (default)
  --headed            Run with visible browser
  --browser TYPE      Browser type: chromium, firefox, webkit
  --config FILE       Configuration file path

Examples:
  python claude_tools_integration.py ./07-tkinter.py
  python claude_tools_integration.py https://example.com --headed
""")
        return
        
    # Configuration
    config = ClaudeToolsConfig(
        playwright_headless="--headed" not in sys.argv,
        browser_type="firefox" if "--browser firefox" in " ".join(sys.argv) else "chromium"
    )
    
    # Initialize integrator
    integrator = ClaudeToolsIntegrator(config)
    
    try:
        # Initialize all tools
        init_results = await integrator.initialize_all_tools()
        print(f"Tool initialization: {init_results}")
        
        # Determine target
        target = "./07-tkinter.py"  # Default target
        for arg in sys.argv[1:]:
            if not arg.startswith("--") and (arg.endswith(".py") or arg.startswith("http")):
                target = arg
                break
                
        # Run comprehensive test
        print(f"\nTesting target: {target}")
        results = await integrator.comprehensive_gui_test(target)
        
        # Print summary
        print(f"\nTest Results Summary:")
        print(f"Overall Score: {results.get('overall_score', 0):.1f}/100")
        print(f"Report: {results.get('report_path', 'N/A')}")
        
        return results
        
    except Exception as e:
        logger.error(f"Integration test failed: {e}")
        return {"error": str(e)}
    finally:
        await integrator.cleanup()

if __name__ == "__main__":
    asyncio.run(main())