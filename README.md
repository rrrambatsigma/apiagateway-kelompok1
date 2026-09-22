# API Gateway Kelompok 1

Implementasi **API Gateway** menggunakan **Nginx** sebagai pintu masuk utama untuk mengatur komunikasi antara client dengan beberapa instance backend service.

Project ini menerapkan beberapa konsep dalam arsitektur **distributed system**, yaitu:

- API Gateway & Reverse Proxy
- Authentication & Authorization
- Rate Limiting
- Request Validation
- Service Discovery
- Load Balancing
- Health Check
- Circuit Breaker
- Request Logging
- Docker Containerization

---

## 1. Overview

Pada sistem tanpa API Gateway, client harus berkomunikasi langsung dengan masing-masing backend service.

Pada project ini, seluruh request client masuk melalui **API Gateway** terlebih dahulu.

```text
                         Client
                           |
                           | HTTP :8080
                           v
                  +-------------------+
                  |   Nginx Gateway   |
                  |     Port 8080     |
                  +---------+---------+
                            |
             +--------------+--------------+
             |              |              |
             v              v              v
          api-1:8000     api-2:8000     api-3:8000
             |              |              |
             +--------------+--------------+
                            |
                            v
                       PostgreSQL
                         :5432


                  +-------------------+
                  | Service Discovery |
                  |      :8010        |
                  +---------+---------+
                            |
                            v
                     Service Registry
                    api-1 / api-2 / api-3
```

API Gateway bertanggung jawab untuk menerima request dari client, menerapkan beberapa mekanisme seperti authentication, rate limiting, dan request validation, kemudian meneruskan request ke backend service yang tersedia.

Service Discovery digunakan untuk mengetahui instance backend yang tersedia dan status kesehatannya.

---

## 2. Tujuan Project

Project ini bertujuan untuk membangun API Gateway yang dapat:

1. Menjadi pintu masuk utama client ke backend service.
2. Meneruskan request menggunakan reverse proxy.
3. Melakukan authentication dan authorization.
4. Membatasi jumlah request menggunakan rate limiter.
5. Melakukan validasi terhadap request.
6. Menemukan backend service menggunakan service discovery.
7. Membagi request ke beberapa instance menggunakan load balancing.
8. Memantau kesehatan service.
9. Menangani kegagalan service menggunakan circuit breaker.
10. Mencatat aktivitas request melalui logging.

---

# 3. Arsitektur Sistem

## 3.1 Komponen Utama

Project terdiri dari beberapa komponen utama:

| Komponen | Teknologi | Port | Fungsi |
|---|---|---:|---|
| API Gateway | Nginx | `8080` | Gateway dan reverse proxy |
| Backend API | FastAPI | `8000` | Menyediakan API |
| API Instance 1 | FastAPI | `8000` | Backend instance |
| API Instance 2 | FastAPI | `8000` | Backend instance |
| API Instance 3 | FastAPI | `8000` | Backend instance |
| Service Discovery | FastAPI | `8010` | Registry dan health monitoring |
| Database | PostgreSQL | `5432` | Penyimpanan data |

> Port `8000` merupakan port internal backend. Instance `api-1` juga diekspos ke host untuk kebutuhan pengujian langsung.

---

## 3.2 Alur Request

Secara umum request berjalan melalui alur:

```text
Client
  |
  v
Nginx API Gateway :8080
  |
  +--> Authentication & Authorization
  |
  +--> Rate Limiting
  |
  +--> Request Validation
  |
  v
Service Discovery
  |
  v
Load Balancing
  |
  +--------+--------+
  |        |        |
  v        v        v
api-1    api-2    api-3
:8000    :8000    :8000
  |        |        |
  +--------+--------+
           |
           v
      PostgreSQL
        :5432
```

---

# 4. Fitur yang Diimplementasikan

## 4.1 API Gateway & Reverse Proxy

Nginx digunakan sebagai API Gateway dan reverse proxy.

Client mengakses sistem melalui:

```text
http://localhost:8080
```

Beberapa endpoint utama:

```text
GET  /
GET  /healthz
GET  /metrics
GET  /instance

POST /auth/login

GET  /api/*
```

Gateway kemudian meneruskan request ke backend service yang sesuai.

---

## 4.2 Authentication & Authorization

Sistem menggunakan **JWT (JSON Web Token)** untuk authentication.

Alur authentication:

```text
Client
  |
  | POST /auth/login
  v
Backend
  |
  | JWT Token
  v
Client
  |
  | Authorization: Bearer <TOKEN>
  v
API Gateway
  |
  v
Protected API
```

Authentication digunakan untuk melakukan login dan mendapatkan token.

Authorization digunakan untuk menentukan apakah user memiliki hak akses terhadap endpoint tertentu.

