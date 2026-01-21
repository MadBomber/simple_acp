# frozen_string_literal: true

require "test_helper"

# PostgreSQL storage tests - require a running PostgreSQL instance
# Skip these tests if PostgreSQL is not available
class StoragePostgreSQLTest < SimpleAcpTestCase
  def setup
    skip_without_postgresql

    @storage = SimpleAcp::Storage::PostgreSQL.new(url: database_url)
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

  def test_list_runs_orders_by_created_at_descending
    old_run = SimpleAcp::Models::Run.new(agent_name: "agent")
    sleep 0.01 # Ensure different timestamps
    new_run = SimpleAcp::Models::Run.new(agent_name: "agent")

    @storage.save_run(old_run)
    @storage.save_run(new_run)

    result = @storage.list_runs
    # Newest first
    assert_equal new_run.run_id, result[:runs].first.run_id
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

  def test_save_run_preserves_error
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    run.fail!("Something went wrong")

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal "failed", retrieved.status
    assert_equal "Something went wrong", retrieved.error.message
  end

  def test_save_run_preserves_await_request
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    request = SimpleAcp::Models::MessageAwaitRequest.new(
      message: SimpleAcp::Models::Message.agent("What is your name?")
    )
    run.await!(request)

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal "awaiting", retrieved.status
    assert_instance_of SimpleAcp::Models::MessageAwaitRequest, retrieved.await_request
  end

  def test_save_run_updates_existing_run
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    @storage.save_run(run)

    run.start!
    @storage.save_run(run)

    retrieved = @storage.get_run(run.run_id)
    assert_equal "in-progress", retrieved.status
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

  def test_save_session_updates_existing_session
    session = SimpleAcp::Models::Session.new(id: "session-update")
    @storage.save_session(session)

    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))
    @storage.save_session(session)

    retrieved = @storage.get_session(session.id)
    assert_equal 1, retrieved.history.length
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

  def test_get_events_orders_by_created_at
    run_id = "run-order"
    @storage.add_event(run_id, SimpleAcp::Models::RunCreatedEvent.new(
      run: SimpleAcp::Models::Run.new(agent_name: "test")
    ))
    sleep 0.01
    @storage.add_event(run_id, SimpleAcp::Models::RunInProgressEvent.new(run_id: run_id))

    events = @storage.get_events(run_id)

    # Earliest first
    assert_equal "run.created", events.first.type
    assert_equal "run.in-progress", events.last.type
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

    result = @storage.list_runs
    assert_equal 0, result[:total]
    assert_nil @storage.get_session("s1")
  end

  # Table setup tests

  def test_skip_setup_option
    # Should not raise even without setup
    storage = SimpleAcp::Storage::PostgreSQL.new(
      url: database_url,
      skip_setup: true
    )
    assert storage
    storage.close
  end

  private

  def database_url
    ENV.fetch("DATABASE_URL", "postgres://localhost/simple_acp_test")
  end

  def skip_without_postgresql
    require "sequel"
    require "simple_acp/storage/postgresql"
    db = Sequel.connect(database_url)
    db.test_connection
    db.disconnect
  rescue LoadError => e
    skip "Sequel gem not installed: #{e.message}"
  rescue StandardError => e
    skip "PostgreSQL server not available at #{database_url}: #{e.message}"
  end
end
