# =====================================================================
# Circuit Breaker Testing Script
# Test circuit breaker behavior dengan simulasi service failure
# =====================================================================

Write-Host "==================================================================="
Write-Host "Circuit Breaker Testing"
Write-Host "==================================================================="
Write-Host ""

# Check if services are running
Write-Host "1. Checking services status..."
docker ps --filter "name=api-" --filter "name=discovery" --filter "name=gateway" --format "table {{.Names}}\t{{.Status}}"
Write-Host ""

# Show current registry
Write-Host "2. Current service registry:"
Write-Host "-------------------------------------------------------------------"
$registry = Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET
$registry.services | ForEach-Object {
    Write-Host "  $($_.key) - State: $($_.state) - Failures: $($_.consecutive_failures)"
}
Write-Host ""

# Show current upstream config
Write-Host "3. Current upstream configuration:"
Write-Host "-------------------------------------------------------------------"
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf
Write-Host ""

Write-Host "4. Testing Circuit Breaker..."
Write-Host "-------------------------------------------------------------------"
Write-Host "Stopping api-2 to simulate failure..."
docker stop api-2
Write-Host ""

Write-Host "Waiting for health checks to detect failure (30 seconds)..."
Start-Sleep -Seconds 35

Write-Host ""
Write-Host "5. Registry after api-2 stopped:"
Write-Host "-------------------------------------------------------------------"
$registry = Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET
$registry.services | ForEach-Object {
    $stateColor = if ($_.state -eq "open") { "Red" } elseif ($_.state -eq "closed") { "Green" } else { "Yellow" }
    Write-Host "  $($_.key) - State: " -NoNewline
    Write-Host $_.state -ForegroundColor $stateColor -NoNewline
    Write-Host " - Failures: $($_.consecutive_failures)"
}
Write-Host ""

Write-Host "6. Upstream configuration after circuit opened:"
Write-Host "-------------------------------------------------------------------"
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf
Write-Host ""

Write-Host "7. Testing gateway (should only use api-1 and api-3)..."
Write-Host "-------------------------------------------------------------------"
for ($i = 1; $i -le 5; $i++) {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8080/healthz" -Method GET
        Write-Host "  Request $i`: OK"
    } catch {
        Write-Host "  Request $i`: FAILED - $($_.Exception.Message)" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 500
}
Write-Host ""

Write-Host "8. Starting api-2 back..."
docker start api-2
Write-Host ""

Write-Host "Waiting for recovery (cooldown + health check, ~40 seconds)..."
Start-Sleep -Seconds 45

Write-Host ""
Write-Host "9. Registry after api-2 recovered:"
Write-Host "-------------------------------------------------------------------"
$registry = Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET
$registry.services | ForEach-Object {
    $stateColor = if ($_.state -eq "open") { "Red" } elseif ($_.state -eq "closed") { "Green" } else { "Yellow" }
    Write-Host "  $($_.key) - State: " -NoNewline
    Write-Host $_.state -ForegroundColor $stateColor -NoNewline
    Write-Host " - Failures: $($_.consecutive_failures)"
}
Write-Host ""

Write-Host "10. Final upstream configuration:"
Write-Host "-------------------------------------------------------------------"
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf
Write-Host ""

Write-Host "==================================================================="
Write-Host "Circuit Breaker Test Complete"
Write-Host "==================================================================="
