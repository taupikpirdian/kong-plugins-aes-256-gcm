# Kong Gateway with AES-GCM Encryption Plugin

Project ini adalah setup Kong Gateway dalam mode DBless dengan custom plugin untuk enkripsi response API menggunakan algoritma AES-GCM (AES-256 in Galois/Counter Mode).

## Fitur

- **Kong Gateway** dalam mode DBless (tanpa database)
- **response-aes-encrypt Plugin**: Plugin enkripsi response dengan algoritma AES-256-GCM
- **Declarative Configuration**: Menggunakan file YAML untuk konfigurasi routes dan services
- **Authentication**: Setiap response terenkripsi dilengkapi HMAC-SHA256 untuk memastikan integrity data

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
│   └── response-aes-encrypt/ # Plugin enkripsi response AES-GCM
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

## response-aes-encrypt Plugin

Plugin untuk enkripsi response API dengan algoritma AES-256-GCM (Galois/Counter Mode) dan autentikasi menggunakan HMAC-SHA256.

### Cara Kerja

Plugin ini bekerja dengan tahapan berikut:

1. **Intercept Response**: Plugin menangkap response dari upstream service sebelum dikirim ke client
2. **Generate IV (Initialization Vector)**: Membuat random IV untuk setiap request agar enkripsi unik
3. **Encrypt**: Mengenkripsi body response menggunakan algoritma enkripsi
4. **Authenticate**: Menambahkan HMAC-SHA256 untuk memastikan data integrity
5. **Encode**: Meng-encode hasil enkripsi ke Base64 untuk transport yang aman
6. **Modify Headers**: Mengubah Content-Type dan menambahkan header custom

### Format Response Terenkripsi

Response yang terenkripsi memiliki format sebagai berikut:

```
Base64(IV + HMAC-SHA256 + Ciphertext)
```

- **IV (Initialization Vector)**: 16 bytes random untuk setiap enkripsi
- **HMAC-SHA256**: 32 bytes authentication tag untuk integrity
- **Ciphertext**: Data yang terenkripsi

### Headers yang Ditambahkan

Ketika enkripsi berhasil, plugin menambahkan headers berikut:

| Header | Value | Deskripsi |
|---------|-------|-----------|
| `Content-Type` | `application/aes-256-gcm+json` | Tipe content terenkripsi |
| `X-Encrypted` | `AES-256-GCM` | Indikator enkripsi |
| `Content-Length` | (dihapus) | Dihapus karena body berubah setelah enkripsi |

## Konfigurasi

### Environment Variables

| Variable | Value | Deskripsi |
|----------|-------|-----------|
| `KONG_DATABASE` | `off` | Mode DBless |
| `KONG_DECLARATIVE_CONFIG` | `/usr/local/kong/declarative/kong.yml` | Path ke config file |
| `KONG_PLUGINS` | `bundled,response-aes-encrypt` | Plugin yang di-load |
| `KONG_LUA_PACKAGE_PATH` | `/usr/local/kong/plugins/?.lua;...` | Lua package path |

### Ports

- **3002**: Proxy port (untuk traffic API)
- **8001**: Admin API port

### Plugin Configuration

**Konfigurasi di `kong.yml`:**

```yaml
services:
  - name: esb-api
    url: http://host.docker.internal:3001

    routes:
      - name: esb-route
        paths:
          - /apis
        strip_path: true

    plugins:
      - name: response-aes-encrypt
        config:
          secret_key: "your-secret-key-here"
          additional_headers: true
          fail_encrypt_status: 500
          fail_encrypt_message: "Response encryption failed"
```

**Parameters:**

| Parameter | Type | Default | Required | Deskripsi |
|-----------|------|---------|-----------|-----------|
| `secret_key` | string | - | **Yes** | Secret key untuk enkripsi (disarankan minimal 32 karakter/hex) |
| `additional_headers` | boolean | `true` | No | Tambahkan custom headers ke response |
| `fail_encrypt_status` | number | `500` | No | HTTP status code jika enkripsi gagal |
| `fail_encrypt_message` | string | `"Encryption failed"` | No | Pesan error jika enkripsi gagal |