Request tanpa token yang valid akan ditolak.

---

## 4.3 Rate Limiting

Gateway menggunakan Nginx `limit_req` untuk membatasi jumlah request dari client.

Konfigurasi:

```text
Rate  : 5 request/second
Burst : 5 request
```

Rate limiter diterapkan pada route:

```text
/api/*
```

Jika request melebihi batas yang ditentukan, Gateway memberikan:

```text
HTTP 429 Too Many Requests
```

---

## 4.4 Request Validation

Request divalidasi sebelum diproses oleh service.

### Content-Type Validation

Request `POST`, `PUT`, dan `PATCH` harus menggunakan JSON.

Jika Content-Type tidak sesuai:

```text
HTTP 415 Unsupported Media Type
```

### Schema Validation

Backend melakukan validasi terhadap struktur dan tipe data request.

Request yang tidak sesuai schema akan menghasilkan:

```text
HTTP 422 Unprocessable Entity
```

### Body Size Validation

Ukuran request body dibatasi hingga:

```text
1 MB
```

Jika melebihi batas:

```text
HTTP 413 Request Entity Too Large
```

---

## 4.5 Service Discovery

Service Discovery digunakan untuk mengetahui backend service yang tersedia.

Service Discovery berjalan pada:

```text
http://localhost:8010
```

Endpoint utama:

```text
GET /health
GET /registry
```

Contoh service yang terdaftar:

```text
api-1:8000
api-2:8000
api-3:8000
```

Service Discovery juga melakukan health checking terhadap service yang terdaftar.

---

## 4.6 Load Balancing

Nginx digunakan untuk membagi request ke beberapa backend instance.

Metode load balancing yang digunakan:

```text
least_conn
```

Backend yang tersedia:

```text
api-1
api-2
api-3
```

Dengan demikian, request client dapat diteruskan ke instance backend yang berbeda.

Distribusi request tidak harus sama rata karena metode yang digunakan adalah `least_conn`, yaitu memilih backend berdasarkan jumlah koneksi aktif.

---

## 4.7 Health Check

Health check digunakan untuk mengetahui kondisi service.

### Gateway

```text
GET /healthz
```

### Backend

```text
GET /health
```

### Service Discovery

```text
GET /health
```

Selain endpoint health, Docker Compose juga menggunakan health check untuk memastikan container berada dalam kondisi yang sesuai.

---

## 4.8 Circuit Breaker

Service Discovery memiliki mekanisme **Circuit Breaker** untuk menangani service yang mengalami kegagalan.

State Circuit Breaker:

```text
             failure >= 3
CLOSED --------------------> OPEN
  ^                            |
  |                            |
  | success                    | cooldown 30s
  |                            |
  +-------- HALF_OPEN <--------+
              |
              |
              +---- failure ----> OPEN
```

Konfigurasi:

```text
Maximum consecutive failures : 3
Cooldown                     : 30 seconds
```

State Circuit Breaker:

- `CLOSED` — service dalam kondisi normal.
- `OPEN` — service dianggap mengalami kegagalan.
- `HALF_OPEN` — sistem mencoba kembali mengakses service setelah cooldown.

---

## 4.9 Logging

Gateway menghasilkan request log dalam format JSON.

Informasi yang dicatat antara lain:

```text
timestamp
remote_addr
request_id
request_method
request_uri
status
upstream_addr
upstream_status
upstream_response_time
request_time
```

Log Gateway dapat dilihat menggunakan:

```powershell
docker logs gateway
```

Untuk melihat log secara realtime:

```powershell
docker logs -f gateway
```

---

# 5. Teknologi yang Digunakan

| Teknologi | Fungsi |
|---|---|
| Nginx | API Gateway & Reverse Proxy |
| FastAPI | Backend API dan Service Discovery |
| PostgreSQL | Database |
| Python | Backend |
| Docker | Containerization |
| Docker Compose | Menjalankan seluruh service |
| JWT | Authentication |
| PowerShell | Testing |
| Service Discovery | Registry dan health monitoring |

---

# 6. Struktur Project

```text
apiagateway-kelompok1/
│
├── gateway/
│   ├── nginx.conf
│   └── conf.d/
│       ├── gateway.conf
│       ├── upstreams.conf
│       ├── log_formats.conf
│       └── routes/
│           ├── api.conf
│           ├── auth.conf
│           └── instance.conf
│
├── services/
│   ├── api/
│   │   └── app/
│   │       ├── main.py
│   │       ├── auth.py
│   │       └── routers/
│   │
│   └── discovery/
│       └── app/
│           └── main.py
│
├── docker-compose.yml
├── testing.ps1
├── demo.ps1
└── README.md
```

---

