# Kong Gateway with Custom Encryption Plugins

Project ini adalah setup Kong Gateway dalam mode DBless dengan custom plugins untuk enkripsi request dan response.

## Fitur

- **Kong Gateway** dalam mode DBless (tanpa database)
- **Custom Plugins**:
  - `request-encrypt`: Plugin enkripsi request/response dengan algoritma RC4 dan RSA
  - `response-aes-encrypt`: Plugin enkripsi response dengan algoritma AES-GCM
- **Declarative Configuration**: Menggunakan file YAML untuk konfigurasi routes dan services

## Prerequisites

- Docker
- Docker Compose

## Struktur Project

```
.
├── Dockerfile                  # Docker image untuk Kong dengan custom plugins
├── docker-compose.yml          # Konfigurasi Docker Compose
├── kong.yml                   # Declarative config untuk Kong
├── plugins/                   # Custom plugins
│   ├── request-encrypt/       # Plugin enkripsi request/response
│   └── response-aes-encrypt/ # Plugin enkripsi response AES
└── README.md                  # File ini
```

## Quick Start

### 1. Build Docker Image

```bash
docker build -t kong-custom:latest .
```

### 2. Start Kong Gateway

```bash
docker-compose up -d
```

### 3. Verifikasi Kong Berjalan

```bash
# Cek logs
docker logs kong-dbless -f

# Cek status
curl http://localhost:8001
```

## Konfigurasi

### Environment Variables

| Variable | Value | Deskripsi |
|----------|-------|-----------|
| `KONG_DATABASE` | `off` | Mode DBless |
| `KONG_DECLARATIVE_CONFIG` | `/usr/local/kong/declarative/kong.yml` | Path ke config file |
| `KONG_PLUGINS` | `bundled,request-encrypt,response-aes-encrypt` | Plugin yang di-load |
| `KONG_LUA_PACKAGE_PATH` | `/usr/local/kong/plugins/?.lua;...` | Lua package path |

### Ports

- **3002**: Proxy port (untuk traffic API)
- **8001**: Admin API port

## Custom Plugins

### request-encrypt

Plugin untuk enkripsi request dan response API.

**Konfigurasi:**

```yaml
plugins:
  - name: request-encrypt
    config:
      secret: "your-secret-key"
      algorithm: rc4  # atau 'rsa'
      request_enabled: true
      response_enabled: true
      fail_encrypt_status: 494
```

**Parameters:**

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `secret` | string | - | Secret key untuk enkripsi (required) |
| `algorithm` | string | `rc4` | Algoritma enkripsi: `rc4` atau `rsa` |
| `request_enabled` | boolean | `true` | Enable enkripsi request |
| `response_enabled` | boolean | `true` | Enable enkripsi response |
| `fail_encrypt_status` | number | `494` | HTTP status code jika gagal enkripsi |

### response-aes-encrypt

Plugin untuk enkripsi response dengan algoritma AES-GCM.

**Konfigurasi:**

```yaml
plugins:
  - name: response-aes-encrypt
    config:
      secret_key: "your-secret-key"
      additional_headers: true
      fail_encrypt_status: 500
      fail_encrypt_message: "Encryption failed"
```

**Parameters:**

| Parameter | Type | Default | Deskripsi |
|-----------|------|---------|-----------|
| `secret_key` | string | - | Secret key untuk enkripsi (required) |
| `additional_headers` | boolean | `true` | Tambahkan custom headers |
| `fail_encrypt_status` | number | `500` | HTTP status code jika gagal |
| `fail_encrypt_message` | string | `"Encryption failed"` | Error message |

## Usage

### Test Endpoint

```bash
# Test endpoint (response akan terenkripsi)
curl http://localhost:3002/apis
```

### Admin API

```bash
# Cek routes
curl http://localhost:8001/routes

# Cek services
curl http://localhost:8001/services

# Cek plugins
curl http://localhost:8001/plugins
```

## Troubleshooting

### Container tidak start

```bash
# Cek logs
docker logs kong-dbless

# Restart container
docker-compose restart
```

### Plugin tidak ter-load

Pastikan:
1. Docker image sudah di-build: `docker build -t kong-custom:latest .`
2. Plugin ter-list di `KONG_PLUGINS` environment variable
3. File plugin ada di path `/usr/local/kong/plugins/kong/plugins/` di dalam container

### Rebuild setelah mengubah plugin

```bash
# Stop container
docker-compose down

# Rebuild image
docker build -t kong-custom:latest .

# Start ulang
docker-compose up -d
```

## Development

### Menambah Custom Plugin Baru

1. Buat direktori baru di `plugins/your-plugin/`
2. Buat file-file berikut:
   - `handler.lua` - Main plugin logic
   - `schema.lua` - Plugin schema
   - `init.lua` - Entry point
   - File-file pendukung lainnya

3. Update `Dockerfile` untuk copy plugin baru:

```dockerfile
COPY plugins/your-plugin /usr/local/kong/plugins/kong/plugins/your-plugin
```

4. Update `docker-compose.yml`:

```yaml
KONG_PLUGINS: bundled,request-encrypt,response-aes-encrypt,your-plugin
```

5. Rebuild image:

```bash
docker build -t kong-custom:latest .
```

## Konfigurasi Service

Service backend harus tersedia di `http://host.docker.internal:3001`.

Untuk mengubah URL backend, edit file `kong.yml`:

```yaml
services:
  - name: esb-api
    url: http://your-backend-url:port
```

## Maintenance

### Stop Kong

```bash
docker-compose down
```

### View Logs

```bash
# Real-time logs
docker logs -f kong-dbless

# Last 50 lines
docker logs --tail 50 kong-dbless
```

### Restart Kong

```bash
docker-compose restart
```

## License

MIT

## Support

Untuk pertanyaan atau issues, silakan buat issue di repository.
