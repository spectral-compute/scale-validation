$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$PythonBin = if ($env:PYTHON_BIN) { $env:PYTHON_BIN } else { "python" }
$ResultsDir = Join-Path ([System.IO.Path]::GetTempPath()) "ci_benchmarks\pytorch"

Set-Location $RepoRoot

# Start clean so the copied result folder only contains this run

if (Test-Path $ResultsDir) {
    Remove-Item -Recurse -Force $ResultsDir
}
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

# Keep both the src package and root config package importable

$PathSeparator = [System.IO.Path]::PathSeparator
$LocalPythonPath = "$RepoRoot\src$PathSeparator$RepoRoot"
if ($env:PYTHONPATH) {
    $env:PYTHONPATH = "$LocalPythonPath$PathSeparator$env:PYTHONPATH"
}
else {
    $env:PYTHONPATH = $LocalPythonPath
}

Write-Host "Running pytorch_extended_tests"
Write-Host "Writing results to $ResultsDir\"

# Windows PowerShell turns native stderr into ErrorRecord objects

# Keep warnings in the log without treating them as terminating PowerShell errors

$PreviousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
try {
    & $PythonBin -u -m pytorch_extended_tests.orchestrator.run_suite `
        --results-dir $ResultsDir `
        --keep-existing `
        @args 2>&1 |
        ForEach-Object { $_.ToString() } |
        Tee-Object -FilePath (Join-Path $ResultsDir "execution.log")

    $SuiteExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $PreviousErrorActionPreference
}
Write-Host "Results are available in $ResultsDir\"
exit $SuiteExitCode