# 7. Prerequisites

Sebelum menjalankan project, pastikan sudah terinstall:

- Docker Desktop
- Docker Compose
- Git
- PowerShell

Pastikan Docker Desktop sudah berjalan.

Cek Docker:

```powershell
docker --version
```

Cek Docker Compose:

```powershell
docker compose version
```

---

# 8. Menjalankan Project

## 8.1 Clone Repository

Clone repository:

```powershell
git clone https://github.com/rrrambatsigma/apiagateway-kelompok1.git
```

Masuk ke directory project:

```powershell
cd apiagateway-kelompok1
```

---

## 8.2 Menjalankan Docker Compose

Project dijalankan menggunakan Docker Compose.

Gunakan command:

```powershell
docker compose --env-file .env -f infra/docker-compose.yml up -d --build --wait --wait-timeout 180
```

Command tersebut akan:

1. Membaca konfigurasi `.env`.
2. Membaca Docker Compose dari `infra/docker-compose.yml`.
3. Build image yang diperlukan.
4. Menjalankan seluruh container.
5. Menunggu service sampai kondisi siap.

---

## 8.3 Mengecek Container

Setelah proses selesai, cek container:

```powershell
docker compose -f infra/docker-compose.yml ps
```

atau:

```powershell
docker ps
```

Container yang diharapkan:

```text
gateway
api-1
api-2
api-3
discovery
db
```

---

# 9. Pengujian API Gateway

## 9.1 Gateway Root

```powershell
curl.exe -i http://localhost:8080/
```

## 9.2 Gateway Health

```powershell
curl.exe -i http://localhost:8080/healthz
```

## 9.3 Metrics

```powershell
curl.exe -i http://localhost:8080/metrics
```

## 9.4 Instance Routing

```powershell
curl.exe -i http://localhost:8080/instance
```

---

# 10. Pengujian Backend Secara Langsung

Backend `api-1` dapat diakses langsung melalui:

```text
http://localhost:8000
```

Contoh health check:

```powershell
curl.exe -i http://localhost:8000/health
```

Contoh endpoint API:

```powershell
curl.exe -i http://localhost:8000/api/users
```

Perbedaan akses:

```text
Port 8000
    |
    +--> Direct Backend

Port 8080
    |
    +--> API Gateway
            |
            +--> Backend
```

Port `8080` merupakan jalur utama melalui API Gateway.

---

# 11. Pengujian Service Discovery

Health check:

```powershell
curl.exe -i http://localhost:8010/health
```

Melihat service registry:

```powershell
curl.exe -i http://localhost:8010/registry
```

Registry diharapkan berisi:

```text
api-1
api-2
api-3
```

---

# 12. Authentication

Untuk mendapatkan JWT token, gunakan PowerShell:

```powershell
$loginBody = @{
    email = "ahmad@example.com"
    password = "admin123"
} | ConvertTo-Json -Compress

$LOGIN = Invoke-RestMethod `
    -Uri "http://localhost:8080/auth/login" `
    -Method POST `
    -ContentType "application/json" `
    -Body $loginBody

$TOKEN = $LOGIN.access_token
```

Cek apakah token berhasil diperoleh:

```powershell
$TOKEN.Length
```

Token dapat digunakan untuk mengakses protected endpoint:

```powershell
Invoke-RestMethod `
    -Uri "http://localhost:8080/api/users" `
    -Method GET `
    -Headers @{ Authorization = "Bearer $TOKEN" }
