# Memory Storage

The Memory storage backend stores all data in-process using thread-safe data structures. It's the default backend and ideal for development and testing.

## Features

- **Zero dependencies** - No external services required
- **Thread-safe** - Uses `concurrent-ruby` for safe concurrent access
- **Fast** - All operations are in-memory
- **Simple** - No configuration needed

## Limitations

- **Not persistent** - Data is lost when the process exits
- **Single process** - Cannot share data between processes
- **Memory bound** - Limited by available RAM

## Usage

### Basic Setup

```ruby
require 'simple_acp'

# Memory is the default
server = SimpleAcp::Server::Base.new

# Or explicitly
storage = SimpleAcp::Storage::Memory.new
server = SimpleAcp::Server::Base.new(storage: storage)
```

### With Options

```ruby
storage = SimpleAcp::Storage::Memory.new(
  # Currently no specific options
)
```

## Operations

### Runs

```ruby
# Save a run
storage.save_run(run)

# Get a run
run = storage.get_run("run-id")

# Delete a run
storage.delete_run("run-id")

# List runs
result = storage.list_runs(
  agent_name: "echo",    # Optional filter
  session_id: "sess-1",  # Optional filter
  limit: 10,
  offset: 0
)
puts result[:runs]   # Array of runs
puts result[:total]  # Total count
```

### Sessions

```ruby
# Save a session
storage.save_session(session)

# Get a session
session = storage.get_session("session-id")

# Delete a session
storage.delete_session("session-id")
```

### Events

```ruby
# Add an event
storage.add_event("run-id", event)

# Get events
events = storage.get_events("run-id", limit: 100, offset: 0)
```

## Utility Methods

### Clear All Data

```ruby
storage.clear!
```

### Get Statistics

```ruby
stats = storage.stats

puts "Runs: #{stats[:runs]}"
puts "Sessions: #{stats[:sessions]}"
puts "Events: #{stats[:events]}"
```

### Health Check

```ruby
if storage.ping
  puts "Storage is healthy"
end
```

## Thread Safety

Memory storage uses `Concurrent::Map` from concurrent-ruby:

```ruby
# Safe for concurrent access
threads = 10.times.map do |i|
  Thread.new do
    run = create_run(i)
    storage.save_run(run)
  end
end

threads.each(&:join)
```

## Testing

Memory storage is ideal for tests:

```ruby
class MyAgentTest < Minitest::Test
  def setup
    @storage = SimpleAcp::Storage::Memory.new
    @server = SimpleAcp::Server::Base.new(storage: @storage)
    register_agents(@server)
  end

  def teardown
    @storage.clear!
  end

  def test_agent_behavior
    run = @server.run_sync(
      agent_name: "echo",
      input: [SimpleAcp::Models::Message.user("test")]
    )

    assert_equal "completed", run.status
  end
end
```

## Migration to Production

When moving to production, switch to Redis or PostgreSQL:

```ruby
# Development
if ENV['RACK_ENV'] == 'development'
  storage = SimpleAcp::Storage::Memory.new
else
  # Production
  storage = SimpleAcp::Storage::Redis.new(url: ENV['REDIS_URL'])
  # or
  storage = SimpleAcp::Storage::PostgreSQL.new(url: ENV['DATABASE_URL'])
end

server = SimpleAcp::Server::Base.new(storage: storage)
```

## Best Practices

1. **Use for development** - Quick iteration without setup
2. **Use for tests** - Isolated, fast test runs
3. **Clear between tests** - Use `clear!` in teardown
4. **Monitor memory** - Watch for growing data in long runs
5. **Don't use in production** - Data loss on restart

## Implementation Details

The Memory backend uses these data structures:

| Data | Structure | Thread Safety |
|------|-----------|---------------|
| Runs | `Concurrent::Map` | Yes |
| Sessions | `Concurrent::Map` | Yes |
| Events | `Concurrent::Map` with `Mutex` | Yes |

## Next Steps

- Learn about [Redis](redis.md) for distributed deployments
- Explore [PostgreSQL](postgresql.md) for persistent storage
- Build a [Custom Backend](custom.md) for special needs
