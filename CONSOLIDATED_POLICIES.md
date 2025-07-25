# 📋 Cursor Bundle - Consolidated Policies & Standards
## Single Source of Truth for All Project Policies

![Version](https://img.shields.io/badge/version-6.9.205-blue.svg)
![Policy Status](https://img.shields.io/badge/policy-enforced-green.svg)
![Compliance](https://img.shields.io/badge/compliance-validated-green.svg)

> **AUTHORITATIVE DOCUMENT**: This is the single source of truth for all Cursor Bundle policies. All other policy documents are deprecated and superseded by this consolidated version.

## 🎯 CRITICAL LESSONS LEARNED POLICIES

### LESSON 1: NEVER STOP VERIFICATION POLICY

**MANDATORY POLICY:**
```
NEVER STOP UNTIL VERIFICATION IS COMPLETE
- Continue verification loops until user confirms success
- No stopping after commits - immediately continue monitoring
- No assumptions that changes worked - verify continuously
- If verification fails, immediately start next iteration
```

**Violation Prevention:**
- User must explicitly confirm completion before stopping
- Create automatic verification loops that don't exit until success
- Never assume changes worked without verification

### LESSON 2: MANDATORY VERSION BUMPING POLICY

**MANDATORY POLICY:**
```
ALWAYS USE EXISTING BUMP FUNCTIONS
- Never manually edit VERSION file - use existing bump functions
- Always use ./bump.sh or ./bump_merged.sh scripts
- Let bump scripts handle branch creation and version management
- Never bypass the established bump workflow
```

**Implementation:**
```bash
# ✅ CORRECT: Use existing bump scripts
./bump.sh 6.9.XXX    # or ./bump_merged.sh 6.9.XXX

# ❌ FORBIDDEN: Manual version editing
echo "6.9.XXX" > VERSION  # NEVER DO THIS
git add VERSION           # NEVER DO THIS
```

### LESSON 3: GITHUB API AS PRIMARY VERIFICATION

**MANDATORY POLICY:**
```
GITHUB API MUST BE PRIMARY VERIFICATION METHOD
- Always check API before visual verification
- Never rely solely on WebFetch for status checking
- Use curl + jq for definitive status confirmation
```

**Mandatory API Commands:**
```bash
# PRIMARY verification command (MUST RUN EVERY TIME)
curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"'

# Expected success output:
# check: completed - success
# container-security: completed - success  
# security-scan: completed - success
# perf-test: completed - success
# build: completed - success
```

### LESSON 4: GITHUB ACTIONS JOB DEPENDENCIES PROHIBITION

**MANDATORY POLICY:**
```yaml
# ✅ CORRECT: Parallel execution (NO dependencies)
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

# ❌ FORBIDDEN: Dependencies create bottlenecks
jobs:
  perf-test:
    needs: build  # NEVER USE THIS
```

**Root Cause Prevention:**
- Job dependencies create bottlenecks where dependent jobs wait for build job
- Build job timeouts block all dependent jobs causing 4/5 status
- Parallel execution prevents single points of failure

### LESSON 5: SYSTEMATIC INVESTIGATION APPROACH

**MANDATORY POLICY:**
```
SYSTEMATIC DEBUGGING APPROACH:
1. Check GitHub API for exact status first
2. Identify all expected jobs/workflows 
3. Map 1:1 what's expected vs actual
4. Use API to pinpoint failing components
5. Fix root cause, not symptoms
6. Verify fix with API before declaring success
```

### LESSON 6: POLICY DOCUMENTATION CONSOLIDATION

**MANDATORY POLICY:**
```
SINGLE SOURCE OF TRUTH FOR POLICIES:
- Never scatter policies across multiple documents
- Consolidate all policies into one authoritative document
- Deprecate and remove duplicate policy files
- Reference single policy document from all locations
```

**Implementation:**
This document (`CONSOLIDATED_POLICIES.md`) supersedes:
- ❌ `VERIFICATION_POLICY.md` (DEPRECATED)
- ❌ `LESSONS_LEARNED_POLICY.md` (DEPRECATED) 
- ❌ Multiple policy sections in `POLICIES.md` (SUPERSEDED)

## 🔄 VERIFICATION PROTOCOL

### Mandatory Verification Loop
```bash
while true; do
    # 1. MANDATORY API Check
    api_result=$(curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"')
    
    # 2. Count successful completions
    success_count=$(echo "$api_result" | grep -c "completed - success")
    expected_jobs=5
    
    # 3. Check completion
    if [[ $success_count -eq $expected_jobs ]]; then
        echo "✓ API Verification complete: All $expected_jobs jobs successful"
        echo "$api_result"
        break
    else
        echo "⏳ Continuing verification... ($success_count/$expected_jobs successful)"
        echo "$api_result"
        sleep 60
    fi
done
```

### Version Bump Protocol
```bash
# MANDATORY: Use existing bump scripts
./bump.sh $(echo "$(cat VERSION | cut -d. -f1-2).$(expr $(cat VERSION | cut -d. -f3) + 1)")

# FORBIDDEN: Manual version management
# echo "x.x.x" > VERSION  # NEVER DO THIS
```

## 📊 IMPLEMENTATION CHECKLIST

### Every GitHub Operation Must Include:
- [ ] ✅ Use bump script instead of manual VERSION editing
- [ ] ✅ API verification before declaring success
- [ ] ✅ No job dependencies unless critical
- [ ] ✅ Timeout limits on all jobs (5-30 minutes)
- [ ] ✅ Continuous verification until user confirms
- [ ] ✅ Multiple verification methods
- [ ] ✅ Systematic debugging if issues arise
- [ ] ✅ Clear communication of status

### Never Do:
- [ ] ❌ Stop verification without user confirmation
- [ ] ❌ Manually edit VERSION file
- [ ] ❌ Use job dependencies unnecessarily  
- [ ] ❌ Rely solely on visual verification
- [ ] ❌ Make assumptions about success
- [ ] ❌ Skip API verification step
- [ ] ❌ Give up without root cause analysis
- [ ] ❌ Scatter policies across multiple documents

## 🔒 EXISTING ENTERPRISE POLICIES

### Security Policies
*[Inherits all security policies from original POLICIES.md]*
- Data Classification and Secret Management
- Container and Network Security
- Application Security and SDLC
- Vulnerability Management

### Development Standards  
*[Inherits all development standards from original POLICIES.md]*
- Code Quality and Testing Requirements
- Documentation Standards
- Semantic Versioning and Release Management
- Branching Strategy and Git Flow

### Infrastructure Policies
*[Inherits all infrastructure policies from original POLICIES.md]*
- Infrastructure as Code (IaC)
- Environment Management
- Kubernetes and Service Mesh Standards
- Resource Management and Cost Optimization

### Compliance Framework
*[Inherits all compliance requirements from original POLICIES.md]*
- SOC 2, PCI DSS, ISO 27001, GDPR
- Audit Requirements and Continuous Compliance
- Change Management and Access Control
- Monitoring, Logging, and Incident Response

## 📄 POLICY ENFORCEMENT

### Version Control
- **Version**: 2.0.0 (Consolidated)
- **Supersedes**: All previous policy documents
- **Enforcement**: MANDATORY for all operations
- **Review**: Quarterly with immediate updates for critical issues

### Contact Information
- **Security Incidents**: security-emergency@cursor-bundle.com
- **Policy Questions**: compliance@cursor-bundle.com
- **Technical Issues**: engineering@cursor-bundle.com

---

## 🗂️ DEPRECATED DOCUMENTS

The following documents are **DEPRECATED** and superseded by this consolidated policy:

- ❌ `VERIFICATION_POLICY.md` → Use Lesson 3 & Verification Protocol above
- ❌ `LESSONS_LEARNED_POLICY.md` → Use Critical Lessons Learned section above
- ❌ Policy sections in `POLICIES.md` → Use Existing Enterprise Policies above

**ACTION REQUIRED**: Remove deprecated policy files to prevent confusion.

---

**Document Control:**
- **Created**: July 25, 2025
- **Status**: ACTIVE AND MANDATORY  
- **Authority**: Consolidated from all policy sources
- **Scope**: All Cursor Bundle operations

---

**Remember: One document, one truth. Follow the consolidated policies to prevent all identified issues.**