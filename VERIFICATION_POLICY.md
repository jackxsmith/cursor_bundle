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

### 2. Specific Verification Requirements

#### GitHub Actions Status Verification
- Check https://github.com/jackxsmith/cursor_bundle/actions for workflow runs
- Verify actual status indicators (green ✓, red ✗, yellow ●)
- Confirm expected number of status checks (e.g., 2/2, 5/5)
- Wait for workflows to complete processing

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
4. **Verify** - Check actual GitHub URLs for confirmation
5. **Repeat** - If verification fails, analyze and fix issues
6. **Document** - Only mark complete when verification succeeds

### 4. Enforcement Guidelines

#### For Automated Scripts
```bash
# Example verification loop
while true; do
    # Check GitHub status
    status=$(curl -s https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/status)
    if [[ "$status" == "success" ]]; then
        echo "✓ Verification complete"
        break
    else
        echo "⏳ Waiting for GitHub to update..."
        sleep 30
    fi
done
```

#### For Manual Verification
- Use browser to check GitHub URLs directly
- Screenshot status if needed for documentation
- Do not rely on assumptions or cached data
- Refresh pages to ensure latest status

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

#### Direct GitHub URLs (Primary)
- Repository: https://github.com/jackxsmith/cursor_bundle
- Actions: https://github.com/jackxsmith/cursor_bundle/actions  
- Branches: https://github.com/jackxsmith/cursor_bundle/branches
- Commits: https://github.com/jackxsmith/cursor_bundle/commits/main

#### API Endpoints (Secondary)
- Status API: https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/status
- Workflows API: https://api.github.com/repos/jackxsmith/cursor_bundle/actions/runs

#### Command Line Tools (Tertiary)
- `gh` CLI for GitHub operations
- `curl` for API verification
- `git` status and log commands

## Implementation Date
July 25, 2025

## Version
1.0.0

## Enforcement
This policy is **MANDATORY** for all cursor bundle operations. No exceptions.

---

**Remember: Trust but verify. In this case, ALWAYS verify.**