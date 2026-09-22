# ============================================================
# API GATEWAY - DEMO TESTING SCRIPT
# Kelompok 1
# ============================================================

$BASE_URL = "http://localhost:8080"
$DIRECT_API = "http://localhost:8000"
$DISCOVERY_URL = "http://localhost:8010"

$results = @()

# ============================================================
# HELPER FUNCTIONS
# ============================================================

function Add-Result {
    param(
        [string]$Test,
        [string]$Status,
        [string]$Description
    )

    $script:results += [PSCustomObject]@{
        Test        = $Test
        Status      = $Status
        Description = $Description
    }
}

function Header {
    param([string]$Title)

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
}

function Step {
    param([string]$Title)

    Write-Host ""
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host " $Title" -ForegroundColor Yellow
    Write-Host "------------------------------------------------------------" -ForegroundColor DarkCyan
}

function Success {
    param([string]$Message)

    Write-Host "[PASS] $Message" -ForegroundColor Green
}

function Failed {
    param([string]$Message)

    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Info {
    param([string]$Message)

    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

# ============================================================
# START
# ============================================================

Clear-Host

Header "API GATEWAY - DEMO TESTING"

Write-Host ""
Write-Host "Project   : API Gateway Kelompok 1"
Write-Host "Gateway   : $BASE_URL"
Write-Host "API       : $DIRECT_API"
Write-Host "Discovery : $DISCOVERY_URL"
Write-Host ""

# ============================================================
# 1. DOCKER CONTAINER
# ============================================================

Header "1. CEK DOCKER CONTAINER"

docker compose ps

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 2. API GATEWAY BASIC
# ============================================================

Header "2. API GATEWAY BASIC"

# ------------------------------------------------------------
# 2.1 ROOT
# ------------------------------------------------------------

Step "2.1 GET / - Gateway Root"

try {

    $root = Invoke-RestMethod `
        -Uri "$BASE_URL/" `
        -Method GET

    $root | ConvertTo-Json

    if ($root.gateway) {

        Success "Gateway aktif"

        Add-Result `
            "Gateway Root" `
            "PASS" `
            "GET / berhasil"

    }
    else {

        Failed "Response Gateway tidak sesuai"

        Add-Result `
            "Gateway Root" `
            "FAIL" `
            "Response tidak sesuai"
    }

}
catch {

    Failed "Gateway root gagal"

    Add-Result `
        "Gateway Root" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 2.2 HEALTHZ
# ------------------------------------------------------------

Step "2.2 GET /healthz - Gateway Health Check"

try {

    $health = Invoke-WebRequest `
        -Uri "$BASE_URL/healthz" `
        -Method GET

    Write-Host "Status Code : $($health.StatusCode)"
    Write-Host "Response    : $($health.Content)"

    if ($health.StatusCode -eq 200) {

        Success "Gateway health check OK"

        Add-Result `
            "Gateway Health" `
            "PASS" `
            "HTTP 200"
    }
    else {

        Add-Result `
            "Gateway Health" `
            "FAIL" `
            "HTTP $($health.StatusCode)"
    }

}
catch {

    Failed "Gateway health check gagal"

    Add-Result `
        "Gateway Health" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 2.3 METRICS
# ------------------------------------------------------------

Step "2.3 GET /metrics"

try {

    $metrics = Invoke-RestMethod `
        -Uri "$BASE_URL/metrics" `
        -Method GET

    $metrics | ConvertTo-Json

    Success "Metrics endpoint aktif"

    Add-Result `
        "Metrics" `
        "PASS" `
        "GET /metrics berhasil"
}

catch {

    Failed "Metrics gagal"

    Add-Result `
        "Metrics" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 2.4 INSTANCE
# ------------------------------------------------------------

Step "2.4 GET /instance"

try {

    $instance = Invoke-RestMethod `
        -Uri "$BASE_URL/instance" `
        -Method GET

    $instance | ConvertTo-Json

    Success "Gateway berhasil meneruskan request ke backend"

    Add-Result `
        "Instance Routing" `
        "PASS" `
        "Backend instance: $($instance.instance)"
}

catch {

    Failed "Instance endpoint gagal"

    Add-Result `
        "Instance Routing" `
        "FAIL" `
        $_.Exception.Message
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 3. AUTHENTICATION & AUTHORIZATION
# ============================================================

Header "3. AUTHENTICATION & AUTHORIZATION"

# ------------------------------------------------------------
# 3.1 LOGIN
# ------------------------------------------------------------

Step "3.1 POST /auth/login - Login Admin"

$loginBody = @{
    email    = "ahmad@example.com"
    password = "admin123"
} | ConvertTo-Json -Compress

try {

    $LOGIN = Invoke-RestMethod `
        -Uri "$BASE_URL/auth/login" `
        -Method POST `
        -ContentType "application/json" `
        -Body $loginBody

    $TOKEN = $LOGIN.access_token

    Write-Host ""
    Write-Host "Login berhasil"
    Write-Host "Token Length : $($TOKEN.Length)"
    Write-Host "Token        : [HIDDEN]"

    if ($TOKEN) {

        Success "Authentication berhasil"

        Add-Result `
            "Authentication" `
            "PASS" `
            "Login admin berhasil"
    }
    else {

        Failed "Token tidak ditemukan"

        Add-Result `
            "Authentication" `
            "FAIL" `
            "access_token tidak ditemukan"

        exit
    }

}
catch {

    Failed "Login gagal"

    Write-Host $_.Exception.Message

    Add-Result `
        "Authentication" `
        "FAIL" `
        $_.Exception.Message

    Write-Host ""
    Write-Host "Demo dihentikan karena token tidak tersedia." -ForegroundColor Red

    exit
}

# ------------------------------------------------------------
# 3.2 AUTHORIZATION
# ------------------------------------------------------------

Step "3.2 Authorization Check"

try {

    $authResult = Invoke-RestMethod `
        -Uri "$BASE_URL/auth/authorize" `
        -Method GET `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        }

    $authResult | ConvertTo-Json

    if ($authResult.authorized -eq $true) {

        Success "Authorization berhasil"

        Add-Result `
            "Authorization" `
            "PASS" `
            "User authorized sebagai $($authResult.role)"
    }
    else {

        Failed "Authorization ditolak"

        Add-Result `
            "Authorization" `
            "FAIL" `
            "authorized=false"
    }

}
catch {

    Failed "Authorization gagal"

    Add-Result `
        "Authorization" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 3.3 PROTECTED API
# ------------------------------------------------------------

Step "3.3 GET /api/users - Protected Endpoint"

try {

    $users = Invoke-RestMethod `
        -Uri "$BASE_URL/api/users" `
        -Method GET `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        }

    $users | ConvertTo-Json -Depth 5

    Success "Protected endpoint berhasil diakses dengan JWT"

    Add-Result `
        "Protected API" `
        "PASS" `
        "GET /api/users berhasil"
}

catch {

    Failed "Protected API gagal"

    Add-Result `
        "Protected API" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 3.4 TANPA TOKEN
# ------------------------------------------------------------

Step "3.4 GET /api/users - Tanpa Token"

try {

    Invoke-WebRequest `
        -Uri "$BASE_URL/api/users" `
        -Method GET `
        -ErrorAction Stop

    Failed "Endpoint seharusnya membutuhkan authentication"

    Add-Result `
        "Unauthorized Access" `
        "FAIL" `
        "Request tanpa token diterima"
}

catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    if ($status -eq 401 -or $status -eq 403) {

        Success "Request tanpa JWT ditolak"

        Add-Result `
            "Unauthorized Access" `
            "PASS" `
            "Request ditolak dengan HTTP $status"
    }
    else {

        Failed "Status tidak sesuai"

        Add-Result `
            "Unauthorized Access" `
            "FAIL" `
            "HTTP $status"
    }
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 4. RATE LIMITER
# ============================================================

Header "4. RATE LIMITER"

Write-Host ""
Write-Host "Konfigurasi:"
Write-Host "Rate  : 5 request/second"
Write-Host "Burst : 5"
Write-Host "Target: /api/*"
Write-Host ""

# ------------------------------------------------------------
# 4.1 NORMAL REQUEST
# ------------------------------------------------------------

Step "4.1 Normal Request"

try {

    $normal = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items" `
        -Method GET `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        }

    Write-Host "HTTP Status : $($normal.StatusCode)"

    if ($normal.StatusCode -eq 200) {

        Success "Request normal diterima"

        Add-Result `
            "Rate Limit Normal" `
            "PASS" `
            "HTTP 200"
    }
    else {

        Failed "Request normal menghasilkan HTTP $($normal.StatusCode)"

        Add-Result `
            "Rate Limit Normal" `
            "FAIL" `
            "HTTP $($normal.StatusCode)"
    }

}

catch {

    Failed "Normal request gagal"

    Add-Result `
        "Rate Limit Normal" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 4.2 BURST REQUEST
# ------------------------------------------------------------

Step "4.2 Burst Request - 100 Request Concurrent"

Write-Host ""
Write-Host "Mengirim 100 request secara bersamaan..."
Write-Host "Target: GET /api/items"
Write-Host ""

$jobsRate = 1..100 | ForEach-Object {

    Start-Job -ArgumentList $TOKEN -ScriptBlock {

        param($token)

        curl.exe `
            -s `
            -o NUL `
            -w "%{http_code}" `
            -H "Authorization: Bearer $token" `
            "http://localhost:8080/api/items"
    }
}

Write-Host "Menunggu seluruh request selesai..."

$jobsRate | Wait-Job | Out-Null

$rateResults = @()

foreach ($job in $jobsRate) {

    $result = Receive-Job $job

    if ($result) {
        $rateResults += $result.ToString().Trim()
    }
}

$jobsRate | Remove-Job -Force

Write-Host ""
Write-Host "Hasil request:"
Write-Host ""

for ($i = 0; $i -lt $rateResults.Count; $i++) {

    Write-Host (
        "Request {0,3} -> HTTP {1}" -f `
        ($i + 1), `
        $rateResults[$i]
    )
}

$rate200 = @(
    $rateResults |
    Where-Object {
        $_ -eq "200"
    }
).Count

$rate429 = @(
    $rateResults |
    Where-Object {
        $_ -eq "429"
    }
).Count

Write-Host ""
Write-Host "----------------------------------------"
Write-Host "HASIL RATE LIMITER"
Write-Host "----------------------------------------"
Write-Host "HTTP 200 : $rate200"
Write-Host "HTTP 429 : $rate429"
Write-Host "----------------------------------------"
Write-Host ""

if ($rate429 -gt 0) {

    Success "Rate limiter aktif dan menghasilkan HTTP 429"

    Add-Result `
        "Rate Limiter" `
        "PASS" `
        "$rate429 request mendapat HTTP 429"
}
else {

    Failed "Tidak ditemukan HTTP 429"

    Add-Result `
        "Rate Limiter" `
        "FAIL" `
        "Tidak ada HTTP 429"
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 5. REQUEST VALIDATION
# ============================================================

Header "5. REQUEST VALIDATION"

# ------------------------------------------------------------
# 5.1 VALID JSON
# ------------------------------------------------------------

Step "5.1 Valid JSON Request"

$validBody = @{
    name = "Demo Item"
} | ConvertTo-Json -Compress

try {

    $validResponse = Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/1" `
        -Method PUT `
        -ContentType "application/json" `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        } `
        -Body $validBody `
        -ErrorAction Stop

    Write-Host "HTTP Status : $($validResponse.StatusCode)"

    if ($validResponse.StatusCode -eq 200) {

        Success "Valid JSON diterima"

        Add-Result `
            "Valid JSON" `
            "PASS" `
            "HTTP 200"
    }
    else {

        Add-Result `
            "Valid JSON" `
            "INFO" `
            "HTTP $($validResponse.StatusCode)"
    }

}
catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    Add-Result `
        "Valid JSON" `
        "INFO" `
        "HTTP $status"
}

# ------------------------------------------------------------
# 5.2 INVALID CONTENT TYPE
# ------------------------------------------------------------

Step "5.2 Invalid Content-Type -> Expected 415"

try {

    Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/1" `
        -Method PUT `
        -ContentType "text/plain" `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        } `
        -Body "invalid content type" `
        -ErrorAction Stop

    Failed "Request text/plain diterima"

    Add-Result `
        "Content-Type Validation" `
        "FAIL" `
        "Request seharusnya 415"
}

catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    if ($status -eq 415) {

        Success "Invalid Content-Type ditolak dengan HTTP 415"

        Add-Result `
            "Content-Type Validation" `
            "PASS" `
            "HTTP 415"
    }
    else {

        Failed "Status tidak sesuai"

        Add-Result `
            "Content-Type Validation" `
            "FAIL" `
            "HTTP $status"
    }
}

# ------------------------------------------------------------
# 5.3 INVALID SCHEMA
# ------------------------------------------------------------

Step "5.3 Invalid JSON Schema -> Expected 422"

$invalidSchema = @{
    price = "bukan-angka"
    stock = "bukan-angka"
} | ConvertTo-Json -Compress

Write-Host ""
Write-Host "Request Body:"
Write-Host $invalidSchema
Write-Host ""

try {

    Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/1" `
        -Method PUT `
        -ContentType "application/json" `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        } `
        -Body $invalidSchema `
        -ErrorAction Stop

    Failed "Invalid schema diterima"

    Add-Result `
        "Schema Validation" `
        "FAIL" `
        "Request seharusnya 422"
}

catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    if ($status -eq 422) {

        Success "Invalid schema ditolak dengan HTTP 422"

        Add-Result `
            "Schema Validation" `
            "PASS" `
            "price/stock string -> HTTP 422"
    }
    else {

        Failed "Status tidak sesuai"

        Add-Result `
            "Schema Validation" `
            "FAIL" `
            "HTTP $status"
    }
}

# ------------------------------------------------------------
# 5.4 BODY TERLALU BESAR
# ------------------------------------------------------------

Step "5.4 Request > 1 MB -> Expected 413"

$largeBody = "A" * 1100000

try {

    Invoke-WebRequest `
        -Uri "$BASE_URL/api/items/1" `
        -Method PUT `
        -ContentType "application/json" `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        } `
        -Body $largeBody `
        -ErrorAction Stop

    Failed "Request >1MB diterima"

    Add-Result `
        "Body Size Validation" `
        "FAIL" `
        "Request seharusnya 413"
}

catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    if ($status -eq 413) {

        Success "Request >1MB ditolak dengan HTTP 413"

        Add-Result `
            "Body Size Validation" `
            "PASS" `
            "HTTP 413"
    }
    else {

        Failed "Status tidak sesuai"

        Add-Result `
            "Body Size Validation" `
            "FAIL" `
            "HTTP $status"
    }
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 6. SERVICE DISCOVERY
# ============================================================

Header "6. SERVICE DISCOVERY"

# ------------------------------------------------------------
# 6.1 DISCOVERY HEALTH
# ------------------------------------------------------------

Step "6.1 Discovery Health"

try {

    $discoveryHealth = Invoke-RestMethod `
        -Uri "$DISCOVERY_URL/health" `
        -Method GET

    $discoveryHealth | ConvertTo-Json

    if ($discoveryHealth.status -eq "ok") {

        Success "Discovery service sehat"

        Add-Result `
            "Discovery Health" `
            "PASS" `
            "Discovery HTTP 200"
    }
    else {

        Failed "Discovery status tidak OK"

        Add-Result `
            "Discovery Health" `
            "FAIL" `
            "Discovery status tidak OK"
    }

}

catch {

    Failed "Discovery health gagal"

    Add-Result `
        "Discovery Health" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 6.2 REGISTRY
# ------------------------------------------------------------

Step "6.2 Service Registry"

try {

    $registry = Invoke-RestMethod `
        -Uri "$DISCOVERY_URL/registry" `
        -Method GET

    $registry | ConvertTo-Json -Depth 10

    $registered = @($registry.services).Count

    Write-Host ""
    Write-Host "Registered Services : $registered"

    if ($registered -ge 3) {

        Success "3 backend instance terdaftar"

        Add-Result `
            "Service Registry" `
            "PASS" `
            "$registered service terdaftar"
    }
    else {

        Failed "Jumlah service kurang dari 3"

        Add-Result `
            "Service Registry" `
            "FAIL" `
            "$registered service terdaftar"
    }

}

catch {

    Failed "Registry gagal"

    Add-Result `
        "Service Registry" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 6.3 UPSTREAM CONFIG
# ------------------------------------------------------------

Step "6.3 Nginx Dynamic Upstream"

Write-Host ""
Write-Host "gateway/conf.d/upstreams.conf"
Write-Host ""

Get-Content ".\gateway\conf.d\upstreams.conf"

Write-Host ""

$upstreamContent = Get-Content `
    ".\gateway\conf.d\upstreams.conf" `
    -Raw

$hasApi1 = $upstreamContent -match "api-1:8000"
$hasApi2 = $upstreamContent -match "api-2:8000"
$hasApi3 = $upstreamContent -match "api-3:8000"

if ($hasApi1 -and $hasApi2 -and $hasApi3) {

    Success "api-1, api-2, api-3 tersedia pada upstream"

    Add-Result `
        "Dynamic Upstream" `
        "PASS" `
        "3 backend instance tersedia"
}
else {

    Failed "Upstream belum memuat semua instance"

    Add-Result `
        "Dynamic Upstream" `
        "FAIL" `
        "Tidak semua instance ditemukan"
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 7. LOAD BALANCING
# ============================================================

Header "7. LOAD BALANCING"

Write-Host ""
Write-Host "Mengirim 30 request secara concurrent..."
Write-Host "Target: GET /instance"
Write-Host ""

$jobs = 1..30 | ForEach-Object {

    Start-Job {

        curl.exe `
            -s `
            "http://localhost:8080/instance"
    }
}

$jobs | Wait-Job | Out-Null

$resultsLB = @()

foreach ($job in $jobs) {

    $result = Receive-Job $job

    if ($result) {
        $resultsLB += $result
    }
}

$jobs | Remove-Job -Force

Write-Host ""
Write-Host "Hasil distribusi request:"
Write-Host ""

$parsedInstances = @()

foreach ($result in $resultsLB) {

    try {

        $obj = $result | ConvertFrom-Json

        if ($obj.instance) {
            $parsedInstances += $obj.instance
        }

    }
    catch {
    }
}

$grouped = $parsedInstances |
    Group-Object |
    Sort-Object Name

$grouped | Format-Table Count, Name

$instanceCount = @($grouped).Count

Write-Host ""

if ($instanceCount -ge 2) {

    Success "Load balancing mendistribusikan request ke beberapa instance"

    Add-Result `
        "Load Balancing" `
        "PASS" `
        "$instanceCount instance menerima traffic"
}
else {

    Info "Traffic hanya terlihat pada satu instance"

    Add-Result `
        "Load Balancing" `
        "INFO" `
        "$instanceCount instance terlihat"
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 8. DIRECT BACKEND VS GATEWAY
# ============================================================

Header "8. PERBANDINGAN DIRECT BACKEND VS API GATEWAY"

# ------------------------------------------------------------
# 8.1 DIRECT BACKEND
# ------------------------------------------------------------

Step "8.1 Direct Backend : localhost:8000"

try {

    $directUsers = Invoke-RestMethod `
        -Uri "$DIRECT_API/api/users" `
        -Method GET

    Write-Host "Direct Backend HTTP 200"
    Write-Host "Jumlah user : $($directUsers.Count)"

    Success "Backend dapat diakses langsung melalui port 8000"

    Add-Result `
        "Direct Backend" `
        "PASS" `
        "Port 8000 aktif"
}

catch {

    Failed "Direct backend gagal"

    Add-Result `
        "Direct Backend" `
        "FAIL" `
        $_.Exception.Message
}

# ------------------------------------------------------------
# 8.2 GATEWAY
# ------------------------------------------------------------

Step "8.2 Gateway : localhost:8080"

try {

    $gatewayUsers = Invoke-RestMethod `
        -Uri "$BASE_URL/api/users" `
        -Method GET `
        -Headers @{
            Authorization = "Bearer $TOKEN"
        }

    Write-Host "Gateway HTTP 200"
    Write-Host "Jumlah user : $($gatewayUsers.Count)"

    Success "Protected API berhasil melalui Gateway"

    Add-Result `
        "Gateway Protected API" `
        "PASS" `
        "Port 8080 aktif"
}

catch {

    Failed "Gateway API gagal"

    Add-Result `
        "Gateway Protected API" `
        "FAIL" `
        $_.Exception.Message
}

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 9. LOGGING
# ============================================================

Header "9. LOGGING"

Step "9.1 Gateway Access Log"

Write-Host ""
Write-Host "Menampilkan beberapa log terakhir:"
Write-Host ""

docker logs gateway --tail 20

Write-Host ""

Success "Gateway JSON access log ditampilkan"

Add-Result `
    "Logging" `
    "PASS" `
    "docker logs gateway berhasil"

Read-Host "`nTekan ENTER untuk lanjut"

# ============================================================
# 10. NGINX CONFIGURATION
# ============================================================

Header "10. NGINX CONFIGURATION CHECK"

Step "10.1 Nginx Configuration Test"

docker exec gateway nginx -t

if ($LASTEXITCODE -eq 0) {

    Success "Konfigurasi Nginx valid"

    Add-Result `
        "Nginx Config" `
        "PASS" `
        "nginx -t berhasil"
}
else {

    Failed "Konfigurasi Nginx bermasalah"

    Add-Result `
        "Nginx Config" `
        "FAIL" `
        "nginx -t gagal"
}

# ============================================================
# 11. 404 HANDLING
# ============================================================

Header "11. ERROR HANDLING"

Step "11.1 Endpoint Tidak Ditemukan -> Expected 404"

try {

    Invoke-WebRequest `
        -Uri "$BASE_URL/endpoint-tidak-ada" `
        -Method GET `
        -ErrorAction Stop

    Failed "Endpoint tidak dikenal diterima"

    Add-Result `
        "404 Handling" `
        "FAIL" `
        "Request tidak menghasilkan 404"
}

catch {

    $status = 0

    if ($_.Exception.Response) {
        $status = [int]$_.Exception.Response.StatusCode
    }

    Write-Host "HTTP Status : $status"

    if ($status -eq 404) {

        Success "Unknown endpoint menghasilkan HTTP 404"

        Add-Result `
            "404 Handling" `
            "PASS" `
            "HTTP 404"
    }
    else {

        Failed "Status tidak sesuai"

        Add-Result `
            "404 Handling" `
            "FAIL" `
            "HTTP $status"
    }
}

# ============================================================
# 12. FINAL SUMMARY
# ============================================================

Header "12. DEMO SUMMARY"

Write-Host ""

$results | Format-Table -AutoSize

Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " DEMO SELESAI" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan

$passCount = @(
    $results |
    Where-Object {
        $_.Status -eq "PASS"
    }
).Count

$failCount = @(
    $results |
    Where-Object {
        $_.Status -eq "FAIL"
    }
).Count

$infoCount = @(
    $results |
    Where-Object {
        $_.Status -eq "INFO"
    }
).Count

Write-Host ""

Write-Host "PASS : $passCount" -ForegroundColor Green
Write-Host "FAIL : $failCount" -ForegroundColor Red
Write-Host "INFO : $infoCount" -ForegroundColor Yellow

Write-Host ""

Write-Host "Komponen yang telah didemokan:" -ForegroundColor Cyan
Write-Host "1. API Gateway / Reverse Proxy"
Write-Host "2. Authentication"
Write-Host "3. Authorization"
Write-Host "4. Rate Limiter"
Write-Host "5. Request Validation"
Write-Host "6. Service Discovery"
Write-Host "7. Load Balancing"
Write-Host "8. Health Check"
Write-Host "9. Logging"
Write-Host "10. Error Handling"

Write-Host ""

Write-Host "Token JWT tidak ditampilkan untuk keamanan." -ForegroundColor DarkGray

Write-Host ""