```

> Untuk lingkungan nyata, jangan membagikan JWT token atau credential ke repository maupun dokumentasi.

---

# 13. Menjalankan Testing

Project menyediakan script PowerShell untuk melakukan pengujian seluruh fitur.

Jalankan:

```powershell
.\testing.ps1
```

Jika PowerShell menolak execution policy:

```powershell
powershell -ExecutionPolicy Bypass -File .\testing.ps1
```

Testing mencakup:

### API Gateway

- Gateway Root
- Gateway Health
- Metrics
- Instance Routing

### Authentication & Authorization

- Authentication
- Authorization
- Protected API
- Unauthorized Access

### Rate Limiter & Request Validation

- Rate Limit Normal
- Rate Limiter
- Valid JSON
- Content-Type Validation
- Schema Validation
- Body Size Validation

### Service Discovery & Load Balancing

- Discovery Health
- Service Registry
- Dynamic Upstream
- Load Balancing

### Monitoring & Reliability

- Direct Backend
- Gateway Protected API
- Logging
- Nginx Config
- 404 Handling

---

# 14. Hasil Pengujian

Hasil pengujian terakhir:

| Test | Status | Keterangan |
|---|---|---|
| Gateway Root | PASS | GET `/` berhasil |
| Gateway Health | PASS | HTTP 200 |
| Metrics | PASS | GET `/metrics` berhasil |
| Instance Routing | PASS | Backend instance terdeteksi |
| Authentication | PASS | Login admin berhasil |
| Authorization | PASS | User authorized |
| Protected API | PASS | GET `/api/users` berhasil |
| Unauthorized Access | PASS | Request ditolak HTTP 403 |
| Rate Limit Normal | PASS | HTTP 200 |
| Rate Limiter | PASS | HTTP 429 terdeteksi |
| Valid JSON | PASS | HTTP 200 |
| Content-Type Validation | PASS | HTTP 415 |
| Schema Validation | PASS | HTTP 422 |
| Body Size Validation | PASS | HTTP 413 |
| Discovery Health | PASS | Discovery HTTP 200 |
| Service Registry | PASS | 3 service terdaftar |
| Dynamic Upstream | PASS | 3 backend tersedia |
| Load Balancing | PASS | Beberapa instance menerima traffic |
| Direct Backend | PASS | Port 8000 aktif |
| Gateway Protected API | PASS | Port 8080 aktif |
| Logging | PASS | Gateway log tersedia |
| Nginx Config | PASS | `nginx -t` berhasil |
| 404 Handling | PASS | HTTP 404 |

### Ringkasan

```text
23 PASS
0 FAIL
```

---

# 15. Pengujian Rate Limiter

Rate limiter menggunakan konfigurasi:

```text
Rate  : 5 request/second
Burst : 5
```

Pengujian dilakukan dengan mengirimkan request secara bersamaan.

Request yang masih diterima:

```text
HTTP 200
```

Request yang melebihi batas:

```text
HTTP 429 Too Many Requests
```

Hasil pengujian menunjukkan bahwa rate limiter berhasil menghasilkan response `HTTP 429`.

---

# 16. Pengujian Load Balancing

Load balancing dapat diuji dengan mengirimkan beberapa request secara bersamaan ke endpoint `/instance`.

Contoh:

```powershell
$jobs = 1..30 | ForEach-Object {
    Start-Job {
        curl.exe -s http://localhost:8080/instance
    }
}

$results = $jobs | Wait-Job | Receive-Job

$results | ConvertFrom-Json | Group-Object instance
```

Hasil dapat menunjukkan request diterima oleh beberapa backend:

```text
api-1
api-2
api-3
```

Jumlah request pada setiap instance tidak harus sama karena Gateway menggunakan metode:

```text
least_conn
```

---

# 17. Melihat Log Gateway

Melihat seluruh log:

```powershell
docker logs gateway
```

Melihat log secara realtime:

```powershell
docker logs -f gateway
```

---

# 18. Mengecek Konfigurasi Nginx

Test konfigurasi:

```powershell
docker exec gateway nginx -t
```

Jika konfigurasi valid:

```text
syntax is ok
test is successful
```

Melihat konfigurasi Nginx yang sedang digunakan:

```powershell
docker exec gateway nginx -T
```

---

# 19. Menghentikan Project

Untuk menghentikan container:

```powershell
docker compose -f infra/docker-compose.yml down
```

Jika ingin menghentikan container sekaligus menghapus volume:

```powershell
docker compose -f infra/docker-compose.yml down -v
```

> Gunakan `-v` dengan hati-hati karena volume database dapat ikut terhapus.

---

# 20. Pembagian Tugas Kelompok

Project dikerjakan oleh 5 anggota:

| Anggota | Bagian Utama | Fokus |
|---|---|---|
| Orang 1 | API Gateway & Reverse Proxy | Gateway, routing, reverse proxy |
| Orang 2 | Authentication & Authorization | Login, JWT, authorization |
| Orang 3 | Rate Limiter & Request Validation | Rate limiting dan validasi request |
| Orang 4 | Service Discovery & Load Balancing | Registry, discovery, load balancing |
| Orang 5 | Health Check, Circuit Breaker & Logging | Monitoring, failure handling, logging |

---

# 21. Kesimpulan

Project ini mengimplementasikan **API Gateway** menggunakan Nginx sebagai pintu masuk utama antara client dan beberapa backend service.

Backend menggunakan FastAPI dan dijalankan dalam tiga instance, yaitu `api-1`, `api-2`, dan `api-3`. Service Discovery digunakan untuk melakukan registry dan monitoring terhadap backend service.

Selain routing, project juga menerapkan:

- Authentication & Authorization
- Rate Limiting
- Request Validation
- Service Discovery
- Load Balancing
- Health Check
- Circuit Breaker
- Request Logging

Seluruh komponen dijalankan menggunakan Docker Compose sehingga dapat digunakan dan diuji sebagai satu sistem terintegrasi.