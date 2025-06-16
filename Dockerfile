# Optimized Dockerfile for Jais AI - Apple Silicon (ARM64)
# Streamlined configuration with proper dependency isolation
# Supports mradermacher GGUF models with OpenBLAS acceleration

FROM --platform=linux/arm64 python:3.13.3-slim AS builder

# Install build dependencies for ARM64 optimization
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    pkg-config \
    libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# Set build environment for optimal ARM64 performance with OpenBLAS
ENV CMAKE_ARGS="-DLLAMA_BLAS=ON -DLLAMA_BLAS_VENDOR=OpenBLAS -DLLAMA_NATIVE=OFF -DLLAMA_METAL=OFF"
ENV FORCE_CMAKE=1

# Copy and install Python dependencies
COPY src/requirements.txt /tmp/requirements.txt

# Install dependencies with proper isolation and optimizations
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir --force-reinstall --no-binary=llama-cpp-python \
    llama-cpp-python==0.2.90 && \
    pip install --no-cache-dir -r /tmp/requirements.txt

# Runtime stage
FROM --platform=linux/arm64 python:3.13.3-slim

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libopenblas0 \
    libgomp1 \
    curl \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd -r jais && useradd -r -g jais jais

# Copy Python environment from builder
COPY --from=builder /usr/local/lib/python3.13/site-packages /usr/local/lib/python3.13/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Set working directory
WORKDIR /app

# Set environment variables for GGML stability in Docker ARM64
ENV GGML_METAL=0
ENV GGML_OPENCL=0
ENV GGML_CUDA=0
ENV GGML_BLAS=1
ENV OMP_NUM_THREADS=4
ENV OPENBLAS_NUM_THREADS=4
ENV DOCKER_CONTAINER=true
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Copy application files with proper ownership
COPY --chown=jais:jais src/ ./
COPY --chown=jais:jais scripts/ ./scripts/
COPY --chown=jais:jais config/ ./config/

# Create models directory with proper permissions
RUN mkdir -p /app/models && chown -R jais:jais /app/models

# Make scripts executable
RUN chmod +x ./scripts/*.sh

# Add labels for better maintainability
LABEL maintainer="jais-ai-project" \
      description="Jais AI 30B 16K Chat model containerized application" \
      version="2.0" \
      model="jais-family-30b-16k-chat" \
      architecture="arm64" \
      acceleration="openblas"

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:5001/health || exit 1

# Switch to non-root user
USER jais

# Expose port
EXPOSE 5001

# Set default environment variables
ENV MODEL_PATH=/app/models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf \
    CONFIG_PATH=/app/config/performance_config.json

# Use exec form for better signal handling and run with optimizations
CMD ["python", "-O", "app.py"]
