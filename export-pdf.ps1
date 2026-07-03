param(
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

$briefingDir = Join-Path $PSScriptRoot "briefings\$Date"
$htmlFile = Join-Path $briefingDir "$Date.html"
$pdfFile  = Join-Path $briefingDir "$Date.pdf"

$edgePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)

$edge = $null
foreach ($p in $edgePaths) {
    if (Test-Path $p) {
        $edge = $p
        break
    }
}

if (-not $edge) {
    Write-Host "Edge not found, trying Chrome..."
    $chromePaths = @(
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    )
    foreach ($p in $chromePaths) {
        if (Test-Path $p) {
            $edge = $p
            break
        }
    }
}

if (-not $edge) {
    Write-Host "ERROR: Neither Edge nor Chrome found."
    exit 1
}

Write-Host "Browser: $edge"
Write-Host "Input:   $htmlFile"
Write-Host "Output:  $pdfFile"

$htmlUri = "file:///" + ($htmlFile -replace '\\', '/')

& $edge --headless --disable-gpu --print-to-pdf="$pdfFile" --no-pdf-header-footer $htmlUri

if (Test-Path $pdfFile) {
    $size = (Get-Item $pdfFile).Length
    Write-Host "SUCCESS: PDF created ($size bytes)"
    Start-Process $pdfFile
} else {
    Write-Host "FAILED: PDF not created."
    exit 1
}
