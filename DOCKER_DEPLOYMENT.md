# 🐳 Docker Deployment - Jais AI

Quick reference for Docker deployment (see [README.md](README.md) for complete guide).

## 🚀 Simple Deployment

```bash
# Download model
./scripts/model_download.sh

# Run with simplified script
./run.sh docker
```

## 🔧 Manual Docker Commands

```bash
# Build image
docker build --platform linux/arm64 -t jais-ai:latest .

# Run container
docker run -d --name jais-ai \
  -p 8000:5001 \
  -v "$(pwd)/models:/app/models" \
  --platform linux/arm64 \
  jais-ai:latest
```

## 🎯 System Requirements

- Docker Desktop with ARM64 support
- 32GB RAM recommended  
- 30GB free disk space
- Model file: `jais-family-30b-16k-chat.i1-Q4_K_M.gguf`

## � Advanced Deployment Options

### Production Deployment
```bash
# Production deployment with full configuration
docker run -d --name jais-ai \
  --restart unless-stopped \
  -p 5001:5001 \
  -v "$(pwd)/models:/app/models" \
  -v "$(pwd)/config:/app/config" \
  --platform linux/arm64 \
  --memory=32g \
  --cpus=8 \
  jais-ai:latest

# Development deployment
docker run --rm -it \
  --name jais-ai-dev \
  -p 5001:5001 \
  -v "$(pwd)/models:/app/models" \
  --platform linux/arm64 \
  jais-ai:latest
```
  -p 5001:5001 \
  -v "$(pwd)/models:/app/models" \
  --platform linux/arm64 \
  jais-ai:latest
```

## 🔧 Configuration

### Environment Variables
```bash
# Model configuration
MODEL_PATH=/app/models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf
CONFIG_PATH=/app/config/performance_config.json

# Performance tuning
OMP_NUM_THREADS=8
OPENBLAS_NUM_THREADS=8

# Docker-specific
DOCKER_CONTAINER=true
PYTHONUNBUFFERED=1
```

### Performance Presets
The container automatically detects the environment and applies optimal settings:

**Docker Preset (Auto-selected):**
- Context: 2048 tokens
- Threads: 8 (auto-detected)
- GPU Layers: 0 (CPU-only)
- Batch Size: 64
- Memory mapping: Enabled

## 🧪 Testing & Verification

### 1. Health Check
```bash
curl http://localhost:5001/health | jq
```

Expected response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "load_time_seconds": 4.33,
  "system_metrics": {
    "memory_usage_percent": 9.6,
    "cpu_usage_percent": 0.0
  }
}
```

### 2. Chat Test
```bash
curl -X POST http://localhost:5001/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello! Please introduce yourself."}'
```

### 3. Performance Test
```bash
# Run comprehensive performance test
./test.sh performance docker
```

## 📊 Performance Expectations

### ARM64/Apple Silicon
- **Load Time**: 4-6 seconds
- **Token Rate**: 3.5-4.5 tokens/second
- **Memory Usage**: ~26GB model + 3-4GB overhead
- **CPU Utilization**: NEON acceleration enabled

### Response Times by Content Type
- **Short responses** (20-50 tokens): 8-20 seconds
- **Medium responses** (50-100 tokens): 15-25 seconds  
- **Long responses** (100+ tokens): 30-60 seconds

### Language Performance
- **English**: Consistent 3.5-4.0 tok/s
- **Arabic**: Slightly better 4.0-4.5 tok/s
- **Mixed language**: Varies by content

## 🛠️ Troubleshooting

### Common Issues

#### 1. Container Won't Start
```bash
# Check logs
docker logs jais-ai

# Common fixes
docker system prune -f
docker pull python:3.13.3-slim
```

#### 2. Model Loading Fails
```bash
# Verify model file
ls -la models/
file models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf

# Check permissions
chmod 644 models/*.gguf
```

#### 3. Out of Memory
```bash
# Increase Docker memory limit
# Docker Desktop → Settings → Resources → Memory → 32GB+

# Monitor usage
docker stats jais-ai
```

#### 4. Slow Performance
```bash
# Check CPU allocation
docker inspect jais-ai | grep -i cpu

# Verify ARM64 platform
docker inspect jais-ai | grep -i platform
```

## 🚀 Advanced Deployment

### Docker Compose
```yaml
version: '3.8'
services:
  jais-ai:
    build:
      context: .
      platforms:
        - linux/arm64
    container_name: jais-ai
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - "./models:/app/models:ro"
      - "./config:/app/config:ro"
    environment:
      - MODEL_PATH=/app/models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf
      - OMP_NUM_THREADS=8
    deploy:
      resources:
        limits:
          memory: 32G
          cpus: '8'
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

### Production Monitoring
```bash
# Resource monitoring
docker stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

# Log monitoring
docker logs -f jais-ai

# Health monitoring
watch -n 30 'curl -s http://localhost:5001/health | jq .status'
```

## 🔒 Security & Best Practices

### 1. Network Security
```bash
# Run on custom network
docker network create jais-network
docker run --network jais-network jais-ai:latest
```

### 2. Resource Limits
```bash
# Strict resource limits
docker run \
  --memory=32g --memory-swap=32g \
  --cpus=8 \
  --ulimit nofile=65536:65536 \
  jais-ai:latest
```

### 3. Read-Only Volumes
```bash
# Mount models as read-only
docker run -v "$(pwd)/models:/app/models:ro" jais-ai:latest
```

## 📈 Scaling & Load Balancing

### Multiple Instances
```bash
# Run multiple instances on different ports
for i in {5001..5003}; do
  docker run -d --name "jais-ai-$i" \
    -p "$i:5001" \
    -v "$(pwd)/models:/app/models:ro" \
    jais-ai:latest
done
```

### Nginx Load Balancer
```nginx
upstream jais_backend {
    server localhost:5001;
    server localhost:5002;
    server localhost:5003;
}

server {
    listen 80;
    location / {
        proxy_pass http://jais_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## 🏁 Conclusion

The optimized Docker deployment provides:
- ✅ **Stable 3.8+ tokens/second** performance
- ✅ **4-6 second** model loading
- ✅ **ARM64 optimization** with NEON acceleration  
- ✅ **Production-ready** with health checks
- ✅ **Easy scaling** and monitoring

For maximum performance, consider the native Metal deployment. For production stability and portability, this Docker solution is ideal.
