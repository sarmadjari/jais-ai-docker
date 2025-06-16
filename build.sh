#!/bin/bash

# 🚀 Jais AI - Simplified Build Script
# Usage: ./build.sh [native|docker] [--clean]

set -e

MODE=${1:-docker}
CLEAN_FLAG=${2}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[BUILD]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "🚀 Jais AI - Build System"
echo "========================="
echo "Mode: $MODE"
echo "Date: $(date)"
echo ""

# Clean if requested
if [[ "$CLEAN_FLAG" == "--clean" ]]; then
    log_info "Running cleanup first..."
    ./cleanup.sh
    echo ""
fi

# Check model exists
MODEL_FILE="models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf"
if [[ ! -f "$MODEL_FILE" ]]; then
    log_error "Model file not found: $MODEL_FILE"
    echo "Download with: ./scripts/model-download.sh"
    exit 1
fi

case $MODE in
    "docker")
        log_info "Building Docker image..."
        docker build --platform linux/arm64 -t jais-ai:latest .
        
        log_info "✅ Docker build completed!"
        echo "Run with: ./run.sh docker"
        ;;
        
    "native")
        log_info "Setting up native environment..."
        
        # Create virtual environment if it doesn't exist
        if [[ ! -d "venv_metal" ]]; then
            log_info "Creating Python virtual environment..."
            python3 -m venv venv_metal
        fi
        
        # Activate and install dependencies
        log_info "Installing dependencies..."
        source venv_metal/bin/activate
        pip install --upgrade pip
        pip install -r src/requirements.txt
        
        # Set Metal environment
        export GGML_METAL=1
        export GGML_METAL_PATH_RESOURCES=$(pwd)/venv_metal/lib/python3.13/site-packages/llama_cpp/lib/
        
        log_info "✅ Native build completed!"
        echo "Run with: ./run.sh native"
        ;;
        
    *)
        log_error "Invalid mode: $MODE"
        echo "Usage: ./build.sh [native|docker] [--clean]"
        exit 1
        ;;
esac

echo ""
log_info "🎯 Next steps:"
echo "  1. Run: ./run.sh $MODE"
echo "  2. Test: ./tests/test.sh quick"
echo "  3. Clean: ./cleanup.sh"
