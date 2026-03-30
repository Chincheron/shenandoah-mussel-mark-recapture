# ── Python ─────────────────────────────────────────────────────────────────────

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "ERROR: Python is not installed (or not on PATH)." -ForegroundColor Red
    Write-Host "Please install Python from https://www.python.org/downloads/" -ForegroundColor Yellow
    Write-Host "IMPORTANT: During installation, check 'Add Python to PATH'" -ForegroundColor Yellow
    Write-Host "Then re-run setup.bat." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Python found: $(python --version)" -ForegroundColor Green

# ── uv ─────────────────────────────────────────────────────────────────────────

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..." -ForegroundColor Cyan
    
    # Run installation in same instance of PowerShell instead of nested one
    Set-ExecutionPolicy Bypass -Scope Process -Force
    irm https://astral.sh/uv/install.ps1 | iex
    
    # Refresh PATH
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("PATH", "User")
}

if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv installed but not available in PATH." -ForegroundColor Yellow
    Write-Host "Please restart PowerShell and re-run setup." -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Syncing Python environment..." -ForegroundColor Cyan
uv sync

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Python environment sync failed." -ForegroundColor Red
    pause
    exit 1
}

Write-Host "Python environment synced." -ForegroundColor Green

# ── R ──────────────────────────────────────────────────────────────────────────

if (-not (Get-Command Rscript -ErrorAction SilentlyContinue)) {
    # R is often installed but not on PATH - check common location first
    $rPath = Get-ChildItem "C:\Program Files\R" -Filter "Rscript.exe" -Recurse -ErrorAction SilentlyContinue |
             Sort-Object LastWriteTime -Descending |
             Select-Object -First 1 -ExpandProperty DirectoryName

    if ($rPath) {
        Write-Host "Found R at: $rPath" -ForegroundColor Cyan
        $env:PATH += ";$rPath"
    } else {
        Write-Host ""
        Write-Host "ERROR: R is not installed." -ForegroundColor Red
        Write-Host "Please install R from https://cran.r-project.org/" -ForegroundColor Yellow
        Write-Host "Then re-run setup.bat." -ForegroundColor Yellow
        pause
        exit 1
    }
}

Write-Host "R found: $(Rscript --version 2>&1)" -ForegroundColor Green

# ── renv ───────────────────────────────────────────────────────────────────────

# Ensure renv is installed
Write-Host "Checking for renv..." -ForegroundColor Cyan
Rscript -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv')"

Write-Host "Syncing R environment (this may take a few minutes)..." -ForegroundColor Cyan
Rscript -e "options(repos = c(CRAN = 'https://cloud.r-project.org')); renv::restore(prompt = FALSE)"

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: R package restore failed." -ForegroundColor Red
    Write-Host "Try opening R or RStudio and running: renv::restore()" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "R environment synced." -ForegroundColor Green

# ── Done ───────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
pause