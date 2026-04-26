# Dog Report V7 - Transfer Setup Script (Windows PowerShell)
# Run on a NEW machine to bootstrap the project from scratch.
#
# Recommended (download then run - most reliable):
#   iwr https://raw.githubusercontent.com/Fairytails123/reportadmin/main/setup.ps1 -OutFile $env:TEMP\dr-setup.ps1; powershell -NoExit -ExecutionPolicy Bypass -File $env:TEMP\dr-setup.ps1
#
# Alternative (run in current shell):
#   iwr -useb https://raw.githubusercontent.com/Fairytails123/reportadmin/main/setup.ps1 | iex

# ============================================================
# Master try/catch/finally — guarantees the window stays open
# ============================================================
try {

    function Write-Header {
        param([string]$Text)
        Write-Host ""
        Write-Host ("=" * 60) -ForegroundColor Cyan
        Write-Host $Text -ForegroundColor Cyan
        Write-Host ("=" * 60) -ForegroundColor Cyan
    }

    function Test-Cmd {
        param([string]$Name)
        $null = Get-Command $Name -ErrorAction SilentlyContinue
        return $?
    }

    Write-Header "Dog Report V7 - Transfer Setup"

    # --- Step 1: Check prerequisites -------------------------------------
    Write-Host ""
    Write-Host "[1/4] Checking prerequisites..." -ForegroundColor Yellow

    $hasGit  = Test-Cmd "git"
    $hasGh   = Test-Cmd "gh"
    $hasNode = Test-Cmd "node"

    if ($hasGit)  { Write-Host "  [OK] git"  -ForegroundColor Green } else { Write-Host "  [MISSING] git  -> https://git-scm.com/downloads" -ForegroundColor Red }
    if ($hasGh)   { Write-Host "  [OK] gh"   -ForegroundColor Green } else { Write-Host "  [MISSING] gh   -> https://cli.github.com/" -ForegroundColor Red }
    if ($hasNode) { Write-Host "  [OK] node" -ForegroundColor Green } else { Write-Host "  [MISSING] node -> https://nodejs.org" -ForegroundColor Red }

    if (-not ($hasGit -and $hasGh -and $hasNode)) {
        Write-Host ""
        Write-Host "Install the missing tools above, then re-run this script." -ForegroundColor Red
        # Skip remaining steps but DON'T throw - fall through to finally pause
    }
    else {

        # --- Step 2: GitHub auth -----------------------------------------
        Write-Host ""
        Write-Host "[2/4] Checking GitHub authentication..." -ForegroundColor Yellow

        $null = & gh auth status 2>&1
        $authOk = ($LASTEXITCODE -eq 0)

        if (-not $authOk) {
            Write-Host "  Not authenticated to GitHub." -ForegroundColor Yellow
            Write-Host "  Run this AFTER the script finishes (it is interactive):" -ForegroundColor Yellow
            Write-Host "    gh auth login" -ForegroundColor White
            Write-Host "  Then re-run this script." -ForegroundColor Yellow
        } else {
            Write-Host "  [OK] GitHub auth" -ForegroundColor Green

            # --- Step 3: Clone repo ---------------------------------------
            Write-Host ""
            Write-Host "[3/4] Cloning project repo..." -ForegroundColor Yellow

            $projectDir = Join-Path $HOME "DogReportV7"
            if (Test-Path $projectDir) {
                Write-Host "  Folder exists, pulling latest: $projectDir" -ForegroundColor Yellow
                Push-Location $projectDir
                try { & git pull origin main } catch { Write-Host "  Pull failed: $($_.Exception.Message)" -ForegroundColor Red }
                Pop-Location
            } else {
                & gh repo clone Fairytails123/reportadmin $projectDir
                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  Clone failed (exit $LASTEXITCODE)" -ForegroundColor Red
                } else {
                    Write-Host "  [OK] Cloned to $projectDir" -ForegroundColor Green
                }
            }
        }

        # --- Step 4: Verify live system ----------------------------------
        Write-Host ""
        Write-Host "[4/4] Verifying live system..." -ForegroundColor Yellow

        # Each check in its own try - never let one fail the script
        try {
            $r = Invoke-RestMethod -Uri "https://ftmanager.app.n8n.cloud/webhook/v7-markers" -TimeoutSec 15 -ErrorAction Stop
            $count = if ($r.markers) { $r.markers.Count } else { 0 }
            Write-Host "  [OK] Admin API: $count markers" -ForegroundColor Green
            if ($count -gt 0) {
                foreach ($m in $r.markers) {
                    $mc = if ($m.mappings) { $m.mappings.Count } else { 0 }
                    Write-Host "        Marker $($m.number): $($m.name) ($mc mappings)" -ForegroundColor Gray
                }
            }
        } catch {
            Write-Host "  [FAIL] Admin API: $($_.Exception.Message)" -ForegroundColor Red
        }

        try {
            $r = Invoke-RestMethod -Uri "https://ftmanager.app.n8n.cloud/webhook/v7-jotform-fields" -TimeoutSec 15 -ErrorAction Stop
            $count = if ($r.fields) { $r.fields.Count } else { 0 }
            Write-Host "  [OK] JotForm fields: $count fields" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] JotForm fields: $($_.Exception.Message)" -ForegroundColor Red
        }

        try {
            $resp = Invoke-WebRequest -Uri "https://fairytails123.github.io/reportadmin/" -Method Head -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
            Write-Host "  [OK] Admin panel: HTTP $($resp.StatusCode)" -ForegroundColor Green
        } catch {
            Write-Host "  [FAIL] Admin panel: $($_.Exception.Message)" -ForegroundColor Red
        }

        # --- Done --------------------------------------------------------
        Write-Header "Setup Complete"
        Write-Host ""
        Write-Host "Project folder: $projectDir" -ForegroundColor White
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor White
        Write-Host "  1. cd `"$projectDir`"" -ForegroundColor Gray
        Write-Host "  2. notepad HANDOFF.md" -ForegroundColor Gray
        Write-Host "  3. claude" -ForegroundColor Gray
        Write-Host ""
        Write-Host "Resume prompt for Claude:" -ForegroundColor White
        Write-Host '  "Read HANDOFF.md and continue from section 12.4"' -ForegroundColor Gray
        Write-Host ""
        Write-Host "n8n workflows:" -ForegroundColor White
        Write-Host "  Setup        https://ftmanager.app.n8n.cloud/workflow/jzdMCWVjNLA7AE71" -ForegroundColor Gray
        Write-Host "  Admin API    https://ftmanager.app.n8n.cloud/workflow/kP0HENv1MCxehoaz" -ForegroundColor Gray
        Write-Host "  Telegram Bot https://ftmanager.app.n8n.cloud/workflow/ufyIpu25DlYdcaFb" -ForegroundColor Gray
    }
}
catch {
    # Catch-all: anything unexpected lands here, we still pause
    Write-Host ""
    Write-Host "Unexpected error:" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  $($_.ScriptStackTrace)" -ForegroundColor DarkRed
}
finally {
    # Always pause - guarantees the window stays open whether success or failure
    Write-Host ""
    Write-Host ("-" * 60) -ForegroundColor DarkGray
    try {
        $null = Read-Host "Press Enter to close"
    } catch {
        # If Read-Host fails (no console), sleep so user can still see output
        Start-Sleep -Seconds 30
    }
}
