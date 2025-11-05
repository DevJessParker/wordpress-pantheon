#!/usr/bin/env bash

# Test UUID extraction function

# Source the function
source ./quickstart.sh 2>/dev/null || true

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Testing UUID Extraction Function${NC}"
echo -e "${CYAN}=================================${NC}"
echo ""

passed=0
failed=0

# Test function
test_uuid() {
    local input="$1"
    local expected="$2"
    local description="$3"

    echo -e "${YELLOW}Test: $description${NC}"
    echo "  Input: $input"

    local result
    result=$(extract_pantheon_uuid "$input" 2>&1 | tail -n 1)

    if [ "$result" == "$expected" ]; then
        echo -e "  ${GREEN}Result: $result${NC}"
        echo -e "  ${GREEN}Status: PASSED${NC}"
        ((passed++))
    else
        echo -e "  ${RED}Expected: $expected${NC}"
        echo -e "  ${RED}Got: $result${NC}"
        echo -e "  ${RED}Status: FAILED${NC}"
        ((failed++))
    fi
    echo ""
}

# Run tests
test_uuid "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "UUID only"
test_uuid "05dedbe8-0955-48d8-b586-6cb2dcbddc09#dev/code" "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "UUID with #dev fragment"
test_uuid "05dedbe8-0955-48d8-b586-6cb2dcbddc09#test/code" "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "UUID with #test fragment (should warn)"
test_uuid "https://dashboard.pantheon.io/sites/05dedbe8-0955-48d8-b586-6cb2dcbddc09#dev/code" "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "Full URL"
test_uuid "  05dedbe8-0955-48d8-b586-6cb2dcbddc09  " "05dedbe8-0955-48d8-b586-6cb2dcbddc09" "UUID with whitespace"

echo -e "${CYAN}=================================${NC}"
if [ $failed -eq 0 ]; then
    echo -e "${GREEN}Results: $passed passed, $failed failed${NC}"
else
    echo -e "${RED}Results: $passed passed, $failed failed${NC}"
fi
