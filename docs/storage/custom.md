# Custom Storage Backends

Build your own storage backend to integrate with any data store or implement special requirements.

## Interface

All storage backends extend `SimpleAcp::Storage::Base`:

```ruby
module SimpleAcp
  module Storage
    class Base
      def initialize(options = {})
      def get_run(run_id)
      def save_run(run)
      def delete_run(run_id)
      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)

      def get_session(session_id)
      def save_session(session)
      def delete_session(session_id)

      def add_event(run_id, event)
      def get_events(run_id, limit: 100, offset: 0)

      def close
      def ping
    end
  end
end
```

## Minimal Implementation

```ruby
class MyStorage < SimpleAcp::Storage::Base
  def initialize(options = {})
    super
    @runs = {}
    @sessions = {}
    @events = {}
  end

  # Runs
  def get_run(run_id)
    @runs[run_id]
  end

  def save_run(run)
    @runs[run.run_id] = run
    run
  end

  def delete_run(run_id)
    @events.delete(run_id)
    @runs.delete(run_id)
  end

  def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
    runs = @runs.values
    runs = runs.select { |r| r.agent_name == agent_name } if agent_name
    runs = runs.select { |r| r.session_id == session_id } if session_id
    runs = runs.sort_by { |r| r.created_at || Time.at(0) }.reverse

    {
      runs: runs.drop(offset).take(limit),
      total: runs.length
    }
  end

  # Sessions
  def get_session(session_id)
    @sessions[session_id]
  end

  def save_session(session)
    @sessions[session.id] = session
    session
  end

  def delete_session(session_id)
    @sessions.delete(session_id)
  end

  # Events
  def add_event(run_id, event)
    @events[run_id] ||= []
    @events[run_id] << event
    event
  end

  def get_events(run_id, limit: 100, offset: 0)
    events = @events[run_id] || []
    events.drop(offset).take(limit)
  end

  # Lifecycle
  def close
    # Cleanup if needed
  end

  def ping
    true
  end
end
```

## Example: SQLite Backend

```ruby
require 'sequel'

class SQLiteStorage < SimpleAcp::Storage::Base
  def initialize(options = {})
    super
    @db = Sequel.sqlite(options[:path] || ':memory:')
    setup_tables
  end

  def get_run(run_id)
    row = @db[:runs].where(run_id: run_id).first
    return nil unless row
    deserialize_run(row)
  end

  def save_run(run)
    data = serialize_run(run)

    if @db[:runs].where(run_id: run.run_id).count > 0
      @db[:runs].where(run_id: run.run_id).update(data)
    else
      @db[:runs].insert(data)
    end

    run
  end

  def delete_run(run_id)
    @db[:events].where(run_id: run_id).delete
    @db[:runs].where(run_id: run_id).delete
  end

  def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
    dataset = @db[:runs]
    dataset = dataset.where(agent_name: agent_name) if agent_name
    dataset = dataset.where(session_id: session_id) if session_id

    total = dataset.count
    rows = dataset
      .order(Sequel.desc(:created_at))
      .limit(limit)
      .offset(offset)
      .all

    {
      runs: rows.map { |r| deserialize_run(r) },
      total: total
    }
  end

  # ... similar for sessions and events

  private

  def setup_tables
    @db.create_table?(:runs) do
      String :run_id, primary_key: true
      String :agent_name
      String :session_id
      String :status
      Text :output
      Text :error
      DateTime :created_at
      DateTime :finished_at
    end

    @db.create_table?(:sessions) do
      String :id, primary_key: true
      Text :history
      Text :state
    end

    @db.create_table?(:events) do
      primary_key :id
      String :run_id
      String :event_type
      Text :data
      DateTime :created_at
    end
  end

  def serialize_run(run)
    {
      run_id: run.run_id,
      agent_name: run.agent_name,
      session_id: run.session_id,
      status: run.status,
      output: run.output.to_json,
      error: run.error&.to_json,
      created_at: run.created_at,
      finished_at: run.finished_at
    }
  end

  def deserialize_run(row)
    output = row[:output] ? JSON.parse(row[:output]).map { |m|
      SimpleAcp::Models::Message.from_hash(m)
    } : []

    run = SimpleAcp::Models::Run.new(
      run_id: row[:run_id],
      agent_name: row[:agent_name],
      session_id: row[:session_id],
      status: row[:status]
    )
    run.instance_variable_set(:@output, output)
    run.instance_variable_set(:@created_at, row[:created_at])
    run.instance_variable_set(:@finished_at, row[:finished_at])
    run
  end
end
```