## Usage

### Test Endpoint dengan Enkripsi

```bash
curl http://localhost:3002/apis
```

**Response yang diharapkan:**

```http
HTTP/1.1 200 OK
Content-Type: application/aes-256-gcm+json; charset=utf-8
X-Encrypted: AES-256-GCM
Content-Length: 292

SGVsbG8wQXl4... (base64 encoded encrypted response)
```

### Men-decrypt Response (Contoh)

Untuk men-decrypt response di sisi client:

```python
import base64
import hmac
import hashlib

def decrypt_response(encrypted_b64, secret_key):
    # Decode base64
    encrypted_data = base64.b64decode(encrypted_b64)

    # Extract components
    iv = encrypted_data[:16]
    tag = encrypted_data[16:48]
    ciphertext = encrypted_data[48:]

    # Verify HMAC
    hmac_data = hmac.new(secret_key.encode(), iv + ciphertext, hashlib.sha256).digest()
    if hmac_data != tag:
        raise ValueError("Invalid HMAC - data may be tampered!")

    # Decrypt using secret key (implement sesuai algoritma yang digunakan)
    plaintext = decrypt_function(ciphertext, secret_key, iv)

    return plaintext
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

## Keamanan

### Best Practices

1. **Secret Key Management**:
   - Gunakan secret key yang kuat (minimal 32 bytes untuk AES-256)
   - Jangan hardcode secret key di config file
   - Gunakan environment variable atau secret management tool
   - Rotasi secret key secara berkala

2. **Key Storage**:
   ```yaml
   # Disarankan: gunakan environment variable
   plugins:
     - name: response-aes-encrypt
       config:
         secret_key: ${ENCRYPTION_KEY}
   ```

3. **Transport Security**:
   - Selalu gunakan HTTPS di production
   - Enkripsi hanya menambahkan security layer, bukan pengganti HTTPS

### Considerations

- **Performance**: Enkripsi menambah latency ~5-10ms per request
- **Key Size**: Gunakan minimal 32 karakter untuk AES-256
- **Key Rotation**: Sediakan mekanisme untuk rotasi key tanpa downtime
- **Algorithm**: Plugin menggunakan enkripsi dengan HMAC untuk authentication

## Troubleshooting

### Container tidak start

```bash
# Cek logs
docker logs kong-dbless

# Restart container
docker-compose restart
```

### Enkripsi gagal (Response tanpa enkripsi)

**Symptom**: Response diterima tapi tidak terenkripsi

**Check**:
```bash
# Cek error logs
docker logs kong-dbless | grep -i "encryption failed"

# Cek plugin status
curl http://localhost:8001/plugins/enabled
```

**Possible causes**:
1. Secret key tidak valid atau terlalu pendek
2. Backend service tidak mengembalikan response
3. Plugin tidak ter-load dengan benar

### Plugin tidak ter-load

Pastikan:
1. Docker image sudah di-build: `docker build -t kong-custom:latest .`
2. Plugin ter-list di `KONG_PLUGINS` environment variable
3. Tidak ada error saat startup: `docker logs kong-dbless`

### Rebuild setelah mengubah plugin

```bash
# Stop container
docker-compose down

# Rebuild image
docker build -t kong-custom:latest .

# Start ulang
docker-compose up -d

