# Storage

Storage backend interface and implementations.

## Interface

All storage backends extend `SimpleAcp::Storage::Base`.

### Class: SimpleAcp::Storage::Base

#### Constructor

```ruby
SimpleAcp::Storage::Base.new(options = {})
```

#### Abstract Methods

These methods must be implemented by subclasses:

---

##### #get_run

Retrieve a run by ID.

```ruby
storage.get_run(run_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run ID |

**Returns:** `Models::Run` or `nil`

---

##### #save_run

Save a run.

```ruby
storage.save_run(run)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run` | `Models::Run` | Run to save |

**Returns:** `Models::Run`

---

##### #delete_run

Delete a run and its events.

```ruby
storage.delete_run(run_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run ID |

**Returns:** `void`

---

##### #list_runs

List runs with optional filtering.

```ruby
storage.list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `agent_name` | `String` | `nil` | Filter by agent |
| `session_id` | `String` | `nil` | Filter by session |
| `limit` | `Integer` | `10` | Max results |
| `offset` | `Integer` | `0` | Skip count |

**Returns:** `Hash` with `:runs` and `:total`

```ruby
{ runs: [Run, ...], total: 42 }
```

---

##### #get_session

Retrieve a session by ID.

```ruby
storage.get_session(session_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `session_id` | `String` | Session ID |

**Returns:** `Models::Session` or `nil`

---

##### #save_session

Save a session.

```ruby
storage.save_session(session)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `session` | `Models::Session` | Session to save |

**Returns:** `Models::Session`

---

##### #delete_session

Delete a session.

```ruby
storage.delete_session(session_id)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `session_id` | `String` | Session ID |

**Returns:** `void`

---

##### #add_event

Add an event to a run.

```ruby
storage.add_event(run_id, event)
```

**Parameters:**

| Name | Type | Description |
|------|------|-------------|
| `run_id` | `String` | Run ID |
| `event` | `Event` | Event to add |

**Returns:** `Event`

---

##### #get_events

Get events for a run.

```ruby
storage.get_events(run_id, limit: 100, offset: 0)
```

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `run_id` | `String` | required | Run ID |
| `limit` | `Integer` | `100` | Max events |
| `offset` | `Integer` | `0` | Skip count |

**Returns:** `Array<Event>`

---

#### Optional Methods

These have default implementations:

##### #close

Close the storage connection.

```ruby
storage.close
```

**Default:** No-op

---

##### #ping

Check if storage is accessible.

```ruby
storage.ping
```

**Returns:** `Boolean`

**Default:** Returns `true`

---

## Implementations

### Memory

```ruby
storage = SimpleAcp::Storage::Memory.new
```

**Additional Methods:**

```ruby
storage.clear!   # Clear all data
storage.stats    # Get counts { runs: N, sessions: N, events: N }
```

---

### Redis

```ruby
require 'simple_acp/storage/redis'

storage = SimpleAcp::Storage::Redis.new(
  url: "redis://localhost:6379",
  ttl: 86400,        # TTL in seconds (default: 24 hours)
  prefix: "acp:",    # Key prefix (default: "acp:")
  redis: nil         # Existing Redis connection
)
```

**Additional Methods:**

```ruby
storage.clear!   # Delete all keys with prefix
```

---

### PostgreSQL

```ruby
require 'simple_acp/storage/postgresql'

storage = SimpleAcp::Storage::PostgreSQL.new(
  url: "postgres://localhost/simple_acp",
  skip_setup: false,  # Skip table creation (default: false)
  db: nil             # Existing Sequel database
)
```

**Additional Methods:**

```ruby
storage.clear!   # Truncate all tables
```

---

## Custom Implementation

```ruby
class MyStorage < SimpleAcp::Storage::Base
  def initialize(options = {})
    super
    # Setup
  end

  def get_run(run_id)
    # Implementation
  end

  def save_run(run)
    # Implementation
  end

  def delete_run(run_id)
    # Implementation
  end

  def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
    # Implementation
  end

  def get_session(session_id)
    # Implementation
  end

  def save_session(session)
    # Implementation
  end

  def delete_session(session_id)
    # Implementation
  end

  def add_event(run_id, event)
    # Implementation
  end

  def get_events(run_id, limit: 100, offset: 0)
    # Implementation
  end

  def close
    # Cleanup
  end

  def ping
    # Health check
    true
  end
end
```

---

## See Also

- [Storage Overview](../storage/index.md)
- [Memory Storage](../storage/memory.md)
- [Redis Storage](../storage/redis.md)
- [PostgreSQL Storage](../storage/postgresql.md)
- [Custom Backends](../storage/custom.md)
