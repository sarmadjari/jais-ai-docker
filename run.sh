#!/bin/bash

# 🚀 Jais AI - Simplified Run Script
# Usage: ./run.sh [docker|native]

set -e

MODE=${1}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[RUN]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Jais AI - Simplified Runner"
echo "=============================="

# Check model exists
MODEL_FILE="models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf"
if [[ ! -f "$MODEL_FILE" ]]; then
    log_error "Model file not found: $MODEL_FILE"
    echo "Download with: ./scripts/model-download.sh"
    exit 1
fi

# Auto-detect mode if not specified
if [[ -z "$MODE" ]]; then
    echo "Choose mode:"
    echo "1) 🐳 Docker (Production-ready, ARM64 optimized)"
    echo "2) 🔥 Native (Maximum performance, Metal GPU)"
    echo ""
    read -p "Enter choice (1-2): " choice
    
    case $choice in
        1) MODE="docker" ;;
        2) MODE="native" ;;
        *) log_error "Invalid choice"; exit 1 ;;
    esac
fi

case $MODE in
    "docker")
        log_info "Starting Docker container..."
        
        # Check if image exists
        if ! docker image inspect jais-ai:latest >/dev/null 2>&1; then
            log_warn "Docker image not found. Building..."
            ./build.sh docker
        fi
        
        # Stop any existing container
        docker stop jais-ai 2>/dev/null || true
        docker rm jais-ai 2>/dev/null || true
        
        # Run container
        log_info "Running on http://localhost:5001"
        docker run --rm -it \
            --name jais-ai \
            -p 5001:5001 \
            -v "$(pwd)/models:/app/models:ro" \
            -v "$(pwd)/config:/app/config:ro" \
            --platform linux/arm64 \
            jais-ai:latest
        ;;
        
    "native")
        log_info "Starting native Metal server..."
        
        # Check virtual environment
        if [[ ! -d "venv_metal" ]]; then
            log_warn "Virtual environment not found. Building..."
            ./build.sh native
        fi
        
        # Activate environment and run
        source venv_metal/bin/activate
        export GGML_METAL=1
        export GGML_METAL_PATH_RESOURCES=$(pwd)/venv_metal/lib/python3.13/site-packages/llama_cpp/lib/
        
        log_info "Running on http://localhost:5001"
        cd src && python app.py
        ;;
        
    *)
        log_error "Invalid mode: $MODE"
        echo "Usage: ./run.sh [docker|native]"
        exit 1
        ;;
esac
