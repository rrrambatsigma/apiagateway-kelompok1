# API Gateway dengan Health Check, Circuit Breaker, dan Logging

API Gateway berbasis Nginx dengan fitur lengkap untuk production-ready deployment.

## 🎯 Fitur Utama

### 1. **API Gateway & Reverse Proxy**
- Routing request ke backend services
- Multiple API instances untuk high availability
- Nginx sebagai reverse proxy

### 2. **Authentication & Authorization**
- JWT-based authentication
- Role-based access control (admin, user)
- Token validation via nginx auth_request

### 3. **Rate Limiting & Request Validation**
- 5 requests/second per client IP
- Burst capacity: 5 requests
- Content-Type validation untuk POST/PUT/PATCH
- Max request body: 1 MB

### 4. **Service Discovery**
- Dynamic service registration/unregistration
- Automatic upstream configuration update
- Registry API untuk monitoring

### 5. **Health Check (Active & Passive)**
- **Active Health Check**: Service Discovery polling `/health` endpoint setiap 10 detik
- **Passive Health Check**: Nginx `max_fails` dan `fail_timeout` parameters
- Database connectivity check di backend

### 6. **Circuit Breaker**
- State machine: CLOSED → OPEN → HALF_OPEN
- Configurable failure threshold (default: 3 consecutive failures)
- Automatic service removal/addition dari upstream
- Cooldown period: 30 detik

### 7. **Load Balancing**
- Algorithm: `least_conn` (least connections)
- Multiple backend instances (3 instances default)
- Dynamic instance management

### 8. **Structured Logging**
- JSON-formatted access logs
- Metadata: timestamp, request info, upstream timing, status codes
- Error categorization (rate limit, auth, server errors)
- Real-time log analysis tools

## 🏗️ Arsitektur

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────────────┐
│          Nginx Gateway (8080)           │
│  - Rate Limiting                        │
│  - Request Validation                   │
│  - Authentication (auth_request)        │
│  - Load Balancing (least_conn)          │
│  - Structured Logging                   │
└──────┬──────────────────────────────────┘
       │
       ├──────────┬──────────┬──────────┐
       ▼          ▼          ▼          ▼
   ┌─────┐    ┌─────┐    ┌─────┐    ┌────────────┐
   │API-1│    │API-2│    │API-3│    │ Discovery  │
   │8001 │    │8002 │    │8003 │    │   8010     │
   └──┬──┘    └──┬──┘    └──┬──┘    └──────┬─────┘
      │          │          │                │
      └──────────┴──────────┴────────────────┘
                 ▼
           ┌──────────┐
           │PostgreSQL│
           │   5432   │
           └──────────┘
```

## 🚀 Quick Start

### Prerequisites
- Docker & Docker Compose
- PowerShell (untuk Windows) atau Bash (untuk Linux/Mac)

### Setup & Run

```powershell
# 1. Clone repository dan masuk ke folder
cd bagianku

# 2. Setup environment (build, start services, wait for healthy)
./scripts/setup.ps1

# 3. Monitor services (real-time dashboard)
./scripts/monitor.ps1
```

### Manual Setup

```powershell
# Copy environment file
cp .env.example .env

# Build and start services
docker compose build
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

## 📡 Endpoints

### Gateway (Port 8080)
- `GET /` - Banner & info
- `GET /healthz` - Gateway health check
- `GET /metrics` - Gateway metrics
- `POST /auth/login` - Login (public)
- `GET /api/*` - Protected API endpoints (requires auth)

### Service Discovery (Port 8010)
- `POST /register` - Register service instance
- `DELETE /register` - Unregister service instance
- `GET /registry` - View all registered services
- `GET /health` - Discovery service health

### API Instances (Ports 8001-8003)
- `GET /health` - Health check dengan database connectivity
- `POST /auth/login` - Authentication
- `GET /api/items` - List items (requires auth)
- `GET /api/users` - List users (admin only)

## 🧪 Testing

### Test Load Balancing
```powershell
./scripts/test-load-balancing.ps1
```

Verifikasi:
- ✅ Requests didistribusikan ke 3 instances
- ✅ Least-conn algorithm bekerja
- ✅ Response time konsisten

### Test Circuit Breaker
```powershell
./scripts/test-circuit-breaker.ps1
```

