# Testing Policy - Comprehensive Validation Required

## Mandatory Testing Requirements

### 1. Installation Script Testing
**POLICY**: ALL installation scripts MUST be tested individually before claiming completion.

**Required Tests**:
- Test each script with `--help` flag
- Test each script with `--dry-run` or equivalent safe mode
- Document ALL errors encountered
- Fix ALL errors before completion
- Verify fixes work

**Scripts to Test**:
- All `*install*.sh` scripts
- All `*setup*.sh` scripts  
- All `*launcher*.sh` scripts
- All `*preinstall*.sh` scripts
- All `*postinstall*.sh` scripts

### 2. Error Documentation Requirements
**POLICY**: ALL errors must be documented with:
- Script name
- Command that failed
- Error message
- Root cause analysis
- Fix implemented
- Verification of fix

### 3. Completion Criteria
**POLICY**: Work is NOT complete until:
- ✅ ALL scripts tested individually
- ✅ ALL errors documented
- ✅ ALL errors fixed
- ✅ ALL fixes verified
- ✅ Final bump to GitHub

### 4. Enforcement
**POLICY**: This testing policy is enforced by:
- Pre-push policy compliance checks
- Mandatory documentation of test results
- Required verification of all fixes
- **ZERO TOLERANCE**: Any untested scripts found later constitute a policy violation

## Violation Prevention
To prevent shortcuts:
1. Use TodoWrite to track testing progress
2. Document results in `installation_test_results.md`
3. Test each script individually, not just sampling
4. Fix ALL errors, not just major ones
5. **MANDATORY**: Test EVERY script with `--help` flag
6. **MANDATORY**: Test EVERY script for timeout/hang issues
7. **MANDATORY**: Document EVERY error found, no matter how minor

## Enhanced Testing Requirements
**POLICY**: ALL installation scripts MUST be tested for:
- Help flag functionality (`--help`, `-h`)
- GUI dialog prevention (scripts should not open GUI on help)
- Log directory creation issues
- Permission requirements
- Timeout/hanging behavior
- Argument parsing errors

**VIOLATION CONSEQUENCES**:
- Finding untested installation errors after "completion" = **IMMEDIATE RE-TEST ALL**
- Claiming "all fixed" without complete testing = **POLICY VIOLATION**
- Any installation script that fails basic help test = **CRITICAL ERROR**

**REMEMBER**: 
- Installation testing is NEVER complete until EVERY script passes basic tests
- "Most scripts work" is NOT sufficient - ALL scripts must work
- Policy violations will require complete re-testing from scratch