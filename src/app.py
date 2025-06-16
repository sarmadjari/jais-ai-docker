import os
import logging
import json
import time
from flask import Flask, request, jsonify, Response
from model_loader import JaisModelLoader
import psutil

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize Flask app
app = Flask(__name__)

# Configuration
MODEL_PATH = os.environ.get("MODEL_PATH", "/app/models/jais-family-30b-16k-chat.i1-Q4_K_M.gguf")
CONFIG_PATH = os.environ.get("CONFIG_PATH", "/app/config/performance_config.json")

logger.info("🚀 Initializing Jais AI application...")
logger.info(f"Model path: {MODEL_PATH}")
logger.info(f"Config path: {CONFIG_PATH}")

# Global model loader
jais_loader = None
model_load_time = None

def initialize_model():
    """Initialize the model with proper error handling."""
    global jais_loader, model_load_time
    
    try:
        start_time = time.time()
        jais_loader = JaisModelLoader(MODEL_PATH, CONFIG_PATH)
        jais_loader.load_model()
        model_load_time = time.time() - start_time
        
        logger.info(f"✅ Jais AI model loaded successfully in {model_load_time:.2f} seconds!")
        return True
        
    except Exception as e:
        logger.error(f"❌ Error loading model: {e}")
        return False

# Initialize model on startup
model_loaded = initialize_model()

@app.route('/health', methods=['GET'])
def health_check():
    """Comprehensive health check endpoint."""
    try:
        # System metrics
        cpu_usage = psutil.cpu_percent(interval=1)
        memory = psutil.virtual_memory()
        disk = psutil.disk_usage('/')
        
        health_data = {
            "status": "healthy" if model_loaded else "unhealthy",
            "model_loaded": model_loaded,
            "model_path": MODEL_PATH,
            "load_time_seconds": model_load_time,
            "system_metrics": {
                "cpu_usage_percent": cpu_usage,
                "memory_usage_percent": memory.percent,
                "memory_available_gb": round(memory.available / (1024**3), 2),
                "disk_usage_percent": disk.percent,
                "disk_free_gb": round(disk.free / (1024**3), 2)
            },
            "timestamp": time.time()
        }
        
        if jais_loader:
            health_data["model_info"] = jais_loader.get_model_info()
        
        status_code = 200 if model_loaded else 503
        return jsonify(health_data), status_code
        
    except Exception as e:
        logger.error(f"Health check failed: {e}")
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route('/chat', methods=['POST'])
def chat():
    """Main chat endpoint with comprehensive error handling."""
    if not model_loaded or not jais_loader:
        return jsonify({"error": "Model not loaded"}), 503
    
    try:
        # Validate request
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        user_message = data.get('message', '').strip()
        if not user_message:
            return jsonify({"error": "No message provided"}), 400
        
        system_message = data.get('system_message')
        
        # Optional parameters
        generation_params = {}
        for param in ['max_tokens', 'temperature', 'top_p', 'repeat_penalty', 'top_k']:
            if param in data:
                generation_params[param] = data[param]
        
        # Generate response
        start_time = time.time()
        logger.info(f"Generating response for message: '{user_message[:50]}...'")
        
        try:
            response_obj = jais_loader.generate_response(
                user_message, 
                system_message,
                **generation_params
            )
            generation_time = time.time() - start_time
            logger.info(f"Response generated successfully in {generation_time:.3f} seconds")
            
            # Extract content and usage if available
            content = None
            usage = None
            if isinstance(response_obj, dict):
                # llama-cpp-python style
                content = response_obj.get("choices", [{}])[0].get("message", {}).get("content") or \
                          response_obj.get("choices", [{}])[0].get("text")
                usage = response_obj.get("usage")
            else:
                content = str(response_obj)
            
            return jsonify({
                "response": content,
                "user_message": user_message,
                "system_message": system_message,
                "generation_time_seconds": round(generation_time, 3),
                "parameters_used": generation_params,
                "usage": usage
            })
            
        except Exception as e:
            generation_time = time.time() - start_time
            logger.error(f"Critical error in response generation: {e}")
            logger.error(f"Error occurred after {generation_time:.3f} seconds")
            import traceback
            logger.error(f"Full traceback: {traceback.format_exc()}")
            
            return jsonify({
                "error": f"Generation failed: {str(e)}",
                "generation_time_seconds": round(generation_time, 3),
                "error_type": type(e).__name__
            }), 500
        
    except Exception as e:
        logger.error(f"Chat endpoint error: {e}")
        return jsonify({"error": f"Generation failed: {str(e)}"}), 500

