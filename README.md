````

# API Gateway Kelompok 1

Project ini merupakan implementasi **API Gateway** menggunakan **Nginx** sebagai pintu masuk utama untuk mengatur komunikasi antara client dengan beberapa instance backend service.

Project dibuat untuk menerapkan beberapa konsep dalam arsitektur distributed system, yaitu:

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

## 1. Tujuan Project

Project ini bertujuan untuk membangun sebuah API Gateway yang menjadi perantara antara client dan backend service.

Tanpa API Gateway, client harus berkomunikasi langsung dengan masing-masing backend service.

Dengan API Gateway, seluruh request client diarahkan terlebih dahulu melalui satu pintu masuk:

```text
Client
   |
   v
API Gateway
   |
   +----------------+
   |                |
   v                v
Backend Service   Service Discovery
   |
   +--------+--------+
   |        |        |
   v        v        v
 api-1    api-2    api-3
````

API Gateway bertanggung jawab untuk menerima request, melakukan beberapa proses seperti autentikasi dan rate limiting, kemudian meneruskan request ke backend yang tersedia.

---

# 2. Arsitektur Sistem

Arsitektur utama project:

```text
                         +------------------+
                         |      Client      |
                         +--------+---------+
                                  |
                                  | HTTP
                                  v
                         +------------------+
                         |   Nginx Gateway  |
                         |    Port :8080    |
                         +--------+---------+
                                  |
                    +-------------+-------------+
                    |             |             |
                    v             v             v
                 api-1:8000    api-2:8000    api-3:8000
                    |             |             |
                    +-------------+-------------+
                                  |
                                  v
                         +------------------+
                         |    PostgreSQL    |
                         |     :5432        |
                         +------------------+


                         +------------------+
                         | Service Discovery|
                         |     :8010        |
                         +------------------+
                                  |
                                  v
                         Registry Service
                         api-1 / api-2 / api-3
```

---

# 3. Komponen Sistem

## 3.1 API Gateway

API Gateway menggunakan **Nginx** dan berjalan pada:

```text
http://localhost:8080
```

Gateway berfungsi sebagai pintu masuk utama seluruh request dari client.

Beberapa endpoint utama:

```text
GET  /
GET  /healthz
GET  /metrics
GET  /instance

POST /auth/login

