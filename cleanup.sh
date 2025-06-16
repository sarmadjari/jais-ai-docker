#!/bin/bash

# 🧹 Jais AI Project Cleanup Script
# Removes unused files, caches, and temporary data

set -e

echo "🧹 Jais AI Project Cleanup"
echo "=========================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CLEANUP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to safely remove files/directories
safe_remove() {
    local target="$1"
    local description="$2"
    
    if [[ -e "$target" ]]; then
        log_info "Removing $description: $target"
        rm -rf "$target"
    fi
}

# 1. Remove log files and temporary outputs
log_info "Cleaning temporary files..."
safe_remove "*.log" "log files"
safe_remove "native_server.log" "native server log"
safe_remove "native_test.log" "native test log"
safe_remove "performance_comparison_*.txt" "performance comparison files"

# 2. Remove backup files
log_info "Cleaning backup files..."
safe_remove "Dockerfile.backup" "Docker backup file"
safe_remove "*.backup" "all backup files"
safe_remove "*.bak" "all .bak files"

# 3. Remove Python cache
log_info "Cleaning Python cache..."
safe_remove "src/__pycache__" "Python cache directory"
find . -name "*.pyc" -delete 2>/dev/null || true
find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true

# 4. Remove virtual environment (it's large and can be recreated)
log_info "Cleaning virtual environment..."
if [[ -d "venv_metal" ]]; then
    log_warn "Removing venv_metal directory (can be recreated with ./build.sh native)"
    rm -rf venv_metal
fi

# 5. Clean Docker resources
log_info "Cleaning Docker resources..."
if command -v docker >/dev/null 2>&1; then
    # Remove unused Docker images for this project
    docker images | grep jais-ai | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || true
    
    # Clean up any stopped containers
    docker ps -a | grep jais | awk '{print $1}' | xargs -r docker rm -f 2>/dev/null || true
    
    log_info "Running Docker system cleanup..."
    docker system prune -f 2>/dev/null || true
fi

# 6. Remove test result files
log_info "Cleaning test artifacts..."
safe_remove "test_results.json" "test results file"
safe_remove "/tmp/docker_performance_result.txt" "performance result cache"

# 7. Remove any editor temporary files
log_info "Cleaning editor temporary files..."
safe_remove ".DS_Store" "macOS metadata files"
find . -name ".DS_Store" -delete 2>/dev/null || true
safe_remove "*.tmp" "temporary files"
safe_remove "*.swp" "vim swap files"
safe_remove "*~" "editor backup files"

echo ""
log_info "✅ Cleanup completed!"
echo ""
echo "📊 Project size after cleanup:"
du -sh . 2>/dev/null || echo "Cannot calculate size"
echo ""
log_info "🚀 Ready for fresh build/test cycle!"
echo "   Run: ./build.sh [native|docker]"
echo "   Test: ./tests/test.sh [quick|full]"
