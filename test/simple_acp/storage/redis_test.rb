# frozen_string_literal: true

require "test_helper"

# Redis storage tests - require a running Redis instance
# Skip these tests if Redis is not available
class StorageRedisTest < SimpleAcpTestCase
  def setup
    skip_without_redis

    @storage = SimpleAcp::Storage::Redis.new(
      url: redis_url,
      prefix: "test_acp:",
      ttl: 300 # 5 minutes for tests
    )
    @storage.clear! # Start fresh
  end

  def teardown
    @storage&.clear!
    @storage&.close
  end

  # Run storage tests

  def test_save_run_and_get_run
    run = SimpleAcp::Models::Run.new(
      agent_name: "test-agent",
      session_id: "session-123"
    )

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal run.run_id, retrieved.run_id
    assert_equal run.agent_name, retrieved.agent_name
    assert_equal run.session_id, retrieved.session_id
  end

  def test_get_run_returns_nil_for_nonexistent
    assert_nil @storage.get_run("non-existent")
  end

  def test_delete_run_removes_run
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    @storage.save_run(run)

    @storage.delete_run(run.run_id)

    assert_nil @storage.get_run(run.run_id)
  end

  def test_delete_run_removes_associated_events
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    @storage.save_run(run)
    @storage.add_event(run.run_id, SimpleAcp::Models::GenericEvent.new(data: { test: true }))

    @storage.delete_run(run.run_id)

    assert_equal [], @storage.get_events(run.run_id)
  end

  def test_list_runs_returns_all_runs
    3.times { @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent")) }

    result = @storage.list_runs

    assert_equal 3, result[:total]
    assert_equal 3, result[:runs].length
  end

  def test_list_runs_filters_by_agent_name
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent-a"))
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent-b"))
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent-a"))

    result = @storage.list_runs(agent_name: "agent-a")

    assert_equal 2, result[:total]
    assert result[:runs].all? { |r| r.agent_name == "agent-a" }
  end

  def test_list_runs_filters_by_session_id
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent", session_id: "session-1"))
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent", session_id: "session-2"))
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent", session_id: "session-1"))

    result = @storage.list_runs(session_id: "session-1")

    assert_equal 2, result[:total]
    assert result[:runs].all? { |r| r.session_id == "session-1" }
  end

  def test_list_runs_supports_pagination
    5.times { @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "agent")) }

    result = @storage.list_runs(limit: 2, offset: 1)

    assert_equal 2, result[:runs].length
    assert_equal 5, result[:total]
  end

  def test_save_run_preserves_status
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    run.complete!([SimpleAcp::Models::Message.agent("Done")])

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal "completed", retrieved.status
  end

  def test_save_run_preserves_output
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    run.complete!([SimpleAcp::Models::Message.agent("Output message")])

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal 1, retrieved.output.length
    assert_equal "Output message", retrieved.output.first.text_content
  end

  # Session storage tests

  def test_save_session_and_get_session
    session = SimpleAcp::Models::Session.new(id: "session-456")
    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))

    @storage.save_session(session)
    retrieved = @storage.get_session(session.id)

    assert_equal session.id, retrieved.id
    assert_equal 1, retrieved.history.length
    assert_equal "Hello", retrieved.history.first.text_content
  end

  def test_get_session_returns_nil_for_nonexistent
    assert_nil @storage.get_session("non-existent")
  end

  def test_delete_session_removes_session
    session = SimpleAcp::Models::Session.new(id: "session-789")
    @storage.save_session(session)

    @storage.delete_session(session.id)

    assert_nil @storage.get_session(session.id)
  end

  def test_save_session_preserves_state
    session = SimpleAcp::Models::Session.new(id: "session-state")
    session.set_state({ counter: 42, name: "test" })

    @storage.save_session(session)
    retrieved = @storage.get_session(session.id)

    assert_equal({ "counter" => 42, "name" => "test" }, retrieved.state)
  end

  # Event storage tests

  def test_add_event_and_get_events
    run_id = "run-789"
    event1 = SimpleAcp::Models::RunCreatedEvent.new(
      run: SimpleAcp::Models::Run.new(agent_name: "test")
    )
    event2 = SimpleAcp::Models::RunInProgressEvent.new(run_id: run_id)

    @storage.add_event(run_id, event1)
    @storage.add_event(run_id, event2)

    events = @storage.get_events(run_id)

    assert_equal 2, events.length
    assert_equal "run.created", events.first.type
    assert_equal "run.in-progress", events.last.type
  end

  def test_get_events_returns_empty_array_for_no_events
    events = @storage.get_events("no-events-run")
    assert_equal [], events
  end

  def test_get_events_supports_pagination
    run_id = "run-pagination"
    10.times do |i|
      @storage.add_event(run_id, SimpleAcp::Models::GenericEvent.new(data: { index: i }))
    end

    events = @storage.get_events(run_id, limit: 3, offset: 2)

    assert_equal 3, events.length
  end

  # Lifecycle tests

  def test_ping_returns_true
    assert @storage.ping
  end

  def test_clear_removes_all_data
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "test"))
    @storage.save_session(SimpleAcp::Models::Session.new(id: "s1"))
    @storage.add_event("r1", SimpleAcp::Models::GenericEvent.new(data: {}))

    @storage.clear!

    assert_nil @storage.get_run(@storage.list_runs[:runs].first&.run_id)
    assert_nil @storage.get_session("s1")
  end

  # TTL tests

  def test_default_ttl_is_24_hours
    storage = SimpleAcp::Storage::Redis.new(url: redis_url, prefix: "test_ttl:")
    assert_equal 86_400, storage.instance_variable_get(:@ttl)
    storage.close
  end

  def test_custom_prefix
    storage = SimpleAcp::Storage::Redis.new(url: redis_url, prefix: "custom:")
    assert_equal "custom:", storage.instance_variable_get(:@prefix)
    storage.close
  end

  private

  def redis_url
    ENV.fetch("REDIS_URL", "redis://localhost:6379")
  end

  def skip_without_redis
    require "redis"
    require "simple_acp/storage/redis"
    redis = ::Redis.new(url: redis_url)
    redis.ping
    redis.close
  rescue LoadError => e
    skip "Redis gem not installed: #{e.message}"
  rescue StandardError => e
    skip "Redis server not available at #{redis_url}: #{e.message}"
  end
end