@app.route('/chat/stream', methods=['POST'])
def chat_stream():
    """Streaming chat endpoint."""
    if not model_loaded or not jais_loader:
        return jsonify({"error": "Model not loaded"}), 503
    
    try:
        # Validate request
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        user_message = data.get('message', '').strip()
        if not user_message:
            return jsonify({"error": "No message provided"}), 400
        
        system_message = data.get('system_message')
        
        # Optional parameters
        generation_params = {}
        for param in ['max_tokens', 'temperature', 'top_p', 'repeat_penalty', 'top_k']:
            if param in data:
                generation_params[param] = data[param]
        
        def generate_stream():
            """Generator for streaming response."""
            try:
                for chunk in jais_loader.stream_response(
                    user_message, 
                    system_message,
                    **generation_params
                ):
                    if chunk['choices'][0]['delta'].get('content'):
                        yield f"data: {json.dumps(chunk)}\n\n"
                yield "data: [DONE]\n\n"
                
            except Exception as e:
                logger.error(f"Streaming error: {e}")
                error_chunk = {
                    "error": f"Streaming failed: {str(e)}"
                }
                yield f"data: {json.dumps(error_chunk)}\n\n"
        
        return Response(
            generate_stream(), 
            mimetype='text/event-stream',
            headers={
                'Cache-Control': 'no-cache',
                'X-Accel-Buffering': 'no'
            }
        )
        
    except Exception as e:
        logger.error(f"Stream endpoint error: {e}")
        return jsonify({"error": f"Streaming setup failed: {str(e)}"}), 500

@app.route('/model/info', methods=['GET'])
def model_info():
    """Get detailed model information."""
    if not model_loaded or not jais_loader:
        return jsonify({"error": "Model not loaded"}), 503
    
    try:
        info = jais_loader.get_model_info()
        info["load_time_seconds"] = model_load_time
        return jsonify(info)
        
    except Exception as e:
        logger.error(f"Model info error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/', methods=['GET'])
def index():
    """API documentation endpoint."""
    return jsonify({
        "service": "Jais AI 30B 16K Chat API",
        "version": "1.0",
        "model_loaded": model_loaded,
        "endpoints": {
            "/": "GET - This documentation",
            "/health": "GET - Health check and system metrics",
            "/chat": "POST - Chat with the AI",
            "/chat/stream": "POST - Streaming chat",
            "/model/info": "GET - Model information"
        },
        "chat_format": {
            "endpoint": "/chat",
            "method": "POST",
            "required_fields": ["message"],
            "optional_fields": [
                "system_message", "max_tokens", "temperature", 
                "top_p", "repeat_penalty", "top_k"
            ]
        },
        "model_info": {
            "name": "Jais Family 30B 16K Chat",
            "format": "GGUF",
            "context_length": "16,384 tokens",
            "quantization": "Q4_K_M"
        }
    })

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    logger.error(f"Internal server error: {error}")
    return jsonify({"error": "Internal server error"}), 500

if __name__ == '__main__':
    logger.info("🚀 Starting Jais AI server...")
    # Use different port for native execution to avoid conflicts with AirPlay
    port = int(os.environ.get('PORT', 5001))
    app.run(
        host='0.0.0.0', 
        port=port, 
        debug=False,
        threaded=True
    )