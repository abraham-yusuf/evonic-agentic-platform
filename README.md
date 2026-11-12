# Evonic Docker Sandbox Kit — Agentic Platform Deployment

**Target:** Docker Agentic Platform (managed container — no docker.sock, no Docker daemon)  
**Author:** RikkaHub Agent  
**Date:** 12 Nov 2026  
**Compatible with:** Evonic v1.6.x

---

## TL;DR

| Pertanyaan | Jawaban |
|---|---|
| Evonic deployable di Agentic Platform? | ✅ **Ya** — dengan `SANDBOX_BACKEND=bwrap` |
| Butuh Docker daemon/Socket? | ❌ **Tidak** — platform ini managed container |
| dsh deployable di Agentic Platform? | ✅ **Ya** — tinggal push image |
| Biaya $250 cukup? | ✅ **Lebih dari cukup** — RAM < 1GB idle |
| Effort setup? | ~15 menit |

---

## Apa yang Ada di Kit Ini

```
evonic-docker-kit/
├── Dockerfile          # Multi-stage build (venv rebuild di dalam image)
├── docker-compose.yml  # Local dev + production config
├── requirements.txt    # Frozen deps untuk build
├── .env.example        # Template semua env var
├── .dockerignore       # exclude .venv, .git, logs, dll.
├── build.sh            # Build helper script
├── entrypoint.sh       # Clean startup (dir + healthcheck)
└── README.md           # Dokumen ini
```

---

## Arsitektur Deployment

```
┌─────────────────────────────────────────────┐
│  Docker Agentic Platform (your sandbox)     │
│                                             │
│  ┌──────────────────────────────────────┐  │
│  │  evonic-agentic-platform container   │  │
│  │                                      │  │
│  │  Python 3.12 (Flask + SQLite)        │  │
│  │  Evonic v1.6.x                       │  │
│  │  SANDBOX_BACKEND=bwrap  ← NO daemon  │  │
│  │  HCNSEC LLM (Qwen3.8)                │  │
│  │  Port 8080 → sandbox external URL    │  │
│  └──────────────────────────────────────┘  │
│                                             │
│  evonic-db volume ← persistent SQLite DB    │
└─────────────────────────────────────────────┘
```

---

## Step-by-Step Deploy ke Agentic Platform

### Prerequisite: Generate Image

Karena Agentic Platform deploys dari **image** (bukan source), langkah pertama adalah build lalu push ke registry.

#### 1. Build di Local (atau di workspace RikkaHub)

```bash
cd /workspace/evonic-docker-kit

# Isi API key dulu
cp .env.example .env
nano .env    # EDIT: LLM_API_KEY, SECRET_KEY

# Build image
chmod +x build.sh
./build.sh

# Atau manual:
docker build --target runtime \
  --build-arg UID=$(id -u) --build-arg GID=$(id -g) \
  -t evonic:latest .
```

#### 2. Push ke Container Registry

```bash
# Tag untuk registry
docker tag evonic:latest your-registry.com/evonic-agentic:latest

# Push
docker push your-registry.com/evonic-agentic:latest
```

#### 3. Deploy di Agentic Platform

Dari dashboard Agentic Platform:

1. **New Sandbox** → Custom Kit
2. **Image**: `your-registry.com/evonic-agentic:latest`
3. **Environment Variables**: tambah semua var dari `.env.example`
4. **Port**: `8080` (HTTP)
5. **Startup Command**: kosongkan (Dockerfile pakai `CMD python app.py`)
6. **Volume Mount**: `evonic-db:/home/evonic/shared` (persistent DB)
7. **Deploy**

#### 4. Setup Pertama Kali

Setelah container jalan, buka `http://<sandbox-url>:8080`:

```
Admin password ada di log pertama kali:
  docker compose logs | grep password
  # atau di dashboard Agentic Platform → container logs
```

---

## Env Var Kunci untuk Agentic Platform

### Server
```bash
HOST=0.0.0.0              # WAJIB: bind ke semua interface
PORT=8080                 # port utama
```

### LLM (pakai HCNSEC kamu)
```bash
LLM_BASE_URL=https://api.hcnsec.cn/v1
LLM_MODEL_NAME=Qwen3.8-Flash-Next
LLM_API_KEY=sk-your-here
```

### Sandbox (CRITICAL — ini yang bikin jalan di managed container)
```bash
SANDBOX_BACKEND=bwrap     # WAJIB: tanpa Docker daemon
# sandbox_enabled default = 0 → aman, tool jalan di container langsung
```

### Keamanan
```bash
SECRET_KEY=               # python -c "import secrets; print(secrets.token_hex(32))"
```

---

## Cara Kerja Sandbox di Sini

```
Managed Container ≠ punya Docker daemon
         ↓
Evonic default → SANDBOX_BACKEND=docker → GAGAL (butuh docker.sock)
         ↓
Solusi → SANDBOX_BACKEND=bwrap (bubblewrap)
         ↓
bubblewrap = Linux namespace sandbox, TIDAK butuh daemon
         ↓
Tool bash/runpy jalan di container langsung tanpa Docker-in-Docker
```

Kalau `bubblewrap` tidak terinstall di image, `sandbox_enabled=0` (default) tetap jalan — tool langsung eksekusi di container tanpa isolasi, aman untuk workload umum.

---

## Local Development (docker-compose)

```bash
# 1. Setup
cp .env.example .env
nano .env   # edit LLM_API_KEY

# 2. Run
docker compose up --build

# 3. Logs
docker compose logs -f

# 4. Stop
docker compose down
```

Akses: `http://localhost:8080`

---

## Resource Usage (Estimated)

| Metric | Idle | Active |
|---|---|---|
| RAM | ~150–200 MB | ~400–600 MB |
| CPU | < 1% | up to 1 core |
| Disk | ~600 MB image | + SQLite DB |
| Startup | ~30 detik | — |

Cocok untuk $250/mo plan Agentic Platform.

---

## Troubleshooting

### Container not starting
```bash
# Cek logs
docker compose logs evonic

# Atau di Agentic Platform dashboard → Logs tab
```

### "bwrap: bubblewrap is not installed"
```dockerfile
# Di Dockerfile, uncomment ini di Stage 2:
RUN apt-get install -y bubblewrap
```
Atau set `sandbox_enabled=0` di agent template (default) — tool jalan tanpa sandbox.

### "Permission denied" di shared/db
```bash
# Pastikan volume mount memiliki permission write
# Di .env atau docker-compose.yml:
SHARED_DB_DIR=/home/evonic/shared
```

### LLM API error 401
```bash
# Cek API key di .env
LLM_API_KEY=sk-...   # harus ada dan valid
```

### Port 8080 already in use
```bash
# Ganti port di .env atau docker-compose.yml
PORT=8081
```

---

## Upgrade Path

```bash
# 1. Pull new Evonic source ke workspace
cd /workspace/evonic && git pull

# 2. Copy requirements.txt ke kit
cp /workspace/evonic/requirements.txt /workspace/evonic-docker-kit/requirements.txt

# 3. Rebuild
./build.sh --no-cache

# 4. Push
./build.sh --push your-registry.com

# 5. Redeploy di Agentic Platform → rebuild/recreate container
```

---

## Referensi

- Evonic: https://github.com/anvie/evonic
- Docker Agentic Platform: https://docs.docker.com/agentic-platform/
- Bubblewrap: https://github.com/containers/bubblewrap
- dsh (DeepSeek Harness): https://github.com/deepseek-ai/deepseek-harness