## Example: S3 Backend

For archival storage:

```ruby
require 'aws-sdk-s3'

class S3Storage < SimpleAcp::Storage::Base
  def initialize(options = {})
    super
    @s3 = Aws::S3::Client.new(
      region: options[:region] || 'us-east-1'
    )
    @bucket = options[:bucket]
    @prefix = options[:prefix] || 'acp/'

    # Use memory for active data, S3 for archive
    @active = SimpleAcp::Storage::Memory.new
  end

  def get_run(run_id)
    # Check active first
    run = @active.get_run(run_id)
    return run if run

    # Fall back to S3
    load_from_s3("runs/#{run_id}")
  end

  def save_run(run)
    @active.save_run(run)

    # Archive completed runs
    if run.terminal?
      save_to_s3("runs/#{run.run_id}", run.to_json)
    end

    run
  end

  # ... implement other methods

  private

  def save_to_s3(key, data)
    @s3.put_object(
      bucket: @bucket,
      key: "#{@prefix}#{key}",
      body: data
    )
  end

  def load_from_s3(key)
    response = @s3.get_object(
      bucket: @bucket,
      key: "#{@prefix}#{key}"
    )
    JSON.parse(response.body.read)
  rescue Aws::S3::Errors::NoSuchKey
    nil
  end
end
```

## Example: Hybrid Backend

Combine multiple backends:

```ruby
class HybridStorage < SimpleAcp::Storage::Base
  def initialize(options = {})
    super
    @cache = SimpleAcp::Storage::Redis.new(
      url: options[:redis_url],
      ttl: 3600  # 1 hour cache
    )
    @persistent = SimpleAcp::Storage::PostgreSQL.new(
      url: options[:database_url]
    )
  end

  def get_run(run_id)
    # Try cache first
    run = @cache.get_run(run_id)
    return run if run

    # Fall back to database
    run = @persistent.get_run(run_id)

    # Populate cache
    @cache.save_run(run) if run

    run
  end

  def save_run(run)
    # Write to both
    @cache.save_run(run)
    @persistent.save_run(run)
    run
  end

  def delete_run(run_id)
    @cache.delete_run(run_id)
    @persistent.delete_run(run_id)
  end

  # ... implement other methods delegating appropriately
end
```

## Testing Custom Backends

```ruby
class CustomStorageTest < Minitest::Test
  def setup
    @storage = MyStorage.new
  end

  def teardown
    @storage.close
  end

  def test_save_and_get_run
    run = create_test_run
    @storage.save_run(run)

    loaded = @storage.get_run(run.run_id)
    assert_equal run.run_id, loaded.run_id
    assert_equal run.agent_name, loaded.agent_name
  end

  def test_list_runs_filters
    @storage.save_run(create_test_run(agent_name: "a"))
    @storage.save_run(create_test_run(agent_name: "b"))

    result = @storage.list_runs(agent_name: "a")
    assert_equal 1, result[:total]
    assert_equal "a", result[:runs].first.agent_name
  end

  def test_session_persistence
    session = create_test_session
    @storage.save_session(session)

    loaded = @storage.get_session(session.id)
    assert_equal session.id, loaded.id
  end

  def test_events_ordering
    events = 3.times.map { |i| create_test_event(i) }
    events.each { |e| @storage.add_event("run-1", e) }

    loaded = @storage.get_events("run-1")
    assert_equal 3, loaded.length
  end

  private

  def create_test_run(overrides = {})
    SimpleAcp::Models::Run.new({
      run_id: SecureRandom.uuid,
      agent_name: "test",
      status: "completed"
    }.merge(overrides))
  end

  def create_test_session
    SimpleAcp::Models::Session.new(id: SecureRandom.uuid)
  end

  def create_test_event(index)
    SimpleAcp::Models::MessagePartEvent.new(
      part: SimpleAcp::Models::MessagePart.text("Event #{index}")
    )
  end
end
```

## Best Practices

1. **Implement all methods** - Don't leave `NotImplementedError`
2. **Handle missing data** - Return `nil` for not found
3. **Be thread-safe** - Use appropriate locking
4. **Test thoroughly** - Cover edge cases
5. **Document limitations** - Note any constraints

## Next Steps

- Review built-in [Memory](memory.md), [Redis](redis.md), and [PostgreSQL](postgresql.md) implementations
- See [API Reference](../api/storage.md) for interface details
