#!/bin/bash

# Final security check for public release
# This script checks for any remaining sensitive information

echo "🔐 Final Security Check for Public Release"
echo "=========================================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check for actual passwords (not in documentation)
echo "Checking for hardcoded passwords in code files..."
FOUND_ISSUES=false

# Check for password123 or devpassword123 in non-documentation files
PASS_FILES=$(grep -r "password123\|devpassword123" \
    --include="*.sh" \
    --include="*.yaml" \
    --include="*.yml" \
    --include="*.env" \
    --exclude="prepare-for-public.sh" \
    --exclude="security-final-check.sh" \
    --exclude-dir=".git" \
    . 2>/dev/null | \
    grep -v "SECURITY" | \
    grep -v "changeme" | \
    grep -v "# CHANGE" | \
    grep -v "WARNING" | \
    cut -d: -f1 | sort | uniq)

if [ -n "$PASS_FILES" ]; then
    echo -e "${RED}✗ Found files with hardcoded passwords:${NC}"
    echo "$PASS_FILES"
    FOUND_ISSUES=true
else
    echo -e "${GREEN}✓ No hardcoded passwords found in code files${NC}"
fi

echo ""

# Check for real pull secrets
echo "Checking for actual pull secrets..."
PULL_SECRET_FILES=$(grep -r "pull.*secret.*:" \
    --include="*.sh" \
    --include="*.yaml" \
    --include="*.yml" \
    --include="*.env" \
    --exclude-dir=".git" \
    . 2>/dev/null | \
    grep -E "ey[A-Za-z0-9]|BEGIN|END|{.*}" | \
    cut -d: -f1 | sort | uniq)

if [ -n "$PULL_SECRET_FILES" ]; then
    echo -e "${RED}✗ Possible pull secrets found in:${NC}"
    echo "$PULL_SECRET_FILES"
    FOUND_ISSUES=true
else
    echo -e "${GREEN}✓ No actual pull secrets found${NC}"
fi

echo ""

# Check for .env file
if [ -f ".env" ]; then
    echo -e "${RED}✗ .env file exists - make sure it's in .gitignore!${NC}"
    FOUND_ISSUES=true

    # Check if .env is in .gitignore
    if [ -f ".gitignore" ] && grep -q "^\.env$" .gitignore; then
        echo -e "${GREEN}  ✓ .env is in .gitignore${NC}"
    else
        echo -e "${RED}  ✗ .env is NOT in .gitignore - CRITICAL!${NC}"
    fi
else
    echo -e "${GREEN}✓ No .env file found${NC}"
fi

echo ""

# Check for company-specific information
echo "Checking for company-specific information..."
COMPANY_REFS=$(grep -r "argoai\|aasmith" \
    --include="*.sh" \
    --include="*.yaml" \
    --include="*.yml" \
    --include="*.md" \
    --exclude-dir=".git" \
    --exclude="security-final-check.sh" \
    . 2>/dev/null | \
    grep -v "argoai/" | \
    cut -d: -f1 | sort | uniq)

if [ -n "$COMPANY_REFS" ]; then
    echo -e "${YELLOW}⚠ Found possible company-specific references in:${NC}"
    echo "$COMPANY_REFS"
    echo "  Review these files for any personal/company information"
fi

echo ""
echo "=========================================="

if [ "$FOUND_ISSUES" = true ]; then
    echo -e "${RED}✗ CRITICAL ISSUES FOUND${NC}"
    echo "  Please fix the issues above before making the repository public"
else
    echo -e "${GREEN}✓ Basic security check passed${NC}"
    echo ""
    echo "Final manual review checklist:"
    echo "  [ ] All passwords are placeholders (changeme, <your-password>, etc.)"
    echo "  [ ] No actual pull secrets or tokens"
    echo "  [ ] No company-specific URLs or information"
    echo "  [ ] .gitignore includes all sensitive patterns"
    echo "  [ ] Documentation warns about security"
    echo "  [ ] All credentials use environment variables"
fi

echo ""
