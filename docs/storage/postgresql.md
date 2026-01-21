# PostgreSQL Storage

PostgreSQL storage provides permanent, relational storage ideal for production deployments requiring audit trails and complex queries.

## Features

- **Persistent** - Data survives restarts
- **ACID compliant** - Reliable transactions
- **Queryable** - Full SQL capabilities
- **Scalable** - Supports read replicas

## Requirements

Add the Sequel and pg gems to your Gemfile:

```ruby
gem 'sequel', '~> 5.0'
gem 'pg', '~> 1.5'
```

## Usage

### Basic Setup

```ruby
require 'simple_acp'
require 'simple_acp/storage/postgresql'

storage = SimpleAcp::Storage::PostgreSQL.new(
  url: "postgres://localhost/simple_acp"
)

server = SimpleAcp::Server::Base.new(storage: storage)
```

### Configuration Options

```ruby
storage = SimpleAcp::Storage::PostgreSQL.new(
  # Connection URL
  url: "postgres://user:pass@host:5432/database",

  # Or specify individually
  host: "localhost",
  port: 5432,
  database: "simple_acp",
  user: "postgres",
  password: "secret",

  # Or use existing Sequel connection
  db: existing_sequel_db,

  # Behavior
  skip_setup: false  # Skip automatic table creation
)
```

### Environment Variables

```ruby
# Uses DATABASE_URL if not specified
storage = SimpleAcp::Storage::PostgreSQL.new

# Reads from:
# ENV['DATABASE_URL'] || "postgres://localhost/acp"
```

## Database Schema

Tables are automatically created on first use:

### acp_runs

```sql
CREATE TABLE acp_runs (
  run_id VARCHAR PRIMARY KEY,
  agent_name VARCHAR NOT NULL,
  session_id VARCHAR,
  status VARCHAR NOT NULL,
  output TEXT,          -- JSON
  error TEXT,           -- JSON
  await_request TEXT,   -- JSON
  created_at TIMESTAMP,
  finished_at TIMESTAMP,
  updated_at TIMESTAMP
);

CREATE INDEX idx_runs_agent ON acp_runs(agent_name);
CREATE INDEX idx_runs_session ON acp_runs(session_id);
```

### acp_sessions

```sql
CREATE TABLE acp_sessions (
  id VARCHAR PRIMARY KEY,
  history TEXT,         -- JSON
  state TEXT,           -- JSON
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);
```

### acp_events

```sql
CREATE TABLE acp_events (
  id SERIAL PRIMARY KEY,
  run_id VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,
  data TEXT,            -- JSON
  created_at TIMESTAMP
);

CREATE INDEX idx_events_run ON acp_events(run_id);
```

## Operations

### Runs

```ruby
# Save
storage.save_run(run)

# Get
run = storage.get_run("run-id")

# Delete (also deletes events)
storage.delete_run("run-id")

# List with filters
result = storage.list_runs(
  agent_name: "echo",
  session_id: "session-123",
  limit: 10,
  offset: 0
)
```

### Sessions

```ruby
# Save (insert or update)
storage.save_session(session)

# Get
session = storage.get_session("session-id")

# Delete
storage.delete_session("session-id")
```

### Events

```ruby
# Add
storage.add_event("run-id", event)

# Get with pagination
events = storage.get_events("run-id", limit: 100, offset: 0)
```

## Connection Management

### Connection Pool

Sequel automatically manages connection pooling:

```ruby
storage = SimpleAcp::Storage::PostgreSQL.new(
  url: ENV['DATABASE_URL']
)

# Pool is managed automatically
```

### Close Connection

```ruby
storage.close  # Disconnects from database
```

### Health Check

```ruby
if storage.ping
  puts "PostgreSQL is healthy"
else
  puts "PostgreSQL connection failed"
end
```

## Production Configuration

### Recommended Setup

```ruby
storage = SimpleAcp::Storage::PostgreSQL.new(
  url: ENV['DATABASE_URL'],
  skip_setup: true  # Manage schema via migrations
)
```

### With Connection Options

```ruby
require 'sequel'

db = Sequel.connect(
  ENV['DATABASE_URL'],
  max_connections: 10,
  pool_timeout: 10,
  connect_timeout: 5
)

storage = SimpleAcp::Storage::PostgreSQL.new(db: db)
```

## Custom Queries

Access the underlying Sequel database:

```ruby
# Get the Sequel database object
db = storage.instance_variable_get(:@db)

# Custom queries
recent_runs = db[:acp_runs]
  .where(agent_name: "chat")
  .where { created_at > Time.now - 3600 }
  .order(Sequel.desc(:created_at))
  .limit(10)
  .all

# Aggregate queries
stats = db[:acp_runs]
  .group(:agent_name)
  .select { [agent_name, count(*).as(total)] }
  .all
```

## Maintenance

### Clear All Data

```ruby
storage.clear!  # Truncates all tables
```

### Manual Schema Setup

```ruby
# Skip auto-setup
storage = SimpleAcp::Storage::PostgreSQL.new(
  url: ENV['DATABASE_URL'],
  skip_setup: true
)

# Run migrations manually in your deployment
```

### Vacuum and Analyze

```sql
-- Periodic maintenance
VACUUM ANALYZE acp_runs;
VACUUM ANALYZE acp_sessions;
VACUUM ANALYZE acp_events;
```

### Archive Old Data

```sql
-- Move old runs to archive
INSERT INTO acp_runs_archive
SELECT * FROM acp_runs
WHERE created_at < NOW() - INTERVAL '90 days';

DELETE FROM acp_runs
WHERE created_at < NOW() - INTERVAL '90 days';
```

## Error Handling

```ruby
begin
  run = storage.get_run("run-id")
rescue Sequel::DatabaseConnectionError
  puts "Database connection failed"
rescue Sequel::DatabaseError => e
  puts "Database error: #{e.message}"
end
```

## Performance Tips

### Indexes

The default schema includes indexes on common query patterns. Add more as needed:

```sql
-- For time-range queries
CREATE INDEX idx_runs_created ON acp_runs(created_at);

-- For status queries
CREATE INDEX idx_runs_status ON acp_runs(status);
```

### Partitioning

For high-volume deployments, consider partitioning:

```sql
-- Partition events by month
CREATE TABLE acp_events (
  id SERIAL,
  run_id VARCHAR NOT NULL,
  event_type VARCHAR NOT NULL,
  data TEXT,
  created_at TIMESTAMP
) PARTITION BY RANGE (created_at);

CREATE TABLE acp_events_2025_01 PARTITION OF acp_events
FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
```

## Best Practices

1. **Use connection pooling** - Let Sequel manage connections
2. **Skip auto-setup in production** - Use migrations instead
3. **Index appropriately** - Based on your query patterns
4. **Archive old data** - Keep tables manageable
5. **Monitor query performance** - Watch for slow queries

## Comparison with Other Backends

| Feature | PostgreSQL | Redis | Memory |
|---------|------------|-------|--------|
| Persistence | Permanent | TTL | None |
| Multi-process | Yes | Yes | No |
| Speed | Moderate | Fast | Fastest |
| Query flexibility | Full SQL | Limited | None |
| Audit trail | Yes | Limited | No |

## Next Steps

- Learn about [Redis](redis.md) for caching layer
- Build a [Custom Backend](custom.md) for special needs
- Review [Memory](memory.md) for development
