# HTTP Endpoints

The SimpleAcp server exposes HTTP endpoints for agent discovery, run management, and session handling.

## Endpoint Overview

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/ping` | Health check |
| `GET` | `/agents` | List all agents |
| `GET` | `/agents/:name` | Get agent manifest |
| `POST` | `/runs` | Create a run |
| `GET` | `/runs/:id` | Get run status |
| `POST` | `/runs/:id` | Resume awaited run |
| `POST` | `/runs/:id/cancel` | Cancel a run |
| `GET` | `/runs/:id/events` | Get run events |
| `GET` | `/session/:id` | Get session info |

## Health Check

### GET /ping

Check server health.

**Request:**
```bash
curl http://localhost:8000/ping
```

**Response:**
```json
{
  "status": "ok"
}
```

## Agent Discovery

### GET /agents

List all registered agents.

**Request:**
```bash
curl http://localhost:8000/agents
```

**Response:**
```json
{
  "agents": [
    {
      "name": "echo",
      "description": "Echoes input back",
      "input_content_types": ["text/plain"],
      "output_content_types": ["text/plain"],
      "metadata": {}
    },
    {
      "name": "analyzer",
      "description": "Analyzes JSON data",
      "input_content_types": ["application/json"],
      "output_content_types": ["application/json"],
      "metadata": {"version": "1.0"}
    }
  ]
}
```

### GET /agents/:name

Get a specific agent's manifest.

**Request:**
```bash
curl http://localhost:8000/agents/echo
```

**Response:**
```json
{
  "name": "echo",
  "description": "Echoes input back",
  "input_content_types": ["text/plain"],
  "output_content_types": ["text/plain"],
  "metadata": {}
}
```

**Error (404):**
```json
{
  "error": {
    "code": "agent_not_found",
    "message": "Agent 'unknown' not found"
  }
}
```

## Run Management

### POST /runs

Create and execute a run.

**Request (Synchronous):**
```bash
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "echo",
    "input": [
      {
        "role": "user",
        "parts": [
          {"content_type": "text/plain", "content": "Hello!"}
        ]
      }
    ]
  }'
```

**Response:**
```json
{
  "run_id": "550e8400-e29b-41d4-a716-446655440000",
  "agent_name": "echo",
  "status": "completed",
  "output": [
    {
      "role": "agent",
      "parts": [
        {"content_type": "text/plain", "content": "Echo: Hello!"}
      ]
    }
  ],
  "created_at": "2025-01-21T10:30:00Z",
  "finished_at": "2025-01-21T10:30:01Z"
}
```

**Request (Streaming):**
```bash
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"agent_name": "chat", "input": [...]}'
```

**Response (SSE Stream):**
```
event: run_started
data: {"run_id":"550e8400-..."}

event: message_created
data: {"message":{"role":"agent","parts":[]}}

event: message_part
data: {"part":{"content_type":"text/plain","content":"Hello"}}

event: message_completed
data: {"message":{"role":"agent","parts":[...]}}

event: run_completed
data: {"run":{...}}
```

**Request with Session:**
```bash
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -d '{
    "agent_name": "chat",
    "session_id": "conversation-123",
    "input": [...]
  }'
```

### GET /runs/:id

Get run status.

**Request:**
```bash
curl http://localhost:8000/runs/550e8400-e29b-41d4-a716-446655440000
```

**Response:**
```json
{
  "run_id": "550e8400-e29b-41d4-a716-446655440000",
  "agent_name": "processor",
  "status": "in_progress",
  "output": [],
  "created_at": "2025-01-21T10:30:00Z"
}
```

**Status Values:**
- `created` - Run created, not started
- `in_progress` - Currently executing
- `completed` - Finished successfully
- `failed` - Encountered error
- `awaiting` - Waiting for input
- `cancelled` - Cancelled by request

### POST /runs/:id

Resume an awaited run.

**Request:**
```bash
curl -X POST http://localhost:8000/runs/550e8400-... \
  -H "Content-Type: application/json" \
  -d '{
    "await_resume": {
      "type": "message",
      "message": {
        "role": "user",
        "parts": [
          {"content_type": "text/plain", "content": "My response"}
        ]
      }
    }
  }'
```

**Response:**
```json
{
  "run_id": "550e8400-...",
  "status": "completed",
  "output": [...]
}
```

### POST /runs/:id/cancel

Cancel a running execution.

**Request:**
```bash
curl -X POST http://localhost:8000/runs/550e8400-.../cancel
```

**Response:**
```json
{
  "run_id": "550e8400-...",
  "status": "cancelled"
}
```

### GET /runs/:id/events

Get events for a run.

**Request:**
```bash
curl "http://localhost:8000/runs/550e8400-.../events?limit=100&offset=0"
```

**Response:**
```json
{
  "events": [
    {
      "type": "run_started",
      "run_id": "550e8400-..."
    },
    {
      "type": "message_part",
      "part": {"content_type": "text/plain", "content": "Hello"}
    },
    {
      "type": "run_completed",
      "run": {...}
    }
  ]
}
```

## Session Management

### GET /session/:id

Get session information.

**Request:**
```bash
curl http://localhost:8000/session/conversation-123
```

**Response:**
```json
{
  "id": "conversation-123",
  "history": [
    {"role": "user", "parts": [...]},
    {"role": "agent", "parts": [...]}
  ],
  "state": {"step": 2, "data": {"name": "Alice"}}
}
```

## Error Responses

All errors follow a consistent format:

```json
{
  "error": {
    "code": "error_code",
    "message": "Human-readable message"
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `agent_not_found` | 404 | Agent doesn't exist |
| `run_not_found` | 404 | Run doesn't exist |
| `session_not_found` | 404 | Session doesn't exist |
| `invalid_input` | 400 | Malformed request |
| `run_not_awaiting` | 400 | Resume on non-awaiting run |
| `internal_error` | 500 | Server error |

## Request Headers

| Header | Purpose |
|--------|---------|
| `Content-Type: application/json` | Required for POST requests |
| `Accept: text/event-stream` | Request SSE streaming |

## Query Parameters

### /runs/:id/events

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `limit` | integer | 100 | Max events to return |
| `offset` | integer | 0 | Events to skip |

## Authentication

SimpleAcp doesn't include built-in authentication. Add it via middleware:

```ruby
# config.ru
require 'simple_acp'

server = SimpleAcp::Server::Base.new
# ... register agents

# Add auth middleware
use Rack::Auth::Basic do |username, password|
  username == ENV['API_USER'] && password == ENV['API_PASS']
end

run server.to_app
```

## CORS

For browser access, add CORS headers:

```ruby
# config.ru
require 'rack/cors'

use Rack::Cors do
  allow do
    origins '*'
    resource '*',
      headers: :any,
      methods: [:get, :post, :options],
      expose: ['Content-Type']
  end
end

run server.to_app
```

## Testing Endpoints

```bash
# Health check
curl http://localhost:8000/ping | jq

# List agents
curl http://localhost:8000/agents | jq

# Run agent
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -d '{"agent_name":"echo","input":[{"role":"user","parts":[{"content_type":"text/plain","content":"test"}]}]}' | jq

# Stream run
curl -X POST http://localhost:8000/runs \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"agent_name":"chat","input":[...]}'
```

## Next Steps

- See [Client Guide](../client/index.md) for using these endpoints
- Review [API Reference](../api/server-base.md) for programmatic usage
- Explore [Storage](../storage/index.md) for data persistence
