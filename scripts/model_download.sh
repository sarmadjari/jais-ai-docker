#!/bin/bash

# Jais AI 30B 16K Chat GGUF Model Download Script
# Optimized for Docker container deployment

set -euo pipefail

# Configuration
MODEL_DIR="${MODEL_DIR:-/app/models}"
MODEL_REPO="mradermacher/jais-family-30b-16k-chat-i1-GGUF"
MODEL_FILE="jais-family-30b-16k-chat.i1-Q4_K_M.gguf"  # 26GB, balanced quality/performance
MODEL_PATH="$MODEL_DIR/$MODEL_FILE"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if model already exists
if [ -f "$MODEL_PATH" ]; then
    log_info "Model already exists at $MODEL_PATH"

    # Print SHA256 hash for verification
    if command -v shasum >/dev/null 2>&1; then
        MODEL_HASH=$(shasum -a 256 "$MODEL_PATH" | awk '{print $1}')
        log_info "SHA256 hash: $MODEL_HASH"
    elif command -v sha256sum >/dev/null 2>&1; then
        MODEL_HASH=$(sha256sum "$MODEL_PATH" | awk '{print $1}')
        log_info "SHA256 hash: $MODEL_HASH"
    else
        log_warn "SHA256 utility not found. Skipping hash calculation."
    fi

    # Verify model integrity (basic check)
    if [ -s "$MODEL_PATH" ]; then
        MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
        log_info "Model size: $MODEL_SIZE"

        # Basic integrity check - GGUF files should be larger than 1GB for 30B models
        MODEL_SIZE_BYTES=$(stat -f%z "$MODEL_PATH" 2>/dev/null || stat -c%s "$MODEL_PATH" 2>/dev/null || echo "0")
        if [ "$MODEL_SIZE_BYTES" -gt 1000000000 ]; then
            read -p "Model appears to be valid. Overwrite and re-download? (y/N): " OVERWRITE
            if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
                log_info "Skipping download."
                exit 0
            else
                log_warn "Overwriting existing model file..."
                rm -f "$MODEL_PATH"
            fi
        else
            log_warn "Model file seems too small. Re-downloading..."
            rm -f "$MODEL_PATH"
        fi
    else
        log_warn "Model file is empty. Re-downloading..."
        rm -f "$MODEL_PATH"
    fi
fi

# Create model directory
log_info "Creating model directory: $MODEL_DIR"
mkdir -p "$MODEL_DIR"

# Check available disk space
AVAILABLE_SPACE=$(df "$MODEL_DIR" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=30000000  # ~30GB in KB for Q4_K_M model (includes buffer)

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    log_error "Insufficient disk space. Required: ~30GB, Available: $(($AVAILABLE_SPACE/1024/1024))GB"
    exit 1
fi

# Download using huggingface-cli (no authentication required for mradermacher models)
log_info "Downloading Jais AI 30B Chat model (GGUF format)..."
log_info "Repository: $MODEL_REPO"
log_info "File: $MODEL_FILE (Q4_K_M quantization - 26GB)"
log_info "Destination: $MODEL_PATH"

# Install huggingface-hub if not available
if ! command -v huggingface-cli >/dev/null 2>&1; then
    log_info "Installing huggingface-hub CLI..."
    pip install huggingface-hub[cli]
fi

# Download specific GGUF file (no authentication required)
log_info "Starting download (this may take a while - 26GB file)..."

# Use temporary directory for cache to avoid permission issues
export HF_HOME="/tmp/hf_cache"
export HUGGINGFACE_HUB_CACHE="/tmp/hf_cache"

if huggingface-cli download "$MODEL_REPO" "$MODEL_FILE" --local-dir "$MODEL_DIR" --local-dir-use-symlinks False; then
    log_info "Download completed successfully!"
else
    log_error "Download failed!"
    log_error "Available quantizations for this model:"
    log_error "   - jais-family-30b-16k-chat.i1-Q4_K_M.gguf (26GB) - Balanced (current)"
    log_error "   - jais-family-30b-16k-chat.i1-Q5_K_M.gguf (30GB) - Higher quality"
    log_error "   - jais-family-30b-16k-chat.i1-Q6_K.gguf (35GB) - Best quality"
    log_error ""
    log_error "You can change MODEL_FILE in this script to try a different quantization"
    exit 1
fi

# Verify download
if [ -f "$MODEL_PATH" ] && [ -s "$MODEL_PATH" ]; then
    MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    log_info "Download completed successfully!"
    log_info "Model size: $MODEL_SIZE"
    log_info "Model location: $MODEL_PATH"
    
    # Set appropriate permissions
    chmod 644 "$MODEL_PATH"
    
    # Basic GGUF format validation
    if file "$MODEL_PATH" | grep -q "GGUF" || head -c 4 "$MODEL_PATH" | grep -q "GGUF"; then
        log_info "Model format validation: GGUF format detected ✓"
    else
        log_warn "Model format validation: Could not confirm GGUF format"
    fi
    
else
    log_error "Download failed or file is empty"
    exit 1
fi

log_info "Model download and setup completed successfully!"
log_info "You can now build and run the Docker container."