GET  /api/*
```

Gateway juga berfungsi sebagai reverse proxy yang meneruskan request ke backend service.

---

## 3.2 Backend API

Backend menggunakan **FastAPI** dan memiliki tiga instance:

```text
api-1
api-2
api-3
```

Masing-masing menggunakan port internal:

```text
8000
```

Instance pertama juga diekspos ke host untuk kebutuhan pengujian:

```text
http://localhost:8000
```

Sedangkan api-2 dan api-3 hanya digunakan melalui network Docker.

---

## 3.3 PostgreSQL

Database yang digunakan adalah PostgreSQL.

Port:

```text
5432
```

Database digunakan oleh backend API untuk menyimpan dan mengambil data aplikasi.

---

## 3.4 Service Discovery

Service Discovery digunakan untuk mengetahui service backend yang tersedia.

Service Discovery berjalan pada:

```text
http://localhost:8010
```

Registry dapat digunakan untuk melihat service yang terdaftar:

```text
GET /registry
```

Contoh service yang terdaftar:

```text
api-1
api-2
api-3
```

Service Discovery juga melakukan health checking terhadap service yang terdaftar.

---

# 4. Fitur yang Diimplementasikan

## 4.1 API Gateway & Reverse Proxy

Nginx digunakan sebagai gateway dan reverse proxy.

Client cukup mengakses:

```text
http://localhost:8080
```

kemudian Gateway meneruskan request ke backend yang sesuai.

---

## 4.2 Authentication & Authorization

Sistem menggunakan authentication berbasis JWT.

Alurnya:

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

Endpoint yang membutuhkan autentikasi akan menolak request yang tidak memiliki token yang valid.

---

## 4.3 Rate Limiting

Gateway menggunakan Nginx `limit_req` untuk membatasi jumlah request dari client.

Konfigurasi yang digunakan:

```text
Rate  : 5 request/second
Burst : 5 request
```

Jika request melebihi batas yang ditentukan, Gateway memberikan:

```text
HTTP 429 Too Many Requests
```

Rate limiter diterapkan pada route:

```text
/api/*
```

---

## 4.4 Request Validation

Request juga divalidasi sebelum diteruskan ke service.

Validasi meliputi:

### Content-Type

Request `POST`, `PUT`, dan `PATCH` harus menggunakan JSON.

Jika tidak sesuai:

```text
HTTP 415 Unsupported Media Type
```

### Schema Validation

Data request divalidasi oleh backend.

Request dengan data yang tidak sesuai schema menghasilkan:

```text
HTTP 422 Unprocessable Entity
```

### Body Size

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

Service Discovery menyimpan registry backend service.

Contoh:

```text
api-1:8000
api-2:8000
api-3:8000
```

Service yang sehat akan digunakan oleh Gateway.

---

## 4.6 Load Balancing

Gateway menggunakan Nginx untuk membagi request ke beberapa backend instance.

Metode yang digunakan:

```text
least_conn
```

Dengan tiga backend:

```text
api-1
api-2
api-3
```

Request dari client dapat diteruskan ke instance yang berbeda.

---

## 4.7 Health Check

Setiap komponen memiliki mekanisme health checking.

Gateway:

```text
GET /healthz
```

Backend:

```text
GET /health
```

Discovery:

```text
GET /health
```

Selain itu, Docker Compose juga menggunakan health check untuk memastikan container dalam kondisi sehat.

---

## 4.8 Circuit Breaker

Service Discovery memiliki mekanisme circuit breaker untuk menangani service yang mengalami kegagalan.

State circuit breaker:

```text
CLOSED
   |
   | consecutive failures >= 3
   v
 OPEN
   |
   | cooldown 30 seconds
   v
HALF_OPEN
   |
   +-------- success --------> CLOSED
   |
   +-------- failure --------> OPEN
```

Konfigurasi:

```text
Maximum failure : 3
Cooldown        : 30 seconds
```

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

Log dapat dilihat menggunakan:

```bash
docker logs gateway
```

---

# 5. Teknologi yang Digunakan

| Teknologi         | Fungsi                         |
| ----------------- | ------------------------------ |
| Nginx             | API Gateway & Reverse Proxy    |
| FastAPI           | Backend API                    |
| PostgreSQL        | Database                       |
| Python            | Backend                        |
| Docker            | Containerization               |
| Docker Compose    | Menjalankan seluruh service    |
| JWT               | Authentication                 |
| PowerShell        | Testing                        |
| Service Discovery | Registry dan health monitoring |

---

# 6. Struktur Project

Struktur utama project:

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

* Docker Desktop
* Docker Compose
* Git
* PowerShell

Pastikan Docker Desktop sedang berjalan.

Cek Docker:

```powershell
docker --version
```

Cek Docker Compose:

```powershell
docker compose version
```

---

# 8. Clone Repository

Clone repository:

```powershell
git clone https://github.com/rrrambatsigma/apiagateway-kelompok1.git
```

Masuk ke directory project:

```powershell
cd apiagateway-kelompok1
```

---

# 9. Menjalankan Project

Project menggunakan Docker Compose.

Jalankan:

```powershell
docker compose --env-file .env -f infra/docker-compose.yml up -d --build --wait --wait-timeout 180
```

Jika file `docker-compose.yml` berada langsung di root project, gunakan:

```powershell
docker compose --env-file .env up -d --build --wait --wait-timeout 180
```

Tunggu sampai seluruh container selesai dibuat dan berada dalam kondisi running/healthy.

---

# 10. Mengecek Container

Gunakan:

```powershell
docker compose ps
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

# 11. Mengecek API Gateway

Setelah container berjalan, test Gateway:

```powershell
curl.exe -i http://localhost:8080/
```

Health check:

```powershell
curl.exe -i http://localhost:8080/healthz
```

Metrics:

```powershell
curl.exe -i http://localhost:8080/metrics
```

Instance:

```powershell
curl.exe -i http://localhost:8080/instance
```

---

# 12. Mengecek Backend Secara Langsung

Backend pertama dapat diakses langsung melalui:

```text
http://localhost:8000
```

Contoh:

```powershell
curl.exe -i http://localhost:8000/health
```

atau:

```powershell
curl.exe -i http://localhost:8000/api/users
```

Perbedaan akses:

```text
Port 8000
   ↓
Direct Backend

Port 8080
   ↓
API Gateway
   ↓
Backend
```

Port `8080` merupakan jalur utama yang digunakan client.

---

# 13. Mengecek Service Discovery

Health:

```powershell
curl.exe -i http://localhost:8010/health
```

Melihat registry:

```powershell
curl.exe -i http://localhost:8010/registry
```

Registry diharapkan menunjukkan tiga instance:

```text
api-1
api-2
api-3
```

---

# 14. Login

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

Token kemudian dapat digunakan untuk mengakses endpoint yang membutuhkan autentikasi.

Contoh:

```powershell
Invoke-RestMethod `
    -Uri "http://localhost:8080/api/users" `
    -Method GET `
    -Headers @{ Authorization = "Bearer $TOKEN" }
```

---

# 15. Menjalankan Testing

Project menyediakan script PowerShell untuk melakukan pengujian fitur.

Jalankan:

```powershell
.\testing.ps1
```

Jika PowerShell menolak execution policy, dapat menjalankan:

```powershell
powershell -ExecutionPolicy Bypass -File .\testing.ps1
```

Testing mencakup:

```text
Gateway Root
Gateway Health
Metrics
Instance Routing

Authentication
Authorization
Protected API
Unauthorized Access

Rate Limit Normal
Rate Limiter

Valid JSON
Content-Type Validation
Schema Validation
Body Size Validation

Discovery Health
Service Registry
Dynamic Upstream
Load Balancing

Direct Backend
Gateway Protected API
Logging
Nginx Config
404 Handling
```

---

# 16. Hasil Pengujian

Hasil pengujian saat ini:

```text
Test                    Status
----------------------------------------
Gateway Root            PASS
Gateway Health          PASS
Metrics                 PASS
Instance Routing        PASS

Authentication          PASS
Authorization           PASS
Protected API           PASS
Unauthorized Access     PASS

Rate Limit Normal       PASS
Rate Limiter            PASS
Valid JSON              PASS
Content-Type Validation PASS
Schema Validation       PASS
Body Size Validation    PASS

Discovery Health        PASS
Service Registry        PASS
Dynamic Upstream        PASS
Load Balancing          PASS

Direct Backend          PASS
Gateway Protected API   PASS
Logging                 PASS
Nginx Config            PASS
404 Handling            PASS
```

Total:

```text
23 PASS
0 FAIL
```

---

# 17. Testing Rate Limiter

Rate limiter menggunakan konfigurasi:

```text
5 request/second
burst = 5
```

Pengujian dilakukan dengan mengirimkan request secara bersamaan.

Jika request melebihi batas, akan muncul:

```text
HTTP 429 Too Many Requests
```

Contoh hasil:

```text
HTTP 200 = request yang diterima
HTTP 429 = request yang dibatasi
```

---

# 18. Testing Load Balancing

Untuk melihat request diteruskan ke instance backend yang berbeda:

```powershell
$jobs = 1..30 | ForEach-Object {
    Start-Job {
        curl.exe -s http://localhost:8080/instance
    }
}

$results = $jobs | Wait-Job | Receive-Job

$results | ConvertFrom-Json | Group-Object instance
```

Hasil dapat menunjukkan request diterima oleh beberapa instance:

```text
api-1
api-2
api-3
```

Jumlah request tiap instance tidak harus sama karena Gateway menggunakan:

```text
least_conn
```

---

# 19. Melihat Log Gateway

Gunakan:

```powershell
docker logs gateway
```

Untuk melihat log secara realtime:

```powershell
docker logs -f gateway
```

---

# 20. Mengecek Konfigurasi Nginx

Cek konfigurasi:

```powershell
docker exec gateway nginx -t
```

Jika berhasil akan muncul:

```text
syntax is ok
test is successful
```

Untuk melihat konfigurasi Nginx yang sedang digunakan:

```powershell
docker exec gateway nginx -T
```

---

# 21. Menghentikan Project

Untuk menghentikan seluruh container:

```powershell
docker compose down
```

Jika ingin menghapus container sekaligus volume:

```powershell
docker compose down -v
```

> Gunakan `-v` dengan hati-hati karena volume database juga dapat ikut dihapus.

---

# 22. Ringkasan Alur Request

Secara keseluruhan, request berjalan seperti berikut:

```text
                    CLIENT
                      |
                      v
              +---------------+
              | API GATEWAY   |
              |    Nginx      |
              |    :8080      |
              +-------+-------+
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
     Authentication  Rate      Request
     Authorization   Limit     Validation
          |           |           |
          +-----------+-----------+
                      |
                      v
              Service Discovery
                      |
                      v
               Load Balancing
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       api-1       api-2       api-3
       :8000       :8000       :8000
          |           |           |
          +-----------+-----------+
                      |
                      v
                 PostgreSQL
                    :5432
```

---

# 23. Pembagian Tugas Kelompok

Project dikerjakan oleh 5 anggota dengan pembagian:

| Anggota | Bagian                                  |
| ------- | --------------------------------------- |
| Orang 1 | API Gateway & Reverse Proxy             |
| Orang 2 | Authentication & Authorization          |
| Orang 3 | Rate Limiter & Request Validation       |
| Orang 4 | Service Discovery & Load Balancing      |
| Orang 5 | Health Check, Circuit Breaker & Logging |

---

# 24. Kesimpulan

Project ini mengimplementasikan API Gateway sebagai pintu masuk utama untuk beberapa backend service.

Nginx digunakan sebagai API Gateway dan reverse proxy, sedangkan FastAPI digunakan sebagai backend service yang dijalankan dalam beberapa instance.

Selain routing, sistem juga menerapkan authentication, authorization, rate limiting, request validation, service discovery, load balancing, health check, circuit breaker, dan logging.

Dengan menggunakan Docker Compose, seluruh komponen dapat dijalankan sebagai satu sistem sehingga proses deployment dan pengujian dapat dilakukan secara terintegrasi.

````
