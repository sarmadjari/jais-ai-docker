#!/bin/bash

# 🧪 Jais AI - Unified Test Script
# Usage: ./test.sh [quick|full|smoke|performance] [docker|native]

set -e

TEST_TYPE=${1:-quick}
MODE=${2}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[TEST]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_result() { echo -e "${BLUE}[RESULT]${NC} $1"; }

echo "🧪 Jais AI - Unified Test Suite"
echo "==============================="
echo "Test Type: $TEST_TYPE"
echo "Mode: ${MODE:-auto-detect}"
echo "Date: $(date)"
echo ""

# Auto-detect running mode if not specified
if [[ -z "$MODE" ]]; then
    if curl -sf http://localhost:5001/health &>/dev/null; then
        MODE="native"
        URL="http://localhost:5001"
        log_info "Detected native server running on port 5001"
    elif curl -sf http://localhost:8000/health &>/dev/null; then
        MODE="docker"
        URL="http://localhost:8000"
        log_info "Detected Docker container running on port 8000"
    else
        log_error "No server detected. Start with:"
        echo "  • Docker: ./run-new.sh docker"
        echo "  • Native: ./run-new.sh native"
        exit 1
    fi
else
    case $MODE in
        "native")
            URL="http://localhost:5001"
            if ! curl -sf "$URL/health" &>/dev/null; then
                log_error "Native server not running. Start with: ./run-new.sh native"
                exit 1
            fi
            ;;
        "docker")
            URL="http://localhost:8000"
            if ! curl -sf "$URL/health" &>/dev/null; then
                log_error "Docker container not running. Start with: ./run-new.sh docker"
                exit 1
            fi
            ;;
        *)
            log_error "Invalid mode: $MODE. Use 'docker' or 'native'"
            exit 1
            ;;
    esac
fi

# Create results directory
RESULTS_DIR="test_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

log_info "Testing $MODE mode at $URL"
log_info "Results will be saved to: $RESULTS_DIR"
echo ""

# Helper function to run a performance test with detailed metrics
run_performance_test() {
    local test_name="$1"
    local prompt="$2"
    
    log_info "Running performance test: $test_name"
    
    local start_time=$(date +%s.%N)
    local response=$(curl -s -X POST "$URL/chat" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"$prompt\"}")
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Save detailed response
    echo "$response" > "$RESULTS_DIR/${test_name}_performance.json"
    
    # Extract performance metrics
    local gen_time=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('generation_time_seconds', 0))
except:
    print(0)
" 2>/dev/null)
    
    local tokens=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    usage = data.get('usage', {})
    print(usage.get('completion_tokens', 0))
except:
    print(0)
" 2>/dev/null)
    
    if [[ "$gen_time" != "0" && "$tokens" != "0" ]]; then
        local tokens_per_sec=$(echo "scale=2; $tokens / $gen_time" | bc -l)
        log_result "⚡ $test_name: ${tokens} tokens in ${gen_time}s (${tokens_per_sec} tok/s)"
        echo "PERF,$test_name,$duration,$gen_time,$tokens,$tokens_per_sec,$MODE" >> "$RESULTS_DIR/performance.csv"
    else
        log_result "⚠️ $test_name: Complete in ${duration}s (no performance data)"
        echo "PERF,$test_name,$duration,0,0,0,$MODE" >> "$RESULTS_DIR/performance.csv"
    fi
    
    echo ""
}

# Helper function to run a single test
run_test() {
    local test_name="$1"
    local prompt="$2"
    local expected_pattern="$3"
    
    log_info "Running test: $test_name"
    
    local start_time=$(date +%s.%N)
    local response=$(curl -s -X POST "$URL/chat" \
        -H "Content-Type: application/json" \
        -d "{\"message\": \"$prompt\", \"max_tokens\": 100}")
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Save detailed response
    echo "$response" > "$RESULTS_DIR/${test_name}_response.json"
    
    # Extract response text (assuming JSON format)
    local response_text=$(echo "$response" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('response', ''))
except:
    print('Error parsing response')
" 2>/dev/null)
    
    # Check if response contains expected pattern
    if [[ "$response_text" == *"$expected_pattern"* ]] || [[ -n "$response_text" && "$expected_pattern" == "*" ]]; then
        log_result "✅ $test_name: PASS (${duration}s)"
        echo "PASS,$test_name,$duration,$MODE,$(echo "$response_text" | wc -c)" >> "$RESULTS_DIR/summary.csv"
    else
        log_result "❌ $test_name: FAIL (${duration}s)"
        echo "FAIL,$test_name,$duration,$MODE,0" >> "$RESULTS_DIR/summary.csv"
        echo "Expected pattern: $expected_pattern"
        echo "Got: $response_text"
    fi
    
    echo "Duration: ${duration}s"
    echo ""
}

# Initialize CSV headers
echo "Status,Test,Duration,Mode,ResponseLength" > "$RESULTS_DIR/summary.csv"
echo "Type,Test,Duration,GenTime,Tokens,TokensPerSec,Mode" > "$RESULTS_DIR/performance.csv"

