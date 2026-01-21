# Storage Backends

Storage backends persist runs, sessions, and events. Choose the right backend for your deployment scenario.

## Overview

```mermaid
graph TB
    S[Server] --> ST{Storage}
    ST --> M[Memory]
    ST --> R[Redis]
    ST --> P[PostgreSQL]
    ST --> C[Custom]
```

## Available Backends

| Backend | Use Case | Persistence | Scaling |
|---------|----------|-------------|---------|
| [Memory](memory.md) | Development, testing | None | Single process |
| [Redis](redis.md) | Production, distributed | TTL-based | Horizontal |
| [PostgreSQL](postgresql.md) | Production, audit | Permanent | Vertical |
| [Custom](custom.md) | Special requirements | Variable | Variable |

## Quick Comparison

### Memory

```ruby
storage = SimpleAcp::Storage::Memory.new
server = SimpleAcp::Server::Base.new(storage: storage)
```

- No dependencies
- Fast, in-process
- Data lost on restart
- Single process only

### Redis

```ruby
require 'simple_acp/storage/redis'

storage = SimpleAcp::Storage::Redis.new(
  url: "redis://localhost:6379",
  ttl: 86400
)
server = SimpleAcp::Server::Base.new(storage: storage)
```

- Requires Redis server
- Automatic expiration
- Multi-process support
- Good for scaling

### PostgreSQL

```ruby
require 'simple_acp/storage/postgresql'

storage = SimpleAcp::Storage::PostgreSQL.new(
  url: "postgres://localhost/acp"
)
server = SimpleAcp::Server::Base.new(storage: storage)
```

- Requires PostgreSQL
- Permanent storage
- Full query capabilities
- Good for auditing

## Choosing a Backend

### Use Memory When

- Developing locally
- Running tests
- Single-process deployment
- Data persistence not needed

### Use Redis When

- Multiple server processes
- Horizontal scaling needed
- TTL-based cleanup acceptable
- Real-time performance critical

### Use PostgreSQL When

- Audit trail required
- Complex queries needed
- Long-term data retention
- Compliance requirements

## Storage Interface

All backends implement the same interface:

```ruby
class Storage::Base
  def get_run(run_id)
  def save_run(run)
  def delete_run(run_id)
  def list_runs(agent_name:, session_id:, limit:, offset:)

  def get_session(session_id)
  def save_session(session)
  def delete_session(session_id)

  def add_event(run_id, event)
  def get_events(run_id, limit:, offset:)

  def close
  def ping
end
```

## Configuration

### Environment Variables

```bash
# Redis
export REDIS_URL=redis://localhost:6379

# PostgreSQL
export DATABASE_URL=postgres://user:pass@host/db
```

### Connection Options

Each backend accepts specific connection options. See individual backend documentation for details.

## In This Section

<div class="grid cards" markdown>

-   :material-memory:{ .lg .middle } **Memory**

    ---

    In-process storage for development

    [:octicons-arrow-right-24: Memory](memory.md)

-   :material-database-clock:{ .lg .middle } **Redis**

    ---

    Distributed storage with TTL

    [:octicons-arrow-right-24: Redis](redis.md)

-   :material-elephant:{ .lg .middle } **PostgreSQL**

    ---

    Persistent relational storage

    [:octicons-arrow-right-24: PostgreSQL](postgresql.md)

-   :material-cog:{ .lg .middle } **Custom Backends**

    ---

    Build your own storage

    [:octicons-arrow-right-24: Custom](custom.md)

</div>

## Next Steps

- Start with [Memory](memory.md) for development
- Move to [Redis](redis.md) or [PostgreSQL](postgresql.md) for production
- Build a [Custom Backend](custom.md) for special needs
