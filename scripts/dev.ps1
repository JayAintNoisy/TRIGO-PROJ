param()

$RootDir = Resolve-Path (Join-Path $PSScriptRoot "..")

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  TriGo Development Server Launcher" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

function Start-DevWindow {
    param([string]$Title, [string]$Command)
    $scriptContent = [string]::Format('$host.UI.RawUI.WindowTitle = "{0}"; {1}', $Title, $Command)
    $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    Set-Content -Path $tempFile -Value $scriptContent -Encoding Unicode
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", $tempFile -WindowStyle Normal
}

Write-Host "[1/3] Launching Backend..." -ForegroundColor Yellow
Start-DevWindow -Title "TriGo Backend (port 4000)" -Command "cd '$RootDir'; npm --workspace=apps/trigo-backend run dev"

Write-Host "       Waiting for backend to be ready at http://localhost:4000/health ..." -ForegroundColor Gray

$ready = $false
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
        $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:4000/health" -TimeoutSec 2 -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $ready = $true
            break
        }
    } catch {}
}

if ($ready) {
    Write-Host "       [SUCCESS] Backend is running at http://localhost:4000" -ForegroundColor Green
} else {
    Write-Host "       [ERROR] Backend did not start within 60s. Check the TriGo Backend window for errors." -ForegroundColor Red
}

Write-Host ""
Write-Host "[2/3] Launching Admin Panel..." -ForegroundColor Yellow
Start-DevWindow -Title "TriGo Admin Panel (port 3000)" -Command "cd '$RootDir'; npm --workspace=apps/trigo-admin run dev"
Write-Host "       [SUCCESS] Admin panel launching at http://localhost:3000" -ForegroundColor Green

Write-Host ""
Write-Host "[3/3] Launching Flutter App..." -ForegroundColor Yellow
Start-DevWindow -Title "TriGo Flutter App" -Command "cd '$RootDir\apps\trigo'; flutter run -t lib/main.dart"
Write-Host "       [SUCCESS] Flutter app launching..." -ForegroundColor Green

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  All services are starting up!" -ForegroundColor Cyan
Write-Host "  Check each terminal window for logs." -ForegroundColor Cyan
Write-Host "  Close a window to stop that service." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Backend -> http://localhost:4000" -ForegroundColor Cyan
Write-Host "  Admin   -> http://localhost:3000" -ForegroundColor Cyan
Write-Host "  Flutter -> device/emulator" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
