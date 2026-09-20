# =====================================================================
# Real-time Monitoring Script
# Monitor service registry, health checks, dan upstream status
# =====================================================================

Write-Host "==================================================================="
Write-Host "API Gateway Monitoring Dashboard"
Write-Host "Press Ctrl+C to stop"
Write-Host "==================================================================="
Write-Host ""

function Get-ColoredStatus {
    param($status)
    switch ($status) {
        "closed" { return @{ Color = "Green"; Text = "✓ CLOSED" } }
        "open" { return @{ Color = "Red"; Text = "✗ OPEN" } }
        "half_open" { return @{ Color = "Yellow"; Text = "⚠ HALF-OPEN" } }
        default { return @{ Color = "Gray"; Text = "? UNKNOWN" } }
    }
}

while ($true) {
    Clear-Host
    Write-Host "==================================================================="
    Write-Host "API Gateway Monitoring - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "==================================================================="
    Write-Host ""
    
    # Docker containers status
    Write-Host "📦 Container Status:"
    Write-Host "-------------------------------------------------------------------"
    $containers = docker ps --filter "name=api-" --filter "name=discovery" --filter "name=gateway" --format "{{.Names}}\t{{.Status}}" 2>$null
    if ($containers) {
        $containers | ForEach-Object {
            $parts = $_ -split '\t'
            Write-Host "  $($parts[0].PadRight(15)) : $($parts[1])"
        }
    } else {
        Write-Host "  No containers running" -ForegroundColor Red
    }
    Write-Host ""
    
    # Service Discovery Health
    try {
        $discoveryHealth = Invoke-RestMethod -Uri "http://localhost:8010/health" -Method GET -ErrorAction Stop
        Write-Host "🔍 Service Discovery:"
        Write-Host "-------------------------------------------------------------------"
        Write-Host "  Status: " -NoNewline
        Write-Host "✓ OK" -ForegroundColor Green
        Write-Host "  Registered Services: $($discoveryHealth.registered_services)"
        Write-Host "  Healthy Services: $($discoveryHealth.healthy_services)"
        Write-Host ""
        
        # Service Registry
        $registry = Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET -ErrorAction Stop
        Write-Host "📋 Service Registry:"
        Write-Host "-------------------------------------------------------------------"
        
        if ($registry.services.Count -eq 0) {
            Write-Host "  No services registered" -ForegroundColor Yellow
        } else {
            foreach ($service in $registry.services) {
                $statusInfo = Get-ColoredStatus -status $service.state
                Write-Host "  $($service.name) ($($service.host):$($service.port))" -NoNewline
                Write-Host " - " -NoNewline
                Write-Host $statusInfo.Text -ForegroundColor $statusInfo.Color
                Write-Host "    Failures: $($service.consecutive_failures) | Last Check: $($service.last_check)"
            }
        }
        Write-Host ""
        
    } catch {
        Write-Host "🔍 Service Discovery: " -NoNewline
        Write-Host "✗ OFFLINE" -ForegroundColor Red
        Write-Host ""
    }
    
    # Gateway Health
    try {
        $gatewayResponse = Invoke-WebRequest -Uri "http://localhost:8080/healthz" -Method GET -UseBasicParsing -ErrorAction Stop
        Write-Host "🌐 Gateway Status: " -NoNewline
        Write-Host "✓ OK" -ForegroundColor Green
    } catch {
        Write-Host "🌐 Gateway Status: " -NoNewline
        Write-Host "✗ OFFLINE" -ForegroundColor Red
    }
    Write-Host ""
    
    # Upstream Configuration
    Write-Host "⚖️  Load Balancer Configuration:"
    Write-Host "-------------------------------------------------------------------"
    try {
        $upstreamConfig = docker exec gateway cat /etc/nginx/conf.d/upstreams.conf 2>$null
        if ($upstreamConfig) {
            $upstreamConfig | Select-String -Pattern "server " | ForEach-Object {
                Write-Host "  $_"
            }
        }
    } catch {
        Write-Host "  Cannot read upstream config" -ForegroundColor Red
    }
    Write-Host ""
    
    # Recent logs (errors only)
    Write-Host "📝 Recent Logs (last 5 lines):"
    Write-Host "-------------------------------------------------------------------"
    $recentLogs = docker logs --tail 5 gateway 2>&1
    if ($recentLogs) {
        $recentLogs | ForEach-Object {
            if ($_ -match "error|fail|warn") {
                Write-Host "  $_" -ForegroundColor Yellow
            } else {
                Write-Host "  $_" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
    
    Write-Host "==================================================================="
    Write-Host "Refreshing in 5 seconds... (Ctrl+C to stop)"
    Start-Sleep -Seconds 5
}
