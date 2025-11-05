# Test UUID extraction function

# Import the function
. ./quickstart.ps1

# Test cases
$testCases = @(
    @{Input = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Expected = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Description = "UUID only"},
    @{Input = "05dedbe8-0955-48d8-b586-6cb2dcbddc09#dev/code"; Expected = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Description = "UUID with #dev fragment"},
    @{Input = "05dedbe8-0955-48d8-b586-6cb2dcbddc09#test/code"; Expected = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Description = "UUID with #test fragment (should warn)"},
    @{Input = "https://dashboard.pantheon.io/sites/05dedbe8-0955-48d8-b586-6cb2dcbddc09#dev/code"; Expected = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Description = "Full URL"},
    @{Input = "  05dedbe8-0955-48d8-b586-6cb2dcbddc09  "; Expected = "05dedbe8-0955-48d8-b586-6cb2dcbddc09"; Description = "UUID with whitespace"},
    @{Input = "INVALID"; Expected = $null; Description = "Invalid input"}
)

Write-Host "Testing UUID Extraction Function" -ForegroundColor Cyan
Write-Host "=================================" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

foreach ($test in $testCases) {
    Write-Host "Test: $($test.Description)" -ForegroundColor Yellow
    Write-Host "  Input: $($test.Input)"

    $result = Extract-PantheonUUID -UserInput $test.Input

    if ($result -eq $test.Expected) {
        Write-Host "  Result: $result" -ForegroundColor Green
        Write-Host "  Status: PASSED" -ForegroundColor Green
        $passed++
    } else {
        Write-Host "  Expected: $($test.Expected)" -ForegroundColor Red
        Write-Host "  Got: $result" -ForegroundColor Red
        Write-Host "  Status: FAILED" -ForegroundColor Red
        $failed++
    }
    Write-Host ""
}

Write-Host "=================================" -ForegroundColor Cyan
Write-Host "Results: $passed passed, $failed failed" -ForegroundColor $(if ($failed -eq 0) { "Green" } else { "Red" })
