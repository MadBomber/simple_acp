# Configuration

SimpleAcp can be configured at multiple levels: global configuration, server options, and client options.

## Global Configuration

Use the global configure block to set default options:

```ruby
SimpleAcp.configure do |config|
  config.default_storage = :memory  # :memory, :redis, or :postgresql
  config.logger = Logger.new(STDOUT)
end
```

## Server Configuration

### Basic Options

```ruby
server = SimpleAcp::Server::Base.new(
  storage: SimpleAcp::Storage::Memory.new
)
```

### Storage Backend

Choose the appropriate storage backend for your deployment:

=== "Memory (Default)"

    ```ruby
    storage = SimpleAcp::Storage::Memory.new
    server = SimpleAcp::Server::Base.new(storage: storage)
    ```

    Best for: Development, testing, single-process deployments

=== "Redis"

    ```ruby
    require 'simple_acp/storage/redis'

    storage = SimpleAcp::Storage::Redis.new(
      url: ENV['REDIS_URL'] || 'redis://localhost:6379',
      ttl: 86400,      # 24 hours (default)
      prefix: 'acp:'   # Key prefix (default)
    )
    server = SimpleAcp::Server::Base.new(storage: storage)
    ```

    Best for: Multi-process deployments, horizontal scaling

=== "PostgreSQL"

    ```ruby
    require 'simple_acp/storage/postgresql'

    storage = SimpleAcp::Storage::PostgreSQL.new(
      url: ENV['DATABASE_URL'] || 'postgres://localhost/simple_acp',
      skip_setup: false  # Auto-create tables (default: false)
    )
    server = SimpleAcp::Server::Base.new(storage: storage)
    ```

    Best for: Production deployments, data persistence

### HTTP Server Options

When running the HTTP server, you can configure Puma:

```ruby
server.run(
  port: 8000,              # Listen port
  host: '0.0.0.0',         # Bind address
  workers: 2,              # Puma workers
  threads: '1:5'           # Min:max threads per worker
)
```

## Client Configuration

### Basic Options

```ruby
client = SimpleAcp::Client::Base.new(
  base_url: 'http://localhost:8000',
  timeout: 30  # Request timeout in seconds
)
```

### With Authentication

```ruby
client = SimpleAcp::Client::Base.new(
  base_url: 'http://localhost:8000',
  headers: {
    'Authorization' => "Bearer #{ENV['API_TOKEN']}"
  }
)
```

### Session Configuration

```ruby
# Use a specific session for stateful interactions
client.use_session("user-123-session")

# All subsequent requests will use this session
client.run_sync(agent: "stateful-agent", input: "...")
client.run_sync(agent: "stateful-agent", input: "...")

# Clear when done
client.clear_session
```

## Environment Variables

SimpleAcp respects these environment variables:

| Variable | Purpose | Default |
|----------|---------|---------|
| `REDIS_URL` | Redis connection URL | `redis://localhost:6379` |
| `DATABASE_URL` | PostgreSQL connection URL | `postgres://localhost/acp` |

## Agent Configuration

When registering agents, you can configure:

```ruby
server.agent(
  "my-agent",
  description: "Description shown in manifest",
  input_content_types: ["text/plain", "application/json"],
  output_content_types: ["text/plain"]
) do |context|
  # Agent logic
end
```

### Agent Options

| Option | Type | Description |
|--------|------|-------------|
| `description` | String | Human-readable description |
| `input_content_types` | Array | Accepted input MIME types |
| `output_content_types` | Array | Output MIME types produced |
| `metadata` | Hash | Custom metadata |

## Logging

Configure logging for debugging:

```ruby
# Enable debug logging
SimpleAcp.configure do |config|
  config.logger = Logger.new(STDOUT)
  config.logger.level = Logger::DEBUG
end
```

## Next Steps

- Explore [Core Concepts](../core-concepts/index.md)
- Learn about [Storage Backends](../storage/index.md) in detail
- Read the [Server Guide](../server/index.md) for advanced features
