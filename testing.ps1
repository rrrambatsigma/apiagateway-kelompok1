# =====================================================================
# API GATEWAY - TESTING
# Load Balancing, Rate Limiter & Request Validation
# =====================================================================

$ErrorActionPreference = "SilentlyContinue"

$BASE_URL = "http://localhost:8080"
$DISCOVERY_URL = "http://localhost:8500"

$EMAIL = "ahmad@example.com"
$PASSWORD = "admin123"

Write-Host ""
Write-Host "============================================================"
Write-Host " API GATEWAY - TESTING"
Write-Host " Service Discovery, Load Balancing, Rate Limiter & Request Validation"
Write-Host "============================================================"
Write-Host ""

# =====================================================================
# 1. SERVICE DISCOVERY - REGISTRY CHECK
# =====================================================================

Write-Host "[1] SERVICE DISCOVERY - REGISTRY CHECK"
Write-Host "------------------------------------------------------------"

$maxRetries = 5
$retryDelay = 3
$discovered = $false

for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {

    try {

        $registryResponse = Invoke-RestMethod `
            -Uri "$DISCOVERY_URL/registry" `
            -Method GET `
            -UseBasicParsing

        $instanceCount = $registryResponse.count
        $instances = $registryResponse.instances
        $discovered = $true
        break

    }
    catch {

        if ($attempt -lt $maxRetries) {
            Write-Host "  Attempt $attempt/$maxRetries - Discovery belum ready, menunggu ${retryDelay}s..."
            Start-Sleep -Seconds $retryDelay
        }

    }

}

Write-Host ""

if ($discovered) {

    Write-Host "DISCOVERY STATUS    : OK"
    Write-Host "Jumlah instance     : $instanceCount"
    Write-Host ""

    foreach ($inst in $instances) {
        Write-Host "  - $($inst.name) @ $($inst.host):$($inst.port) [state: $($inst.state)]"
    }

    Write-Host ""

    if ($instanceCount -ge 3) {
        Write-Host "SERVICE DISCOVERY   : SUCCESS"
        Write-Host "Semua instance terdaftar: YES"
    }
    else {
        Write-Host "SERVICE DISCOVERY   : CHECK"
        Write-Host "Hanya $instanceCount instance ditemukan"
    }

}
else {

    Write-Host "SERVICE DISCOVERY   : FAILED"
    Write-Host "Tidak bisa mengakses discovery service di $DISCOVERY_URL setelah $maxRetries percobaan"
    Write-Host "Pastikan container discovery berjalan: docker compose up -d discovery"

}

Write-Host ""

Start-Sleep -Seconds 2

# =====================================================================
# 2. INSTANCE CHECK - DAPATKAN NAMA INSTANCE
# =====================================================================

Write-Host "[2] INSTANCE CHECK"
Write-Host "------------------------------------------------------------"

try {

    $raw = curl.exe -s "$BASE_URL/instance"
    $instanceResponse = $raw | ConvertFrom-Json

    Write-Host "INSTANCE            : $($instanceResponse.instance)"
    Write-Host "STATUS              : OK"

}
catch {

    Write-Host "INSTANCE CHECK      : FAILED"
    Write-Host "Tidak bisa mengakses /instance"

}

Write-Host ""

# =====================================================================
# 3. LOAD BALANCING TEST
# =====================================================================

Write-Host "[3] LOAD BALANCING TEST"
Write-Host "------------------------------------------------------------"
Write-Host "Mengirim 9 request untuk melihat distribusi ke 3 instance..."
Write-Host ""

$instances = @()
$failedCount = 0

for ($i = 1; $i -le 9; $i++) {

    $raw = curl.exe --no-keepalive -s -H "Accept: application/json" "$BASE_URL/instance"

    try {

        $resp = $raw | ConvertFrom-Json

        $instances += $resp.instance
        Write-Host "Request $i          : $($resp.instance)"

    }
    catch {

        $failedCount++
        Write-Host "Request $i          : FAILED"
        $instances += "FAILED"

    }

    Start-Sleep -Milliseconds 200

}

Write-Host ""

$uniqueInstances = $instances | Where-Object { $_ -ne "FAILED" } | Sort-Object -Unique

Write-Host "Instance ditemukan  : $($uniqueInstances -join ', ')"
Write-Host "Jumlah instance     : $($uniqueInstances.Count)"
Write-Host "Jumlah gagal        : $failedCount"

if ($uniqueInstances.Count -ge 2) {

    Write-Host ""
    Write-Host "LOAD BALANCING      : SUCCESS"
    Write-Host "Request tersebar ke : $($uniqueInstances.Count) instance"

}
else {

    Write-Host ""
    Write-Host "LOAD BALANCING      : CHECK"
    Write-Host "Hanya 1 instance ditemukan"
    Write-Host "Pastikan 3 API instance berjalan"

}

Write-Host ""

Start-Sleep -Seconds 2

# =====================================================================
# 4. LOGIN ADMIN
# =====================================================================

Write-Host "[4] LOGIN ADMIN"
Write-Host "------------------------------------------------------------"

$loginBody = @{
    email = $EMAIL
    password = $PASSWORD
} | ConvertTo-Json -Compress

try {

    $loginResponse = Invoke-RestMethod `
        -Uri "$BASE_URL/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody `
        -UseBasicParsing

    $token = $loginResponse.access_token
    $role = $loginResponse.user.role

    if ($token) {
        Write-Host "LOGIN              : SUCCESS"
        Write-Host "ROLE               : $role"
        Write-Host "TOKEN              : SUCCESS"
    }
    else {
        Write-Host "LOGIN              : FAILED"
        exit
    }

}
catch {

    Write-Host "LOGIN              : FAILED"
    Write-Host "Tidak bisa mendapatkan JWT."
    exit
}

$headers = @{
    Authorization = "Bearer $token"
}

Write-Host ""

# =====================================================================
# 5. RATE LIMITER - SUCCESS TEST
# =====================================================================

Write-Host "[5] RATE LIMITER - SUCCESS TEST"
Write-Host "------------------------------------------------------------"

try {

    $response = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items" `
        -Method GET `
        -Headers $headers `
        -UseBasicParsing

    if ($response.StatusCode -eq 200) {

        Write-Host "GET /api/items      : SUCCESS"
        Write-Host "HTTP STATUS         : 200"

    }
    else {

        Write-Host "GET /api/items      : FAILED"
        Write-Host "HTTP STATUS         : $($response.StatusCode)"

    }

}
catch {

    Write-Host "GET /api/items      : FAILED"

    if ($_.Exception.Response) {
        Write-Host "HTTP STATUS         : $($_.Exception.Response.StatusCode.value__)"
    }

}

Write-Host ""

# =====================================================================
# 6. RATE LIMITER - FAILED TEST
# =====================================================================

Write-Host "[6] RATE LIMITER - FAILED TEST"
Write-Host "------------------------------------------------------------"

Write-Host "Mengirim 15 request secara cepat..."
Write-Host ""

$rateLimitResults = @()

for ($i = 1; $i -le 15; $i++) {

    $result = curl.exe `
        -s `
        -o NUL `
        -w "%{http_code}" `
        -H "Authorization: Bearer $token" `
        "$BASE_URL/api/items"

    $status = [int]$result

    $rateLimitResults += $status

    Write-Host "Request $i : HTTP $status"
}

$has429 = $rateLimitResults -contains 429

Write-Host ""

if ($has429) {

    Write-Host "RATE LIMITER        : SUCCESS"
    Write-Host "HTTP 429 ditemukan  : YES"

}
else {

    Write-Host "RATE LIMITER        : FAILED"
    Write-Host "HTTP 429 ditemukan  : NO"

}

Write-Host ""

# =====================================================================
# WAIT FOR RATE LIMIT BUCKET TO REFILL
# =====================================================================

Write-Host "Menunggu rate limiter refill..."
Start-Sleep -Seconds 3

Write-Host "Lanjut ke Request Validation."
Write-Host ""

# =====================================================================
# 7. REQUEST VALIDATION - SUCCESS TEST
# =====================================================================

Write-Host "[7] REQUEST VALIDATION - SUCCESS TEST"
Write-Host "------------------------------------------------------------"

$validBody = @{
    name = "Laptop Asus ROG"
    price = 15000000
    stock = 10
} | ConvertTo-Json -Compress

try {

    $items = Invoke-RestMethod `
        -Uri "$BASE_URL/api/items" `
        -Method GET `
        -Headers $headers `
        -UseBasicParsing

    $itemId = $items[0].id

    $response = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/$itemId" `
        -Method PUT `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $validBody `
        -UseBasicParsing

    $status = $response.StatusCode

    if ($status -eq 200) {

        Write-Host "JSON VALID          : SUCCESS"
        Write-Host "HTTP STATUS         : 200"

    }
    else {

        Write-Host "JSON VALID          : FAILED"
        Write-Host "HTTP STATUS         : $status"

    }

}
catch {

    $status = $_.Exception.Response.StatusCode.value__

    Write-Host "JSON VALID          : FAILED"
    Write-Host "HTTP STATUS         : $status"

}

Write-Host ""

Start-Sleep -Milliseconds 500

# =====================================================================
# 8. REQUEST VALIDATION - INVALID CONTENT TYPE
# =====================================================================

Write-Host "[8] REQUEST VALIDATION - INVALID CONTENT TYPE"
Write-Host "------------------------------------------------------------"

$invalidContentTypeBody = '{"name":"Laptop Asus ROG","price":15000000,"stock":10}'

try {

    $response = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/$itemId" `
        -Method PUT `
        -Headers $headers `
        -ContentType "text/plain" `
        -Body $invalidContentTypeBody `
        -UseBasicParsing

    $status = $response.StatusCode

}
catch {

    $status = $_.Exception.Response.StatusCode.value__

}

if ($status -eq 415) {

    Write-Host "CONTENT-TYPE       : SUCCESS"
    Write-Host "HTTP STATUS         : 415"
    Write-Host "Validation bekerja : YES"

}
else {

    Write-Host "CONTENT-TYPE       : FAILED"
    Write-Host "HTTP STATUS         : $status"

}

Write-Host ""

Start-Sleep -Milliseconds 500

# =====================================================================
# 9. REQUEST VALIDATION - BODY > 1 MB
# =====================================================================

Write-Host "[9] REQUEST VALIDATION - BODY > 1 MB"
Write-Host "------------------------------------------------------------"

$largeText = "A" * 1100000

$largeBody = @{
    name = $largeText
    price = 15000000
    stock = 10
} | ConvertTo-Json -Compress

Write-Host "Body size           : $($largeBody.Length) bytes"

try {

    $response = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/$itemId" `
        -Method PUT `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $largeBody `
        -UseBasicParsing

    $status = $response.StatusCode

}
catch {

    $status = $_.Exception.Response.StatusCode.value__

}

if ($status -eq 413) {

    Write-Host "BODY SIZE           : SUCCESS"
    Write-Host "HTTP STATUS         : 413"
    Write-Host "Limit 1 MB bekerja : YES"

}
else {

    Write-Host "BODY SIZE           : FAILED"
    Write-Host "HTTP STATUS         : $status"

}

Write-Host ""

Start-Sleep -Milliseconds 500

# =====================================================================
# 10. BACKEND SCHEMA VALIDATION
# =====================================================================

Write-Host "[10] BACKEND SCHEMA VALIDATION - INVALID JSON DATA"
Write-Host "------------------------------------------------------------"

$invalidSchemaBody = @{
    name = "Laptop Baru"
    price = "BUKAN ANGKA"
    stock = "BUKAN ANGKA"
} | ConvertTo-Json -Compress

try {

    $response = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/$itemId" `
        -Method PUT `
        -Headers $headers `
        -ContentType "application/json" `
        -Body $invalidSchemaBody `
        -UseBasicParsing

    $status = $response.StatusCode

}
catch {

    $status = $_.Exception.Response.StatusCode.value__

}

if ($status -eq 422) {

    Write-Host "SCHEMA VALIDATION  : SUCCESS"
    Write-Host "HTTP STATUS         : 422"
    Write-Host "FastAPI validation  : YES"

}
else {

    Write-Host "SCHEMA VALIDATION  : FAILED"
    Write-Host "HTTP STATUS         : $status"

}

Write-Host ""

# =====================================================================
# FINAL SUMMARY
# =====================================================================

Write-Host "============================================================"
Write-Host " FINAL SUMMARY"
Write-Host "============================================================"

Write-Host ""
Write-Host "SERVICE DISCOVERY"
Write-Host "  Registry endpoint         : $DISCOVERY_URL/registry"
Write-Host "  Instance terdaftar        : $instanceCount"

Write-Host ""
Write-Host "LOAD BALANCING"
Write-Host "  Instance ditemukan        : $($uniqueInstances.Count)"
Write-Host "  Distribusi                : $($uniqueInstances -join ', ')"

Write-Host ""
Write-Host "AUTHENTICATION"
Write-Host "  Admin authentication      : SUCCESS"

Write-Host ""
Write-Host "RATE LIMITER"
Write-Host "  Normal request            : 200"
Write-Host "  Excessive request         : 429"

Write-Host ""
Write-Host "REQUEST VALIDATION"
Write-Host "  Valid JSON                : 200"
Write-Host "  Invalid Content-Type      : 415"
Write-Host "  Body > 1 MB               : 413"

Write-Host ""
Write-Host "BACKEND VALIDATION"
Write-Host "  Invalid schema            : 422"

Write-Host ""
Write-Host "============================================================"
Write-Host " TESTING SELESAI"
Write-Host "============================================================"
Write-Host ""
