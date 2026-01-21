# Redis Storage

Redis storage provides distributed, TTL-based storage suitable for production deployments with multiple server processes.

## Features

- **Distributed** - Share state across multiple processes
- **TTL-based** - Automatic expiration of old data
- **Fast** - Sub-millisecond operations
- **Scalable** - Supports Redis clustering

## Requirements

Add the Redis gem to your Gemfile:

```ruby
gem 'redis', '~> 5.0'
```

## Usage

### Basic Setup

```ruby
require 'simple_acp'
require 'simple_acp/storage/redis'

storage = SimpleAcp::Storage::Redis.new(
  url: "redis://localhost:6379"
)

server = SimpleAcp::Server::Base.new(storage: storage)
```

### Configuration Options

```ruby
storage = SimpleAcp::Storage::Redis.new(
  # Connection
  url: "redis://localhost:6379",     # Redis URL
  host: "localhost",                  # Or specify individually
  port: 6379,
  db: 0,
  password: "secret",
  ssl: false,

  # Or use existing connection
  redis: existing_redis_client,

  # Behavior
  ttl: 86400,                         # TTL in seconds (default: 24 hours)
  prefix: "acp:"                      # Key prefix (default: "acp:")
)
```

### Environment Variables

```ruby
# Uses REDIS_URL if not specified
storage = SimpleAcp::Storage::Redis.new

# Reads from:
# ENV['REDIS_URL'] || "redis://localhost:6379"
```

## Data Model

### Key Structure

```
acp:run:{run_id}              # Run data (JSON)
acp:session:{session_id}      # Session data (JSON)
acp:events:{run_id}           # Events list (JSON items)
acp:agent_runs:{agent_name}   # Set of run IDs for agent
acp:session_runs:{session_id} # Set of run IDs for session
```

### TTL Behavior

All keys expire after the configured TTL:

```ruby
storage = SimpleAcp::Storage::Redis.new(
  ttl: 3600  # 1 hour
)

# Run expires 1 hour after last update
storage.save_run(run)
```

## Operations

### Runs

```ruby
# Save (sets TTL)
storage.save_run(run)

# Get
run = storage.get_run("run-id")

# Delete (also removes from indexes)
storage.delete_run("run-id")

# List by agent
result = storage.list_runs(agent_name: "echo")

# List by session
result = storage.list_runs(session_id: "session-123")
```

### Sessions

```ruby
# Save (sets TTL)
storage.save_session(session)

# Get
session = storage.get_session("session-id")

# Delete
storage.delete_session("session-id")
```

### Events

```ruby
# Add (extends TTL)
storage.add_event("run-id", event)

# Get
events = storage.get_events("run-id", limit: 100, offset: 0)
```

## Connection Management

### Connection Pooling

Use connection pooling in multi-threaded environments:

```ruby
require 'connection_pool'

pool = ConnectionPool.new(size: 10) do
  Redis.new(url: ENV['REDIS_URL'])
end

# Create storage with pooled connection
storage = SimpleAcp::Storage::Redis.new(redis: pool)
```

### Close Connection

```ruby
storage.close
```

### Health Check

```ruby
if storage.ping
  puts "Redis is healthy"
else
  puts "Redis connection failed"
end
```

## Scaling

### Redis Cluster

For high availability and horizontal scaling:

```ruby
require 'redis-cluster-client'

redis = RedisClient.cluster(
  nodes: [
    { host: "node1.example.com", port: 6379 },
    { host: "node2.example.com", port: 6379 },
    { host: "node3.example.com", port: 6379 }
  ]
).new_pool(timeout: 5, size: 10)

storage = SimpleAcp::Storage::Redis.new(redis: redis)
```

### Multiple Processes

Redis naturally supports multiple processes:

```ruby
# Process 1
server1 = SimpleAcp::Server::Base.new(
  storage: SimpleAcp::Storage::Redis.new(url: ENV['REDIS_URL'])
)

# Process 2 (shares data with Process 1)
server2 = SimpleAcp::Server::Base.new(
  storage: SimpleAcp::Storage::Redis.new(url: ENV['REDIS_URL'])
)
```

## Production Configuration

### Recommended Settings

```ruby
storage = SimpleAcp::Storage::Redis.new(
  url: ENV['REDIS_URL'],
  ttl: 86400 * 7,        # 7 days
  prefix: "myapp:acp:"   # Namespace for your app
)
```

### With Sentinel

```ruby
redis = Redis.new(
  url: "redis://mymaster",
  sentinels: [
    { host: "sentinel1", port: 26379 },
    { host: "sentinel2", port: 26379 },
    { host: "sentinel3", port: 26379 }
  ],
  role: :master
)

storage = SimpleAcp::Storage::Redis.new(redis: redis)
```

## Maintenance

### Clear All Data

```ruby
storage.clear!  # Deletes all keys with prefix
```

### Monitor Key Count

```bash
redis-cli KEYS "acp:*" | wc -l
```

### Check Memory Usage

```bash
redis-cli INFO memory
```

## Error Handling

```ruby
begin
  run = storage.get_run("run-id")
rescue Redis::CannotConnectError
  puts "Redis connection failed"
  # Fallback logic...
rescue Redis::TimeoutError
  puts "Redis timeout"
  # Retry logic...
end
```

## Best Practices

1. **Use appropriate TTL** - Balance retention vs. memory usage
2. **Use key prefix** - Namespace to avoid collisions
3. **Monitor memory** - Watch Redis memory usage
4. **Use connection pooling** - For multi-threaded apps
5. **Set up replication** - For high availability

## Comparison with Other Backends

| Feature | Redis | Memory | PostgreSQL |
|---------|-------|--------|------------|
| Persistence | TTL | None | Permanent |
| Multi-process | Yes | No | Yes |
| Speed | Fast | Fastest | Moderate |
| Query flexibility | Limited | None | Full SQL |

## Next Steps

- Learn about [PostgreSQL](postgresql.md) for permanent storage
- Build a [Custom Backend](custom.md) for special needs
- Review [Memory](memory.md) for development
