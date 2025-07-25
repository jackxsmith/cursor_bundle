# Verification Policy for Cursor Bundle

## Core Principle
**NEVER STOP UNTIL VERIFICATION IS COMPLETE**

This policy establishes the fundamental requirement that all changes must be verified against the actual GitHub repository before considering any task complete.

## Policy Statement

### 1. Mandatory Verification Requirement
- **NEVER** make claims about GitHub status without direct verification
- **ALWAYS** check the actual GitHub repository URLs to confirm statements
- **CONTINUE** checking until the expected result is visually confirmed
- **NEVER** assume changes have taken effect without verification
- **ALWAYS** verify the EXACT status count (e.g., 4/5, 5/5) shown on GitHub branches page
- **NEVER** mark verification complete until GitHub branches page shows expected status
- **MANDATORY**: Use GitHub API for programmatic status verification
- **REQUIRED**: Check API endpoints before relying on visual inspection alone

### 2. Specific Verification Requirements

#### GitHub API Status Verification (PRIMARY METHOD)
- **MANDATORY**: Use GitHub API endpoints as primary verification method
- **Required API Check**: `curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs"`
- **Parse API Response**: Extract status of all check runs using jq or similar
- **Expected Output**: All jobs must show "completed - success"
- **API Command Example**: `curl -s "..." | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"'`
- **Verification Complete Only When**: All 5 jobs show "completed - success" via API

#### GitHub Actions Status Verification (SECONDARY METHOD)
- Check https://github.com/jackxsmith/cursor_bundle/actions for workflow runs
- Verify actual status indicators (green ✓, red ✗, yellow ●)
- Confirm expected number of status checks matches GitHub branches page exactly
- Wait for workflows to complete processing
- Check individual workflow pages to ensure all jobs are triggering
- Verify no workflows show "This workflow does not exist"

#### WebFetch Limitations for Status Checking
- WebFetch cannot see dynamic JavaScript-rendered status indicators
- Status checks (4/5, 5/5) are often loaded after page render via JavaScript
- WebFetch gets initial HTML only, not authenticated/dynamic content
- User must manually verify and report status when WebFetch cannot see it
- **SOLUTION**: Always use GitHub API endpoints for definitive verification

#### Branch Status Verification  
- Check https://github.com/jackxsmith/cursor_bundle/branches for branch status
- Verify all branches show up-to-date status
- Confirm no "behind main" indicators
- Validate status check completion

#### Commit Status Verification
- Check https://github.com/jackxsmith/cursor_bundle/commits/main for commit status
- Verify status indicators on latest commits
- Confirm workflow completion for each commit
- Validate all required checks pass

### 3. Verification Loop Protocol

1. **Make Change** - Implement the required fix/feature
2. **Commit & Push** - Deploy changes to GitHub
3. **Wait** - Allow GitHub Actions processing time (minimum 2-3 minutes)
4. **API Verification** - **MANDATORY**: Check GitHub API for status first
5. **Visual Verification** - Check actual GitHub URLs for confirmation
6. **Repeat** - If verification fails, analyze and fix issues
7. **Document** - Only mark complete when both API and visual verification succeed

#### Mandatory API Verification Commands
```bash
# Check all check runs status
curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"'

# Expected successful output:
# check: completed - success
# container-security: completed - success  
# security-scan: completed - success
# perf-test: completed - success
# build: completed - success
```

### 4. Enforcement Guidelines

#### For Automated Scripts
```bash
# Mandatory API verification loop
while true; do
    # Check GitHub API for all check runs
    api_result=$(curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"')
    
    # Count successful completions
    success_count=$(echo "$api_result" | grep -c "completed - success")
    
    if [[ $success_count -eq 5 ]]; then
        echo "✓ API Verification complete: All 5 jobs successful"
        echo "$api_result"
        break
    else
        echo "⏳ Waiting for GitHub workflows... ($success_count/5 successful)"
        echo "$api_result"
        sleep 60
    fi
done
```

#### For Manual Verification
- **FIRST**: Always run API verification command
- **SECOND**: Use browser to check GitHub URLs for visual confirmation
- Screenshot status if needed for documentation
- Do not rely on assumptions or cached data
- Refresh pages to ensure latest status
- **NEVER** skip API verification step

### 5. Common Verification Points

#### GitHub Actions Workflows
- ✅ All workflows trigger on expected events
- ✅ All jobs within workflows complete successfully  
- ✅ Artifact uploads succeed
- ✅ Status badges reflect actual state

#### Repository Health
- ✅ Branch protection rules function correctly
- ✅ Required status checks enforce properly
- ✅ Merge conflicts are resolved
- ✅ Version bumps trigger appropriate workflows

### 6. Failure Response Protocol

When verification fails:
1. **Identify** the specific discrepancy
2. **Analyze** root cause (syntax, permissions, timing)
3. **Fix** the underlying issue
4. **Test** the fix with new commit
5. **Re-verify** until successful
6. **Document** the resolution

### 7. Verification Tools

#### GitHub API Endpoints (PRIMARY - MANDATORY)
- **Check Runs API**: https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs
- **Status API**: https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/status
- **Workflows API**: https://api.github.com/repos/jackxsmith/cursor_bundle/actions/runs
- **REQUIRED USAGE**: Must check API before any other verification method

#### Direct GitHub URLs (Secondary)
- Repository: https://github.com/jackxsmith/cursor_bundle
- Actions: https://github.com/jackxsmith/cursor_bundle/actions  
- Branches: https://github.com/jackxsmith/cursor_bundle/branches
- Commits: https://github.com/jackxsmith/cursor_bundle/commits/main

#### Command Line Tools (Supporting)
- `curl` + `jq` for API verification (MANDATORY)
- `gh` CLI for GitHub operations
- `git` status and log commands

#### Mandatory API Verification Pattern
```bash
# This command MUST be run for every verification
curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"'
```

### 8. PERMANENT SOLUTION POLICY: GitHub Actions Job Dependencies

#### Root Cause Prevention
The 4/5 status issue was caused by GitHub Actions job dependencies creating bottlenecks where dependent jobs waited for the build job to complete. This caused timeouts and incomplete workflows.

#### MANDATORY SOLUTION POLICY
```yaml
# ✅ CORRECT: Jobs run in parallel (NO dependencies)
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    
  perf-test:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    # NO 'needs: build' dependency
    
  security-scan:
    runs-on: ubuntu-latest
    timeout-minutes: 5
    # NO 'needs: build' dependency
    
  container-security:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    # NO 'needs: build' dependency
```

#### FORBIDDEN PATTERN
```yaml
# ❌ FORBIDDEN: Job dependencies create bottlenecks
jobs:
  build:
    runs-on: ubuntu-latest
    
  perf-test:
    needs: build  # ❌ NEVER USE THIS
    
  security-scan:
    needs: build  # ❌ NEVER USE THIS
    
  container-security:
    needs: build  # ❌ NEVER USE THIS
```

#### POLICY ENFORCEMENT
- **NEVER** use `needs:` dependencies in GitHub Actions workflows unless absolutely required
- **ALWAYS** enable parallel job execution for faster completion
- **MANDATORY** timeout limits: build (30min), others (5-10min max)
- **REQUIRED** API verification to confirm all 5 jobs complete successfully

## Implementation Date
July 25, 2025

## Version
1.1.0 - Added Permanent Solution Policy

## Enforcement
This policy is **MANDATORY** for all cursor bundle operations. No exceptions.

---

**Remember: Trust but verify. In this case, ALWAYS verify. And NEVER use job dependencies.**