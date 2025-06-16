# 🤖 Jais AI - Optimized Docker & Native Deployment

> **High-performance Arabic-English AI language model with streamlined deployment**

## 🧠 What is JAIS?

**JAIS** (named after Jebel Jais, the UAE's highest mountain) is a bilingual Arabic-English auto-regressive large language model based on the GPT-3 decoder-only architecture, enhanced with modern features like ALiBi positional embeddings and SwiGLU non-linearity.

### 📘 Key Specifications:
| Feature | Details |
|---------|---------|
| **Architecture** | GPT-3 decoder, with ALiBi and SwiGLU |
| **Model Size** | 30B parameters (~26GB GGUF) |
| **Training Data** | 1.6T tokens (Arabic, English, code) |
| **Languages** | Bilingual: Arabic & English |
| **Context** | 16K tokens |
| **Quantization** | Q4_K_M (optimal speed/quality balance) |

### 🏛️ Development Team:
- **Inception** (AI unit under UAE's G42)
- **Mohamed bin Zayed University of AI (MBZUAI)** 
- **Cerebras Systems** (training infrastructure)
- **Released:** August 2023 (13B), November 2023 (30B)

### 🔧 Why mradermacher/jais-family-30b-16k-chat-i1-GGUF?

This project uses the **mradermacher** quantized version because:
- ✅ **iMatrix Quantization:** Advanced `i1-Q4_K_M` provides superior quality vs static quantization
- ✅ **GGUF Format:** Optimized for `llama.cpp` inference with Metal GPU acceleration  
- ✅ **Balanced Performance:** Q4_K_M offers the ideal speed/quality/size ratio (25.97 GiB)
- ✅ **Production Ready:** Pre-quantized and extensively tested for deployment
- ✅ **Community Trusted:** mradermacher is a recognized quantization specialist

This deployment solution provides both Docker containerization and native Metal GPU acceleration for maximum performance flexibility.

### 🔗 Reference Links:
- **Official Site:** [inceptionai.ai/jais](https://inceptionai.ai/jais/index.html)
- **Original Model:** [inceptionai/jais-family-30b-16k-chat](https://huggingface.co/inceptionai/jais-family-30b-16k-chat)
- **Quantized Model:** [mradermacher/jais-family-30b-16k-chat-i1-GGUF](https://huggingface.co/mradermacher/jais-family-30b-16k-chat-i1-GGUF)

## 🏗️ Project Structure

```
/
├── run.sh                      # 🚀 Main server launcher
├── test.sh                     # 🧪 Unified test runner (all modes + performance)
├── build.sh                    # 🏗️ Build system (Docker/Native)
├── cleanup.sh                  # 🧹 Project cleanup
├── Dockerfile                  # ARM64 optimized container
├── .dockerignore               # Docker build context exclusions
│
├── src/                        # 📁 Application Source
│   ├── app.py                  # Flask API server
│   ├── model_loader.py         # GGUF model loader
│   └── requirements.txt        # Python dependencies
│
├── config/                     # ⚙️ Configuration
│   └── performance_config.json # Performance settings
│
├── models/                     # 🤖 AI Model Storage
│   └── jais-family-30b-16k-chat.i1-Q4_K_M.gguf
│
├── scripts/                    # 🛠️ Utilities
│   ├── model_download.sh       # Model acquisition
│   └── README.md               # Scripts documentation
│
└── 📚 Documentation
    ├── README.md               # This file
    └── DOCKER_DEPLOYMENT.md    # Docker deployment guide
```

## 🎯 Main Components

### 1. 🚀 **Server Launcher (`run.sh`)**
- **Purpose:** Starts the JAIS AI server
- **Modes:** Docker (production) or Native (maximum performance)
- **Features:** Auto-detection, error handling, interactive mode

### 2. 🧪 **Test Runner (`test.sh`)**
- **Purpose:** Tests running JAIS server with comprehensive suite
- **Types:** Smoke, Quick, Full testing
- **Features:** Auto-detection, performance metrics, detailed reports

### 3. 🏗️ **Build System (`build.sh`)**
- **Purpose:** Builds Docker images or native environments
- **Features:** ARM64 optimization, dependency management, clean builds

### 4. 🧹 **Cleanup System (`cleanup.sh`)**
- **Purpose:** Removes logs, caches, temporary files, Docker artifacts
- **Benefits:** Optimizes storage, ensures clean state

### 5. 🤖 **JAIS Model Integration**
- **Format:** GGUF (optimized for inference)
- **Size:** 30B parameters (~26GB)
- **Acceleration:** Metal GPU (native) or OpenBLAS (Docker)

## 🚀 How to Run

### Prerequisites
```bash
# Download the JAIS model (required)
./scripts/model_download.sh
```

### Option 1: Interactive Mode (Recommended)
```bash
./run.sh
# Choose: 1) Docker or 2) Native
```

### Option 2: Direct Modes
```bash
# Docker Mode (Production-ready)
./run.sh docker

# Native Mode (Maximum performance with Metal GPU)
./run.sh native
```

### Option 3: Complete Build & Run
```bash
# Clean build and run
./cleanup.sh
./build.sh docker --clean
./run.sh docker
```

## 🧪 How to Test

> **Important:** Tests require a running server. Start the server first, then test in another terminal.

### Step 1: Start Server
```bash
# Terminal 1: Start server
./run.sh docker          # Server runs and blocks terminal
```

### Step 2: Run Tests
```bash
# Terminal 2: Run tests
./test.sh                  # Quick tests with auto-detection
./test.sh smoke            # Basic functionality tests
./test.sh quick            # Essential functionality tests  
./test.sh full             # Comprehensive test suite

# Test specific mode
./test.sh quick docker     # Test Docker server
./test.sh full native      # Test native server
```

### Step 3: View Results
```bash
# Test results are saved in timestamped directories
ls test_results_*/
cat test_results_*/report.md
```


## 🔄 Complete Workflow Example

### Development Cycle:
```bash
# 1. Clean start
./cleanup.sh

# 2. Build
./build.sh docker --clean

# 3. Start server (Terminal 1)
./run.sh docker
# ✅ Server running on http://localhost:8000

# 4. Test (Terminal 2)  
./test.sh full
# ✅ All tests passed! Results in test_results_*/

# 5. Stop server (Terminal 1: Ctrl+C)

# 6. Clean up
./cleanup.sh
```

### Quick Testing:
```bash
# Start and test in one go
./run.sh docker &          # Run in background
sleep 30                   # Wait for startup
./test.sh quick           # Run tests
pkill -f "python.*app.py" # Stop server
```

## 🛠️ Development

### Building
```bash
./build.sh                    # Build with auto-detection
./build.sh docker             # Build Docker image
./build.sh native             # Setup native environment
./build.sh docker --clean     # Clean build
```

### Testing
```bash
./test.sh                     # Auto-detect and quick test
./test.sh smoke              # Basic functionality
./test.sh quick              # Essential tests (~3 requests)
./test.sh full               # Comprehensive (~10 requests)
```

### Maintenance
```bash
./cleanup.sh                 # Clean all artifacts
```

## 🔧 Configuration

### Environment Variables
```bash
# Docker mode
DOCKER_PORT=8000
DOCKER_IMAGE=jais-ai:latest

# Native mode  
NATIVE_PORT=5001
VENV_DIR=venv_metal
```

### Model Configuration
- **File:** `models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf`
- **Size:** ~26GB
- **Format:** GGUF (optimized)
- **Context:** 16K tokens

## 🎯 API Endpoints

When server is running:

```bash
# Health check
curl http://localhost:8000/health     # Docker
curl http://localhost:5001/health     # Native

# Chat completion
curl -X POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "مرحبا، كيف يمكنني مساعدتك؟", "max_tokens": 100}'
```

## 🚨 Troubleshooting

### Common Issues:

**Model not found:**
```bash
./scripts/model_download.sh
```

**Port already in use:**
```bash
lsof -ti:8000 | xargs kill -9    # Kill Docker port
lsof -ti:5001 | xargs kill -9    # Kill native port
```

**Docker build fails:**
```bash
./cleanup.sh                     # Clean Docker cache
./build.sh docker --clean        # Fresh build
```

**Tests fail:**
```bash
# Check if server is running
curl -s http://localhost:8000/health || echo "Server not running"

# Check logs
docker logs $(docker ps -q --filter ancestor=jais-ai) # Docker
tail -f native_server.log                            # Native
```

## 📋 Requirements  
> 🐳 **Docker Guide**: See `DOCKER_DEPLOYMENT.md` for deployment instructions

## 🔧 Auto-Detection

The system automatically detects:
- Runtime environment (Docker vs native)
- Hardware architecture (ARM64 vs AMD64)  
- Available GPU acceleration (Metal vs CPU)
- Optimal thread and memory settings

## 📁 Project Structure

```
/
├── build.sh                    # Build system
├── cleanup.sh                  # Project cleanup
├── run.sh                      # Main server launcher
├── test.sh                     # Unified test runner (smoke/quick/full/performance)
├── Dockerfile                  # Optimized Docker configuration
├── .dockerignore               # Docker build context exclusions
├── config/
│   └── performance_config.json # Performance settings
├── src/
│   ├── app.py                  # Flask API server
│   ├── model_loader.py         # GGUF model loader
│   └── requirements.txt        # Python dependencies
├── scripts/
│   ├── model_download.sh       # Model acquisition script
│   └── README.md               # Scripts documentation
└── models/                     # Model files directory
    └── jais-family-30b-16k-chat.i1-Q4_K_M.gguf
```

## 🎛️ Dependencies & Requirements

**Unified `src/requirements.txt`** handles both Docker and native installations:

- **For Apple Silicon users**: Install natively for Metal GPU acceleration
- **For Docker deployment**: Automatically installed during container build
- **Cross-platform**: Works on ARM64 and AMD64 architectures

## ✅ Testing Suite

All tests are managed by the unified test runner:

```bash
# Quick tests (recommended)
./test.sh

# Full test suite
./test.sh full

# Smoke tests
./test.sh smoke

# Test specific mode
./test.sh quick docker
./test.sh full native
./test.sh performance docker  # Performance testing with detailed metrics
```

> 📊 **Performance Results**: Tests generate detailed reports with timing and success rates

## � Requirements

### System Requirements:
- **macOS:** Apple Silicon (for native mode)
- **Docker:** Docker Desktop with ARM64 support
- **Memory:** 32GB RAM recommended (26GB for model + overhead)
- **Storage:** 30GB free space (model + dependencies)
- **Python:** 3.13+ (for native mode)

### Dependencies:
- **Docker Mode:** Docker, 30GB storage
- **Native Mode:** Python 3.13, Xcode Command Line Tools, 32GB RAM

## 📚 Documentation

- **[DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md)** - Quick Docker reference
- **[scripts/README.md](scripts/README.md)** - Utility scripts documentation

## 🤝 Contributing

1. **Fork** the repository
2. **Create** feature branch: `git checkout -b feature-name`
3. **Test** your changes: `./test.sh full`
4. **Clean** before commit: `./cleanup.sh`
5. **Submit** pull request

## 📄 License

This project follows the MIT License principles.

## 🙏 Acknowledgments

- **Core42** - JAIS model development
- **Cerebras** - Training infrastructure
- **MBZUAI** - Research collaboration
- **mradermacher** - GGUF model optimization

---

**🚀 Ready to start? Run `./run.sh` and begin chatting with JAIS AI!**