case $TEST_TYPE in
    "smoke")
        log_info "Running smoke tests (basic functionality)..."
        run_test "health_check" "Hello" "*"
        run_test "simple_question" "What is 2+2?" "*"
        ;;
        
    "quick")
        log_info "Running quick tests (essential functionality)..."
        run_test "health_check" "Hello" "*"
        run_test "simple_math" "What is 2+2?" "*"
        run_test "basic_question" "What is the capital of France?" "*"
        run_test "arabic_test" "اهلا وسهلا" "*"
        ;;
        
    "full")
        log_info "Running full test suite..."
        
        # Basic functionality
        run_test "health_check" "Hello" "*"
        run_test "simple_math" "What is 2+2?" "*"
        run_test "basic_question" "What is the capital of France?" "*"
        
        # Language tests
        run_test "arabic_simple" "اهلا وسهلا" "*"
        run_test "arabic_question" "ما هي عاصمة فرنسا؟" "*"
        
        # AI capabilities
        run_test "reasoning" "Explain why the sky appears blue during the day" "*"
        run_test "creative_writing" "Write a short poem about technology" "*"
        run_test "problem_solving" "How would you solve traffic congestion in a city?" "*"
        
        # Longer responses
        run_test "detailed_explanation" "Explain the concept of machine learning in detail" "*"
        
        # Edge cases
        run_test "empty_context" "" "*"
        run_test "very_long_prompt" "$(printf 'Tell me about artificial intelligence. %.0s' {1..50})" "*"
        ;;
        
    "performance")
        log_info "Running performance tests..."
        
        # Performance tests with various message types
        run_performance_test "perf_greeting" "Hello! Tell me about yourself."
        run_performance_test "perf_arabic" "ما هو اسمك؟"
        run_performance_test "perf_explanation" "Explain artificial intelligence in simple terms."
        run_performance_test "perf_arabic_question" "كيف يمكنني تعلم البرمجة؟"
        run_performance_test "perf_creative" "Write a short poem about technology."
        
        # Generate performance summary
        log_info "Generating performance summary..."
        if [[ -f "$RESULTS_DIR/performance.csv" ]]; then
            local avg_tokens_per_sec=$(tail -n +2 "$RESULTS_DIR/performance.csv" | awk -F',' '{if($6>0) sum+=$6; count++} END {if(count>0) print sum/count; else print 0}')
            local total_tokens=$(tail -n +2 "$RESULTS_DIR/performance.csv" | awk -F',' '{sum+=$5} END {print sum}')
            local total_gen_time=$(tail -n +2 "$RESULTS_DIR/performance.csv" | awk -F',' '{if($4>0) sum+=$4} END {print sum}')
            
            echo ""
            log_result "📊 Performance Summary:"
            log_result "  Average Rate: ${avg_tokens_per_sec} tokens/second"
            log_result "  Total Tokens: ${total_tokens}"
            log_result "  Total Generation Time: ${total_gen_time}s"
        fi
        ;;
        
    *)
        log_error "Invalid test type: $TEST_TYPE"
        echo "Available types: smoke, quick, full, performance"
        exit 1
        ;;
esac

# Generate summary report
log_info "Generating test report..."

TOTAL_TESTS=$(tail -n +2 "$RESULTS_DIR/summary.csv" | wc -l)
PASSED_TESTS=$(tail -n +2 "$RESULTS_DIR/summary.csv" | grep "PASS" | wc -l)
FAILED_TESTS=$(tail -n +2 "$RESULTS_DIR/summary.csv" | grep "FAIL" | wc -l)
AVG_DURATION=$(tail -n +2 "$RESULTS_DIR/summary.csv" | cut -d',' -f3 | awk '{sum+=$1; count++} END {print sum/count}')

cat > "$RESULTS_DIR/report.md" << EOF
# Jais AI Test Report

**Date:** $(date)  
**Mode:** $MODE  
**Test Type:** $TEST_TYPE  
**Server URL:** $URL  

## Summary
- **Total Tests:** $TOTAL_TESTS
- **Passed:** $PASSED_TESTS
- **Failed:** $FAILED_TESTS
- **Success Rate:** $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%
- **Average Response Time:** ${AVG_DURATION}s

## Test Results
EOF

tail -n +2 "$RESULTS_DIR/summary.csv" | while IFS=',' read -r status test duration mode length; do
    echo "- **$test:** $status (${duration}s, ${length} chars)" >> "$RESULTS_DIR/report.md"
done

# Display summary
echo ""
echo "🎯 Test Summary"
echo "==============="
log_result "Total Tests: $TOTAL_TESTS"
log_result "Passed: $PASSED_TESTS"
log_result "Failed: $FAILED_TESTS"
log_result "Success Rate: $(echo "scale=1; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l)%"
log_result "Average Response Time: ${AVG_DURATION}s"

echo ""
echo "📋 Results saved to: $RESULTS_DIR/"
echo "📊 Full report: $RESULTS_DIR/report.md"

# Cleanup after tests
echo ""
log_info "Cleaning up test artifacts..."
# Don't remove the results directory, but clean temp files
rm -f /tmp/test_*.tmp

if [[ $FAILED_TESTS -gt 0 ]]; then
    echo ""
    log_warn "Some tests failed. Check the detailed results in $RESULTS_DIR/"
    exit 1
else
    echo ""
    log_info "All tests passed! 🎉"
fi
