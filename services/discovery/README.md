# Service Discovery + Health Check + Circuit Breaker

> **Tugas TEMAN.** Folder ini belum diisi — kamu yang mengimplementasi.

## Kontrak / Spek

Service Discovery adalah service kecil (bebas stack, disarankan FastAPI) yang
bertugas: registry, health check berkala, circuit breaker, dan meng-update
config nginx `gateway/conf.d/upstreams.conf` + reload gateway.

### Endpoint wajib

| Method | Path       | Fungsi                                              |
|--------|------------|-----------------------------------------------------|
| POST   | `/register`| Daftarkan instance. Body: `{"name","host","port"}`  |
| DELETE | `/register`| Hapus instance (saat shutdown). Body sama           |
| GET    | `/registry`| Daftar semua instance terdaftar                     |
| GET    | `/health`  | Health check service discovery sendiri              |

Contoh register (dari `scripts/register.sh`):
```json
{ "name": "api", "host": "172.20.0.5", "port": 8000 }
```

### Loop health check (tiap N detik)

1. Ambil semua instance dari registry.
2. `GET http://{host}:{port}/health` tiap instance.
3. **Circuit breaker per instance** — state machine:
   - `CLOSED` : normal, terdaftar di nginx upstream.
   - Gagal health check **3x berturut** → `OPEN` : hapus dari nginx upstream.
   - Setelah `cooldown` (misal 30 dtk) → `HALF_OPEN` : coba 1 probe.
     - Sukses → `CLOSED`, tambahkan lagi ke upstream.
     - Gagal → `OPEN` lagi.
4. Tulis ulang file upstream (di bawah) lalu reload nginx.

### Integrasi dengan Nginx

Discovery menulis file ini (`gateway/conf.d/upstreams.conf`):

```nginx
upstream backend {
    server api-1:8000 max_fails=3 fail_timeout=30s;
    server api-2:8000 max_fails=3 fail_timeout=30s;
}
```

Lalu reload nginx dengan salah satu cara:

```bash
# cara A: docker socket (dev) - discovery container mount docker.sock
docker exec gateway nginx -s reload

# cara B: reloader sidecar dalam container gateway yang watch file
#         dan mengeksekusi `nginx -s reload` saat file berubah
```

### Perlu perubahan di docker-compose.yml (oleh teman)

- Tambah service `discovery` (build dari `services/discovery`).
- Tambah volume bersama antara `discovery` dan `gateway`
  agar discovery bisa menulis `upstreams.conf`:
  ```yaml
  discovery:
    build: ./services/discovery
    volumes:
      - ./gateway/conf.d:/etc/nginx/conf.d:rw   # tulis upstreams.conf
      - /var/run/docker.sock:/var/run/docker.sock:ro  # untuk reload (cara A)
  ```
- API instance ke-2 dst: tambah service `api-2` (build sama, env beda) dan
  `scripts/register.sh` dipanggil saat API start.