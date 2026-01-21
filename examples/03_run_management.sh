#!/usr/bin/env bash
# Run the 03_run_management server and client demo
#
# Usage: ./examples/03_run_management.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

# Clean up any leftover process on port 8000
lsof -ti:8000 | xargs kill -9 2>/dev/null || true

echo "Starting server..."
ruby examples/03_run_management/server.rb &
SERVER_PID=$!

# Wait for server to be ready
echo "Waiting for server to start..."
for i in {1..30}; do
  if curl -s http://localhost:8000/ping > /dev/null 2>&1; then
    echo "Server is ready."
    break
  fi
  sleep 0.1
done

# Run the client
echo ""
ruby examples/03_run_management/client.rb
CLIENT_EXIT=$?

# Clean up
echo ""
echo "Stopping server..."
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

exit $CLIENT_EXIT
