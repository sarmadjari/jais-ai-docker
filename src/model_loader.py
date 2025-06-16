import json
import os
import sys
import logging
import platform
from typing import Dict, Any, Optional, Generator

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class JaisModelLoader:
    """
    Optimized model loader for mradermacher Jais AI GGUF models with proper error handling
    and resource management.
    """
    
    def __init__(self, model_path: str = "/app/models", config_path: str = "/app/config/performance_config.json"):
        self.model_path = model_path
        self.config = self._load_config(config_path)
        # Get model path from environment variable first, then config, then default
        env_model_path = os.environ.get("MODEL_PATH")
        if env_model_path and os.path.exists(env_model_path):
            self.full_model_path = env_model_path
        else:
            self.full_model_path = self.config.get("model_path", "/app/models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf")
        self.model_file = os.path.basename(self.full_model_path)
        self.model = None
        self._default_system_message = (
            "You are Jais, a helpful AI assistant created by Inception AI. "
            "You are knowledgeable, helpful, and can communicate in both English and Arabic."
        )
        
        # Auto-detect runtime environment and set optimal performance mode
        self.performance_mode = self._detect_runtime_environment()
        logger.info(f"Detected runtime environment: {self.performance_mode}")
        
    def _detect_runtime_environment(self) -> str:
        """
        Auto-detect the runtime environment and return optimal performance mode.
        
        Returns:
            str: 'native_metal' for macOS with Metal, 'docker' for containers
        """
        # Check if running in Docker container
        if os.path.exists('/.dockerenv') or os.path.exists('/proc/1/cgroup'):
            return 'docker'
        
        # Check if running natively on macOS with GGML_METAL environment variable
        if (platform.system() == 'Darwin' and 
            platform.machine() == 'arm64' and 
            os.environ.get('GGML_METAL') == '1'):
            return 'native_metal'
        
        # Default to docker mode for safety
        return 'docker'
    
    def _load_config(self, config_path: str) -> Dict[str, Any]:
        """Load model configuration with fallback defaults."""
        try:
            with open(config_path, 'r', encoding='utf-8') as f:
                config = json.load(f)
                logger.info(f"Configuration loaded from {config_path}")
                return config
        except FileNotFoundError:
            logger.warning(f"Config file {config_path} not found, using defaults")
            return self._get_default_config()
        except json.JSONDecodeError as e:
            logger.error(f"Invalid JSON in config file: {e}")
            return self._get_default_config()
    
    def _get_default_config(self) -> Dict[str, Any]:
        """Return default configuration for mradermacher Jais model."""
        return {
            "parameters": {
                "max_tokens": 2048,
                "temperature": 0.3,
                "top_p": 0.9,
                "repeat_penalty": 1.2,
                "top_k": 40
            },
            "server_config": {
                "n_ctx": 16384,  # 16K context for mradermacher model
                "n_threads": -1,
                "n_gpu_layers": -1,
                "chat_format": "chatml"
            }
        }
    
    def load_model(self):
        """Load the mradermacher GGUF model with optimized settings."""
        try:
            # Check if model file exists and is valid
            if os.path.exists(self.full_model_path) and os.path.getsize(self.full_model_path) > 1000000:  # > 1MB
                logger.info(f"Found GGUF model: {self.full_model_path}")
                
                # Check if it's a placeholder test file
                with open(self.full_model_path, 'rb') as f:
                    first_bytes = f.read(100)
                    if b"Placeholder" in first_bytes or b"test file" in first_bytes:
                        logger.warning("⚠️  Detected placeholder model file!")
                        return self._create_mock_model()
                
                # Try to load actual GGUF model
                return self._load_gguf_model()
            else:
                logger.warning(f"GGUF model not found at {self.full_model_path}")
                return self._create_mock_model()
                
        except Exception as e:
            logger.error(f"Error in load_model: {e}")
            return self._create_mock_model()
    
    def _load_gguf_model(self):
        """Load the actual GGUF model using llama-cpp-python."""
        try:
            # Try to import llama_cpp
            try:
                from llama_cpp import Llama
            except ImportError:
                logger.warning("llama-cpp-python not installed. Installing...")
                import subprocess
                subprocess.check_call([
                    sys.executable, "-m", "pip", "install", 
                    "llama-cpp-python", "--no-cache-dir"
                ])
                from llama_cpp import Llama
            
            logger.info(f"Loading mradermacher GGUF model from: {self.full_model_path}")
            
            # Get performance preset based on detected environment
            performance_presets = self.config.get("performance_presets", {})
            preset = performance_presets.get(self.performance_mode, {})
            server_config = preset.get("server_config", self.config.get("server_config", {}))
            
            logger.info(f"Using performance preset: {self.performance_mode}")
            logger.info(f"Preset description: {preset.get('description', 'Default configuration')}")
            
            # Apply configuration from preset
            n_ctx = server_config.get("n_ctx", 2048)
            n_threads = server_config.get("n_threads", -1)
            n_gpu_layers = server_config.get("n_gpu_layers", 0)
            n_batch = server_config.get("n_batch", 64)
            use_mmap = server_config.get("use_mmap", True)
            use_mlock = server_config.get("use_mlock", False)
            
            # Auto-configure threads if not specified
            if n_threads <= 0:
                cpu_count = os.cpu_count() or 4
                if self.performance_mode == 'native_metal':
                    n_threads = min(cpu_count, 12)  # More threads for native execution
                else:
                    n_threads = min(cpu_count // 2, 8)  # Conservative for Docker
            
            logger.info(f"Configuration:")
            logger.info(f"  - Threads: {n_threads}")
            logger.info(f"  - Context: {n_ctx}")
            logger.info(f"  - GPU Layers: {n_gpu_layers} ({'Metal' if self.performance_mode == 'native_metal' else 'CPU-only'})")
            logger.info(f"  - Batch Size: {n_batch}")
            
            # Initialize with optimized settings
            llama_params = {
                "model_path": self.full_model_path,
                "n_ctx": n_ctx,
                "n_threads": n_threads,
                "n_gpu_layers": n_gpu_layers,
                "n_batch": n_batch,
                "use_mmap": use_mmap,
                "use_mlock": use_mlock,
                "verbose": True,
                "chat_format": server_config.get("chat_format", "chatml"),
                "seed": -1,
                "logits_all": False,
                "embedding": False,
            }
            
            # Enable Metal for native macOS execution
            if self.performance_mode == 'native_metal':
                llama_params["metal"] = True
                logger.info("🔥 Metal GPU acceleration enabled")
            
            logger.info(f"Initializing model with {self.performance_mode} preset...")
            
            # Try to load the model with fallback options
            from llama_cpp import Llama
            
            try:
                self.model = Llama(**llama_params)
                logger.info("✅ Model loaded successfully!")
                return True
                
            except Exception as e:
                logger.warning(f"Initial load failed: {e}")
                logger.info("Trying with minimal fallback settings...")
                
                # Fallback with minimal settings
                fallback_params = {
                    "model_path": self.full_model_path,
                    "n_ctx": 512,
                    "n_threads": 1,
                    "n_gpu_layers": 0,
                    "verbose": False,
                    "use_mmap": False,
                    "use_mlock": False,
                    "n_batch": 1,
                }
                
                try:
                    self.model = Llama(**fallback_params)
                    logger.info("✅ Model loaded with fallback settings!")
                    return True
                except Exception as fallback_error:
                    logger.error(f"Failed to load model even with fallback: {fallback_error}")
                    raise fallback_error
            
        except Exception as e:
            logger.error(f"❌ Failed to load GGUF model: {e}")
            return self._create_mock_model()
    
    def _create_mock_model(self):
        """[REMOVED] Mock model creation is not supported in production. This method is now a stub."""
        logger.error("Mock model creation is disabled. Please provide a valid model file.")
        raise RuntimeError("Mock model creation is disabled. Please provide a valid model file.")
    
    def generate_response(
        self, 
        prompt: str, 
        system_message: Optional[str] = None,
        **kwargs
    ) -> dict:
        """Generate a response using the loaded model and return the full response object, including token usage."""
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        # Prepare messages
        messages = []
        if system_message or self._default_system_message:
            messages.append({
                "role": "system", 
                "content": system_message or self._default_system_message
            })
        messages.append({"role": "user", "content": prompt})
        # Get parameters with fallbacks
        params = self.config.get("parameters", {})
        generation_params = {
            "max_tokens": kwargs.get("max_tokens", params.get("max_tokens", 2048)),
            "temperature": kwargs.get("temperature", params.get("temperature", 0.3)),
            "top_p": kwargs.get("top_p", params.get("top_p", 0.9)),
            "repeat_penalty": kwargs.get("repeat_penalty", params.get("repeat_penalty", 1.2)),
            "top_k": kwargs.get("top_k", params.get("top_k", 40)),
            "stream": False
        }
        try:
            logger.info(f"Starting response generation for prompt: '{prompt[:50]}...'")
            logger.info(f"Generation parameters: {generation_params}")
            # Token counting helpers
            def count_tokens(text):
                try:
                    if hasattr(self.model, 'tokenize'):
                        # llama-cpp-python
                        return len(self.model.tokenize(text.encode('utf-8')))
                    else:
                        # Fallback: whitespace split
                        return len(text.split())
                except Exception as e:
                    logger.warning(f"Token counting failed: {e}")
                    return 0
            if hasattr(self.model, 'create_chat_completion'):
                logger.info("Using create_chat_completion method")
                response = self.model.create_chat_completion(
                    messages=messages,
                    **generation_params
                )
                logger.info("Chat completion successful")
                # Extract content
                content = response.get("choices", [{}])[0].get("message", {}).get("content") or \
                          response.get("choices", [{}])[0].get("text", "")
                # Token usage
                prompt_tokens = count_tokens(prompt)
                completion_tokens = count_tokens(content)
                total_tokens = prompt_tokens + completion_tokens
                response["usage"] = {
                    "prompt_tokens": prompt_tokens,
                    "completion_tokens": completion_tokens,
                    "total_tokens": total_tokens
                }
                return response  # Return the full response object
            else:
                # Fallback for mock model
                logger.info("Using fallback method")
                content = str(self.model(prompt, **generation_params))
                prompt_tokens = count_tokens(prompt)
                completion_tokens = count_tokens(content)
                total_tokens = prompt_tokens + completion_tokens
                return {
                    "choices": [{"message": {"content": content}}],
                    "usage": {
                        "prompt_tokens": prompt_tokens,
                        "completion_tokens": completion_tokens,
                        "total_tokens": total_tokens
                    }
                }
        except Exception as e:
            logger.error(f"Generation failed with error: {e}")
            logger.error(f"Error type: {type(e).__name__}")
            import traceback
            logger.error(f"Full traceback: {traceback.format_exc()}")
            return {"error": str(e)}
    
    def stream_response(
        self, 
        prompt: str, 
        system_message: Optional[str] = None,
        **kwargs
    ) -> Generator[Dict[str, Any], None, None]:
        """Generate streaming response."""
        if self.model is None:
            raise RuntimeError("Model not loaded. Call load_model() first.")
        
        # For mock model, return a simple generator
        if not hasattr(self.model, 'create_chat_completion'):
            response = self.model(prompt)
            yield {"choices": [{"delta": {"content": response["choices"][0]["text"]}}]}
            return
        
        # Prepare messages
        messages = []
        if system_message or self._default_system_message:
            messages.append({
                "role": "system", 
                "content": system_message or self._default_system_message
            })
        messages.append({"role": "user", "content": prompt})
        
        # Get parameters with fallbacks
        params = self.config.get("parameters", {})
        generation_params = {
            "max_tokens": kwargs.get("max_tokens", params.get("max_tokens", 2048)),
            "temperature": kwargs.get("temperature", params.get("temperature", 0.3)),
            "top_p": kwargs.get("top_p", params.get("top_p", 0.9)),
            "repeat_penalty": kwargs.get("repeat_penalty", params.get("repeat_penalty", 1.2)),
            "top_k": kwargs.get("top_k", params.get("top_k", 40)),
            "stream": True
        }
        
        try:
            stream = self.model.create_chat_completion(
                messages=messages,
                **generation_params
            )
            
            for chunk in stream:
                yield chunk
                
        except Exception as e:
            logger.error(f"Streaming failed: {e}")
            yield {"error": f"Streaming generation failed: {e}"}
    
    def get_model_info(self) -> Dict[str, Any]:
        """Get information about the loaded model."""
        return {
            "model_path": self.full_model_path,
            "model_type": "GGUF",
            "model_name": "mradermacher/jais-family-30b-16k-chat-i1-GGUF",
            "quantization": "Q4_K_M",
            "context_length": self.config.get("server_config", {}).get("n_ctx", 16384),
            "languages": ["Arabic", "English"],
            "loaded": self.model is not None,
            "file_exists": os.path.exists(self.full_model_path),
            "file_size_gb": round(os.path.getsize(self.full_model_path) / (1024**3), 1) if os.path.exists(self.full_model_path) else 0,
            "config": self.config
        }
