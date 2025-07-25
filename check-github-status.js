const { chromium } = require('playwright');

async function checkGitHubStatus() {
    console.log('Launching browser to check GitHub status...');
    
    const browser = await chromium.launch({ headless: true });
    const page = await browser.newPage();
    
    try {
        // Navigate to GitHub branches page
        console.log('Navigating to GitHub branches page...');
        await page.goto('https://github.com/jackxsmith/cursor_bundle/branches', { 
            waitUntil: 'networkidle' 
        });
        
        // Wait for content to load
        await page.waitForTimeout(3000);
        
        // Look for status indicators on main branch
        console.log('Looking for status indicators...');
        
        // Try different selectors for status checks
        const statusSelectors = [
            '[data-testid="status-checks"]',
            '.status-checks',
            '.branch-status',
            '[aria-label*="status"]',
            '[title*="status"]',
            '.commit-status',
            '.checks-status'
        ];
        
        for (const selector of statusSelectors) {
            const elements = await page.$$(selector);
            if (elements.length > 0) {
                console.log(`Found ${elements.length} elements with selector: ${selector}`);
                for (let i = 0; i < elements.length; i++) {
                    const text = await elements[i].textContent();
                    const title = await elements[i].getAttribute('title');
                    const ariaLabel = await elements[i].getAttribute('aria-label');
                    console.log(`Element ${i}: text="${text}", title="${title}", aria-label="${ariaLabel}"`);
                }
            }
        }
        
        // Look for any text containing status numbers
        const pageText = await page.textContent('body');
        const statusMatches = pageText.match(/\d+\/\d+/g);
        if (statusMatches) {
            console.log('Found status patterns:', statusMatches);
        }
        
        // Take a screenshot for debugging
        await page.screenshot({ path: 'github-branches.png', fullPage: true });
        console.log('Screenshot saved as github-branches.png');
        
        // Get all text content to search for status
        console.log('Searching for status indicators in page text...');
        if (pageText.includes('4/5')) {
            console.log('✓ FOUND: 4/5 status in page text');
        } else if (pageText.includes('5/5')) {
            console.log('✓ FOUND: 5/5 status in page text');
        } else {
            console.log('No clear status indicators found in text');
        }
        
    } catch (error) {
        console.error('Error checking GitHub status:', error);
    } finally {
        await browser.close();
    }
}

checkGitHubStatus().then(() => {
    console.log('GitHub status check completed');
}).catch(console.error);