# Verifikasi
docker logs kong-dbless
```

## Development

### Struktur Plugin

```
plugins/response-aes-encrypt/
├── handler.lua          # Main plugin logic (header_filter, body_filter)
├── schema.lua          # Plugin configuration schema
├── init.lua            # Entry point
└── aes-gcm.lua         # Encryption implementation
```

### Handler Phases

Plugin menggunakan Kong lifecycle phases berikut:

1. **header_filter**: Modify response headers sebelum body dikirim
   - Set `Content-Type` ke `application/aes-256-gcm+json`
   - Tambahkan `X-Encrypted: AES-256-GCM`
   - Hapus `Content-Length` karena body akan berubah

2. **body_filter**: Encrypt response body
   - Ambil raw body dari upstream
   - Enkripsi dengan secret key
   - Generate HMAC untuk authentication
   - Encode ke base64
   - Set encrypted body

### Menambahkan Custom Plugin

1. Buat direktori plugin:
```bash
mkdir -p plugins/my-custom-plugin
```

2. Buat file-file plugin:
   - `handler.lua` - Main logic
   - `schema.lua` - Configuration schema
   - `init.lua` - Entry point: `return require("kong.plugins.my-custom-plugin.handler")`

3. Update Dockerfile:
```dockerfile
COPY plugins/my-custom-plugin /usr/local/kong/plugins/kong/plugins/my-custom-plugin
```

4. Update docker-compose.yml:
```yaml
KONG_PLUGINS: bundled,response-aes-encrypt,my-custom-plugin
```

5. Rebuild:
```bash
docker build -t kong-custom:latest .
```

## Testing

### Manual Testing

```bash
# Test dengan curl
curl -v http://localhost:3002/apis

# Test dengan different methods
curl -X POST http://localhost:3002/apis -H "Content-Type: application/json" -d '{"test":"data"}'

# Test dengan Postman
# Import collection dan test endpoint
```

### Verifikasi Enkripsi

1. Pastikan response memiliki header `X-Encrypted: AES-256-GCM`
2. Pastikan `Content-Type` adalah `application/aes-256-gcm+json`
3. Response body harus berupa Base64 string
4. Decode Base64 untuk melihat panjang data (iv + tag + ciphertext)

## Maintenance

### Stop Kong

```bash
docker-compose down
```

### View Logs

```bash
# Real-time logs
docker logs -f kong-dbless

# Last 100 lines
docker logs --tail 100 kong-dbless

# Error logs only
docker logs kong-dbless 2>&1 | grep -i error
```

### Restart Kong

```bash
docker-compose restart
```

### Update Plugin

```bash
# 1. Edit plugin files
vim plugins/response-aes-encrypt/handler.lua

# 2. Rebuild image
docker-compose down
docker build -t kong-custom:latest .

# 3. Restart
docker-compose up -d

# 4. Verify
docker logs kong-dbless
```

## Configuration Service

Service backend harus tersedia. Untuk mengubah URL backend, edit file `kong.yml`:

```yaml
services:
  - name: esb-api
    url: http://your-backend-url:port
```

## Implementasi Details

### Encryption Flow

```
Upstream Response
       ↓
[kong response-aes-encrypt plugin]
       ↓
   1. Generate IV (16 bytes random)
       ↓
   2. Encrypt plaintext with secret key
       ↓
   3. Generate HMAC-SHA256 (IV + ciphertext)
       ↓
   4. Combine: IV + HMAC + Ciphertext
       ↓
   5. Encode to Base64
       ↓
Encrypted Response to Client
```

### Error Handling

Plugin memiliki error handling berikut:

- **Encryption Failed**: Jika enkripsi gagal, return original body tanpa enkripsi
- **Backend Errors**: Error response dari backend tidak dienkripsi (dilewat)
- **OPTIONS Request**: Tidak dienkripsi untuk CORS preflight

### Security Notes

⚠️ **Important**:
- Enkripsi adalah **additional security layer**, bukan pengganti HTTPS
- Selalu gunakan TLS/HTTPS di production environment
- Secret key harus disimpan dengan aman (gunakan secret management system)
- Implementasi key rotation policy
- Monitor performance impact enkripsi

## License

MIT

## Support

Untuk pertanyaan atau issues, silakan buat issue di repository.
