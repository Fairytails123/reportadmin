# Dog Report V7 - Transfer Setup Script (Windows PowerShell)
# Run on a NEW machine to bootstrap the project from scratch.
#
# One-liner install:
#   iwr -useb https://raw.githubusercontent.com/Fairytails123/reportadmin/main/setup.ps1 | iex

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Test-Command {
    param([string]$Name)
    try { Get-Command $Name -ErrorAction Stop | Out-Null; return $true }
    catch { return $false }
}

Write-Header "Dog Report V7 - Transfer Setup"

# --- Step 1: Check prerequisites -----------------------------------------
Write-Host "`n[1/4] Checking prerequisites..." -ForegroundColor Yellow

$missing = @()
if (-not (Test-Command "git"))  { $missing += "git (https://git-scm.com/downloads)" }
if (-not (Test-Command "gh"))   { $missing += "gh (https://cli.github.com/)" }
if (-not (Test-Command "node")) { $missing += "node (https://nodejs.org)" }

if ($missing.Count -gt 0) {
    Write-Host "Missing tools:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    Write-Host "`nInstall them, then re-run this script." -ForegroundColor Red
    exit 1
}
Write-Host "  git, gh, node all installed." -ForegroundColor Green

# --- Step 2: GitHub auth -------------------------------------------------
Write-Host "`n[2/4] Checking GitHub authentication..." -ForegroundColor Yellow

$authStatus = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  Not authenticated. Launching gh auth login..." -ForegroundColor Yellow
    gh auth login
    if ($LASTEXITCODE -ne 0) {
        Write-Host "  Auth failed." -ForegroundColor Red
        exit 1
    }
}
Write-Host "  GitHub auth OK." -ForegroundColor Green

# --- Step 3: Clone repo --------------------------------------------------
Write-Host "`n[3/4] Cloning project repo..." -ForegroundColor Yellow

$projectDir = Join-Path $HOME "DogReportV7"
if (Test-Path $projectDir) {
    Write-Host "  $projectDir already exists. Pulling latest..." -ForegroundColor Yellow
    Push-Location $projectDir
    git pull origin main
    Pop-Location
} else {
    gh repo clone Fairytails123/reportadmin $projectDir
}
Write-Host "  Project ready at: $projectDir" -ForegroundColor Green

# --- Step 4: Verify system is alive --------------------------------------
Write-Host "`n[4/4] Verifying live system..." -ForegroundColor Yellow

try {
    $markers = Invoke-RestMethod -Uri "https://ftmanager.app.n8n.cloud/webhook/v7-markers" -TimeoutSec 15
    Write-Host "  Admin API: $($markers.markers.Count) markers loaded" -ForegroundColor Green
    $markers.markers | ForEach-Object {
        Write-Host "    Marker $($_.number): $($_.name) ($($_.mappings.Count) mappings)" -ForegroundColor Gray
    }
} catch {
    Write-Host "  Admin API failed: $_" -ForegroundColor Red
}

try {
    $fields = Invoke-RestMethod -Uri "https://ftmanager.app.n8n.cloud/webhook/v7-jotform-fields" -TimeoutSec 15
    Write-Host "  JotForm fields: $($fields.fields.Count) fields available" -ForegroundColor Green
} catch {
    Write-Host "  JotForm fields endpoint failed: $_" -ForegroundColor Red
}

try {
    $resp = Invoke-WebRequest -Uri "https://fairytails123.github.io/reportadmin/" -Method Head -TimeoutSec 15 -UseBasicParsing
    Write-Host "  Admin panel: HTTP $($resp.StatusCode)" -ForegroundColor Green
} catch {
    Write-Host "  Admin panel unreachable: $_" -ForegroundColor Red
}

# --- Done ----------------------------------------------------------------
Write-Header "Setup Complete"

Write-Host ""
Write-Host "Project folder: $projectDir" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Open the folder:    cd $projectDir" -ForegroundColor Gray
Write-Host "  2. Read the handoff:   notepad HANDOFF.md" -ForegroundColor Gray
Write-Host "  3. Start Claude Code:  claude" -ForegroundColor Gray
Write-Host ""
Write-Host "Resume prompt for Claude:" -ForegroundColor White
Write-Host '  "Read HANDOFF.md and continue from section 12.4"' -ForegroundColor Gray
Write-Host ""
Write-Host "Bookmark these n8n URLs:" -ForegroundColor White
Write-Host "  https://ftmanager.app.n8n.cloud/workflow/jzdMCWVjNLA7AE71  (Setup)" -ForegroundColor Gray
Write-Host "  https://ftmanager.app.n8n.cloud/workflow/kP0HENv1MCxehoaz  (Admin API)" -ForegroundColor Gray
Write-Host "  https://ftmanager.app.n8n.cloud/workflow/ufyIpu25DlYdcaFb  (Telegram Bot)" -ForegroundColor Gray
Write-Host ""