Flow test:
1. Stop api-2 container
2. Tunggu 3x health check failure (~30s)
3. Circuit OPEN → api-2 dihapus dari upstream
4. Verifikasi traffic hanya ke api-1 & api-3
5. Start api-2 kembali
6. Tunggu cooldown + recovery (~40s)
7. Circuit CLOSED → api-2 kembali ke upstream

### Manual Testing

#### 1. Login
```powershell
$body = @{
    email = "admin@example.com"
    password = "admin123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/auth/login" `
    -Method POST `
    -ContentType "application/json" `
    -Body $body

$token = $response.access_token
```

#### 2. Access Protected Endpoint
```powershell
$headers = @{
    "Authorization" = "Bearer $token"
}

Invoke-RestMethod -Uri "http://localhost:8080/api/items" `
    -Method GET `
    -Headers $headers
```

#### 3. Test Rate Limiting
```powershell
# Send 10 rapid requests (should hit rate limit)
1..10 | ForEach-Object {
    try {
        Invoke-RestMethod -Uri "http://localhost:8080/api/items" -Headers $headers
        Write-Host "Request $_: OK" -ForegroundColor Green
    } catch {
        Write-Host "Request $_: RATE LIMITED (429)" -ForegroundColor Red
    }
}
```

#### 4. Check Service Registry
```powershell
Invoke-RestMethod -Uri "http://localhost:8010/registry" -Method GET
```

#### 5. View Upstream Config
```powershell
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf
```

## 📊 Monitoring & Logs

### Real-time Monitoring
```powershell
./scripts/monitor.ps1
```

Dashboard menampilkan:
- Container status
- Service Discovery health & registry
- Circuit breaker states
- Upstream configuration
- Recent logs

### Log Analysis
```bash
./scripts/log-analysis.sh
```

Analisis:
- Request statistics (total, status codes)
- Rate limiting hits
- Authentication errors
- Server errors (5xx)
- Upstream response times
- Top endpoints & client IPs

### View Logs
```powershell
# All logs
docker compose logs -f

# Specific service
docker compose logs -f gateway
docker compose logs -f discovery
docker compose logs -f api-1

# JSON pretty-print (requires jq)
docker logs gateway 2>&1 | jq -C '.'
```

## ⚙️ Configuration

### Environment Variables (.env)
```bash
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=api_gateway

# JWT
JWT_SECRET=dev-secret-change-this

# Service Discovery
HEALTH_CHECK_INTERVAL=10      # Health check interval (seconds)
HEALTH_CHECK_TIMEOUT=5        # Health check timeout (seconds)
MAX_FAILURES=3                # Circuit breaker threshold
COOLDOWN_SECONDS=30           # Circuit breaker cooldown (seconds)
```

### Scaling API Instances

Add more instances di `docker-compose.yml`:

```yaml
api-4:
  build: ./services/api
  container_name: api-4
  hostname: api-4
  # ... (copy config dari api-1)
  ports:
    - "8004:8000"
  command: >
    sh -c "
      uvicorn app.main:app --host 0.0.0.0 --port 8000 &
      PID=$$!
      sleep 5
      curl -X POST http://discovery:8001/register -H 'Content-Type: application/json' -d '{\"name\":\"api\",\"host\":\"api-4\",\"port\":8000}' || true
      wait $$PID
    "
```

Auto-registration akan handle discovery dan load balancing.

## 🛠️ Development

### Project Structure
```
bagianku/
├── docker-compose.yml          # Orchestration
├── .env.example               # Environment template
├── gateway/
│   ├── nginx.conf            # Main nginx config
│   └── conf.d/
│       ├── gateway.conf      # Server block
│       ├── upstreams.conf    # Load balancing (auto-generated)
│       ├── log_formats.conf  # Custom log formats
│       └── routes/
│           ├── auth.conf     # Auth routes
│           └── api.conf      # API routes
├── services/
│   ├── api/                  # FastAPI backend
│   │   ├── app/
│   │   │   ├── main.py      # Main app + /health
│   │   │   ├── auth.py      # JWT auth logic
│   │   │   ├── models.py    # Database models
│   │   │   └── routers/     # API endpoints
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── discovery/            # Service Discovery
│       ├── app/
│       │   └── main.py      # Health check + circuit breaker
│       ├── Dockerfile
│       ├── requirements.txt
│       └── README.md
└── scripts/
    ├── setup.ps1                  # Initial setup
    ├── monitor.ps1                # Real-time monitoring
    ├── test-load-balancing.ps1    # Load balancing test
    ├── test-circuit-breaker.ps1   # Circuit breaker test
    ├── log-viewer.sh              # Log viewer
    └── log-analysis.sh            # Log analysis
