# =====================================================================
# Setup Script
# Initial setup untuk development environment
# =====================================================================

Write-Host "==================================================================="
Write-Host "API Gateway Setup"
Write-Host "==================================================================="
Write-Host ""

# Check if .env exists
if (-Not (Test-Path ".env")) {
    Write-Host "1. Creating .env file from .env.example..."
    Copy-Item ".env.example" ".env"
    Write-Host "  ✓ .env file created" -ForegroundColor Green
} else {
    Write-Host "1. .env file already exists"
    Write-Host "  ✓ Skipping" -ForegroundColor Yellow
}
Write-Host ""

# Check Docker
Write-Host "2. Checking Docker..."
try {
    $dockerVersion = docker --version
    Write-Host "  ✓ Docker found: $dockerVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker not found. Please install Docker first." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Check Docker Compose
Write-Host "3. Checking Docker Compose..."
try {
    $composeVersion = docker compose version
    Write-Host "  ✓ Docker Compose found: $composeVersion" -ForegroundColor Green
} catch {
    Write-Host "  ✗ Docker Compose not found. Please install Docker Compose." -ForegroundColor Red
    exit 1
}
Write-Host ""

# Build and start services
Write-Host "4. Building and starting services..."
Write-Host "-------------------------------------------------------------------"
Write-Host "  This may take a few minutes..."
Write-Host ""

docker compose build
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Build failed" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Build completed" -ForegroundColor Green
Write-Host ""

docker compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ✗ Failed to start services" -ForegroundColor Red
    exit 1
}
Write-Host "  ✓ Services started" -ForegroundColor Green
Write-Host ""

# Wait for services to be healthy
Write-Host "5. Waiting for services to be healthy..."
Write-Host "-------------------------------------------------------------------"
Write-Host "  This may take 30-60 seconds..."
Write-Host ""

$maxAttempts = 30
$attempt = 0
$allHealthy = $false

while ($attempt -lt $maxAttempts -and -not $allHealthy) {
    $attempt++
    Start-Sleep -Seconds 2
    
    try {
        # Check discovery health
        $discoveryHealth = Invoke-RestMethod -Uri "http://localhost:8010/health" -Method GET -ErrorAction Stop
        
        # Check gateway health
        $gatewayHealth = Invoke-WebRequest -Uri "http://localhost:8080/healthz" -Method GET -UseBasicParsing -ErrorAction Stop
        
        # Check if services are registered
        $registry = Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET -ErrorAction Stop
        
        if ($registry.services.Count -ge 3) {
            $allHealthy = $true
            Write-Host "  ✓ All services are healthy and registered" -ForegroundColor Green
        } else {
            Write-Host "  ⏳ Waiting... ($($registry.services.Count)/3 services registered)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⏳ Waiting... (attempt $attempt/$maxAttempts)" -ForegroundColor Yellow
    }
}

if (-not $allHealthy) {
    Write-Host "  ⚠ Services are taking longer than expected to start" -ForegroundColor Yellow
    Write-Host "  Check logs with: docker compose logs -f"
    Write-Host ""
}
Write-Host ""

# Show status
Write-Host "6. Service Status:"
Write-Host "-------------------------------------------------------------------"
docker compose ps
Write-Host ""

Write-Host "==================================================================="
Write-Host "Setup Complete!"
Write-Host "==================================================================="
Write-Host ""
Write-Host "Available endpoints:"
Write-Host "  Gateway:          http://localhost:8080"
Write-Host "  Discovery:        http://localhost:8010"
Write-Host "  API Instance 1:   http://localhost:8001"
Write-Host "  API Instance 2:   http://localhost:8002"
Write-Host "  API Instance 3:   http://localhost:8003"
Write-Host ""
Write-Host "Useful commands:"
Write-Host "  Monitor services:        ./scripts/monitor.ps1"
Write-Host "  Test load balancing:     ./scripts/test-load-balancing.ps1"
Write-Host "  Test circuit breaker:    ./scripts/test-circuit-breaker.ps1"
Write-Host "  View logs:               docker compose logs -f"
Write-Host "  Stop services:           docker compose down"
Write-Host ""
Write-Host "Documentation:"
Write-Host "  Main README:             ./README.md"
Write-Host "  Discovery README:        ./services/discovery/README.md"
Write-Host ""
