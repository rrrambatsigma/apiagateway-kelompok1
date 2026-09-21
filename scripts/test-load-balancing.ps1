# =====================================================================
# Load Balancing Testing Script
# Verify load balancing distribution ke multiple instances
# =====================================================================

Write-Host "==================================================================="
Write-Host "Load Balancing Testing"
Write-Host "==================================================================="
Write-Host ""

# Perlu login dulu untuk dapat token
Write-Host "1. Getting authentication token..."
Write-Host "-------------------------------------------------------------------"

$loginBody = @{
    email = "admin@example.com"
    password = "admin123"
} | ConvertTo-Json

try {
    $loginResponse = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody
    
    $token = $loginResponse.access_token
    Write-Host "  ✓ Login successful" -ForegroundColor Green
    Write-Host "  Token: $($token.Substring(0, 20))..." -ForegroundColor Gray
    Write-Host ""
} catch {
    Write-Host "  ✗ Login failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Make sure services are running: docker-compose up -d"
    exit 1
}

# Test load balancing dengan multiple requests
Write-Host "2. Sending 30 requests to /api/items..."
Write-Host "-------------------------------------------------------------------"

$headers = @{
    "Authorization" = "Bearer $token"
}

$upstreamCount = @{}

for ($i = 1; $i -le 30; $i++) {
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8080/api/items" `
            -Method GET `
            -Headers $headers `
            -UseBasicParsing
        
        # Check which upstream handled the request (dari response header jika ada)
        # atau lihat dari logs
        Write-Host "  Request $i`: " -NoNewline
        Write-Host "OK" -ForegroundColor Green
    } catch {
        Write-Host "  Request $i`: " -NoNewline
        Write-Host "FAILED" -ForegroundColor Red
    }
    
    Start-Sleep -Milliseconds 100
}
Write-Host ""

# Analyze logs untuk lihat distribusi
Write-Host "3. Analyzing request distribution from logs..."
Write-Host "-------------------------------------------------------------------"

$logs = docker logs gateway 2>&1 | Select-String -Pattern '"upstream_addr"' | Select-Object -Last 30

$distribution = @{}
foreach ($log in $logs) {
    if ($log -match '"upstream_addr":"([^"]+)"') {
        $upstream = $matches[1]
        if ($distribution.ContainsKey($upstream)) {
            $distribution[$upstream]++
        } else {
            $distribution[$upstream] = 1
        }
    }
}

Write-Host ""
Write-Host "Distribution by upstream:"
foreach ($key in $distribution.Keys | Sort-Object) {
    $count = $distribution[$key]
    $percentage = [math]::Round(($count / 30) * 100, 2)
    $bar = "█" * [math]::Round($percentage / 3)
    Write-Host "  $key`: $count requests ($percentage%) $bar"
}
Write-Host ""

# Show current upstream config
Write-Host "4. Current upstream configuration:"
Write-Host "-------------------------------------------------------------------"
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf
Write-Host ""

Write-Host "==================================================================="
Write-Host "Load Balancing Test Complete"
Write-Host "Expected: Requests distributed evenly using least_conn algorithm"
Write-Host "==================================================================="