```

### Adding New Features

#### 1. New API Endpoint
Edit `services/api/app/routers/*.py`:
```python
@router.get("/new-endpoint")
def new_endpoint():
    return {"message": "Hello"}
```

#### 2. Custom Nginx Location
Add to `gateway/conf.d/routes/api.conf`:
```nginx
location /api/custom {
    # Your custom config
    proxy_pass http://backend;
}
```

#### 3. Additional Logging Metadata
Edit `gateway/nginx.conf` log_format:
```nginx
log_format json_combined escape=json '{'
    # ... existing fields ...
    '"custom_field":"$your_variable"'
'}';
```

## 🐛 Troubleshooting

### Services Won't Start
```powershell
# Check logs
docker compose logs

# Rebuild without cache
docker compose build --no-cache
docker compose up -d
```

### Circuit Breaker Not Working
```powershell
# Check discovery logs
docker compose logs discovery

# Verify health check interval
docker exec discovery env | grep HEALTH

# Manual health check test
curl http://localhost:8001/health
curl http://localhost:8002/health
```

### Nginx Reload Fails
```powershell
# Test nginx config
docker exec gateway nginx -t

# Check upstreams.conf
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf

# Manual reload
docker exec gateway nginx -s reload
```

### Load Balancing Issues
```powershell
# View current upstream config
docker exec gateway cat /etc/nginx/conf.d/upstreams.conf

# Check which instances are healthy
Invoke-RestMethod http://localhost:8010/registry | ConvertTo-Json

# View distribution from logs
docker logs gateway 2>&1 | Select-String "upstream_addr"
```

## 📚 Dokumentasi Lengkap

- [Service Discovery](./services/discovery/README.md) - Health check, circuit breaker, dan dynamic upstream

## 🔒 Security Notes

⚠️ **Development Only**: Configuration ini untuk development. Untuk production:

- [ ] Ganti `JWT_SECRET` dengan value yang secure
- [ ] Enable HTTPS/TLS
- [ ] Implement proper secret management
- [ ] Harden nginx configuration
- [ ] Enable rate limiting per user (bukan hanya per IP)
- [ ] Add request/response size limits
- [ ] Enable CORS dengan proper origin restriction
- [ ] Implement audit logging
- [ ] Use network policies untuk isolasi container

## 📝 License

Educational purpose - Assignment for Desain Aplikasi course.

## 👥 Contributors

**Orang 5**: Health Check, Circuit Breaker, dan Logging implementation

### Implementasi yang Sudah Dikerjakan:

#### 1. Health Check
- ✅ Active health check via Service Discovery (polling setiap 10 detik)
- ✅ Passive health check via Nginx (max_fails, fail_timeout)
- ✅ Database connectivity check di backend API
- ✅ Endpoint `/health` di semua services

#### 2. Circuit Breaker
- ✅ State machine implementation (CLOSED → OPEN → HALF_OPEN)
- ✅ Configurable failure threshold (default: 3 failures)
- ✅ Automatic upstream update saat state berubah
- ✅ Cooldown period sebelum recovery attempt (default: 30s)

#### 3. Logging
- ✅ JSON structured logging format
- ✅ Access logs dengan metadata lengkap
- ✅ Upstream timing tracking
- ✅ Error categorization (rate limit, auth, server error)
- ✅ Real-time monitoring dashboard
- ✅ Log analysis tools

#### 4. Service Discovery
- ✅ Service registration/unregistration API
- ✅ Registry management
- ✅ Dynamic upstream generation
- ✅ Nginx reload integration

#### 5. Load Balancing
- ✅ Least connections algorithm
- ✅ Multiple API instances (3 instances)
- ✅ Auto-registration on startup
- ✅ Dynamic instance management

#### 6. Testing & Monitoring
- ✅ Setup script untuk initial deployment
- ✅ Load balancing test script
- ✅ Circuit breaker test script
- ✅ Real-time monitoring dashboard
- ✅ Log analysis script
