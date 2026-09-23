param(
    [string]$Date = (Get-Date -Format "yyyy-MM-dd")
)

$briefingDir = Join-Path $PSScriptRoot "briefings\$Date"
$htmlFile = Join-Path $briefingDir "$Date-宏观日报.html"
$pdfFile  = Join-Path $briefingDir "$Date-宏观日报.pdf"

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

# Copy to temp to avoid Chinese path encoding issues
$tempHtml = "C:\temp\briefing.html"
$tempPdf  = "C:\temp\briefing.pdf"
Copy-Item -Path $htmlFile -Destination $tempHtml -Force

$htmlUri = "file:///C:/temp/briefing.html"
# NOTE: modern Edge no longer supports the legacy "--headless" flag for
# --print-to-pdf (it silently produces no file). Use "--headless=new".
Remove-Item $tempPdf -Force -ErrorAction SilentlyContinue
& $edge --headless=new --disable-gpu --print-to-pdf="$tempPdf" --no-pdf-header-footer $htmlUri

# Edge may finish writing the PDF slightly after process exit; retry up to 20s
$deadline = (Get-Date).AddSeconds(20)
while (-not (Test-Path $tempPdf) -and (Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 500
}

if (Test-Path $tempPdf) {
    Copy-Item -Path $tempPdf -Destination $pdfFile -Force
    $size = (Get-Item $pdfFile).Length
    Write-Host "SUCCESS: PDF created ($size bytes)"
    # Clean up temp files
    Remove-Item $tempHtml -Force -ErrorAction SilentlyContinue
    Remove-Item $tempPdf -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "FAILED: PDF not created."
    exit 1
}
