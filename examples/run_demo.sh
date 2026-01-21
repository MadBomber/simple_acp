#!/usr/bin/env bash
# Run a SimpleAcp demo by number
#
# Usage: ./examples/run_demo.sh <demo_number>
#        ./examples/run_demo.sh --list
#
# Examples:
#   ./examples/run_demo.sh 1      # Run 01_basic demo
#   ./examples/run_demo.sh 4      # Run 04_rich_messages demo
#   ./examples/run_demo.sh --list # List available demos

set -e

# Calculate project directory ONCE at script start (before any cd commands)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"

# Demo directory mapping
declare -A DEMOS=(
    [1]="01_basic"
    [2]="02_async_execution"
    [3]="03_run_management"
    [4]="04_rich_messages"
    [5]="05_await_resume"
    [6]="06_agent_metadata"
)

# Demo descriptions
declare -A DESCRIPTIONS=(
    [1]="Basic - echo, greeter, counter, streaming, sessions"
    [2]="Async Execution - run_async, polling, wait_for_run"
    [3]="Run Management - cancellation, event history"
    [4]="Rich Messages - JSON, images, URLs, multi-part"
    [5]="Await/Resume - interactive multi-step flows"
    [6]="Agent Metadata - full manifests, content types"
)

show_usage() {
    cat <<EOF
Usage: $0 <demo_number|--list|--all>

Options:
  <number>   Run demo 1-6
  --list     List available demos
  --all      Run all demos sequentially

Available demos:
EOF
    for i in {1..6}; do
        echo "  $i) ${DEMOS[$i]} - ${DESCRIPTIONS[$i]}"
    done
}

run_demo() {
    local demo_num=$1
    local demo_dir=${DEMOS[$demo_num]}

    if [[ -z "$demo_dir" ]]; then
        echo "Error: Invalid demo number '$demo_num'"
        echo "Valid options: 1-6"
        exit 1
    fi

    cd "$PROJECT_DIR"

    # Check if demo directory exists
    if [[ ! -d "examples/$demo_dir" ]]; then
        echo "Error: Demo directory 'examples/$demo_dir' not found"
        exit 1
    fi

    echo "=========================================="
    echo "Running Demo $demo_num: $demo_dir"
    echo "${DESCRIPTIONS[$demo_num]}"
    echo "=========================================="
    echo

    # Clean up any leftover process on port 8000
    lsof -ti:8000 | xargs kill -9 2>/dev/null || true

    echo "Starting server..."
    ruby "examples/$demo_dir/server.rb" &
    SERVER_PID=$!

    # Wait for server to be ready
    echo "Waiting for server to start..."
    for i in {1..30}; do
        if curl -s http://localhost:8000/ping >/dev/null 2>&1; then
            echo "Server is ready."
            break
        fi
        sleep 0.1
    done

    # Run the client
    echo ""
    ruby "examples/$demo_dir/client.rb"
    CLIENT_EXIT=$?

    # Clean up
    echo ""
    echo "Stopping server..."
    kill $SERVER_PID 2>/dev/null || true
    wait $SERVER_PID 2>/dev/null || true

    return $CLIENT_EXIT
}

# Main
case "${1:-}" in
--list | -l)
    show_usage
    ;;
--all | -a)
    echo "Running all demos..."
    echo
    for i in {1..6}; do
        run_demo $i
        echo
    done
    echo "All demos completed!"
    ;;
--help | -h | "")
    show_usage
    exit 0
    ;;
*)
    if [[ "$1" =~ ^[1-6]$ ]]; then
        run_demo "$1"
    else
        echo "Error: Invalid argument '$1'"
        echo
        show_usage
        exit 1
    fi
    ;;
esac
