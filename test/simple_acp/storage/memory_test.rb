# frozen_string_literal: true

require "test_helper"

class StorageMemoryTest < SimpleAcpTestCase
  def setup
    @storage = SimpleAcp::Storage::Memory.new
  end

  # Run storage tests

  def test_save_run_and_get_run
    run = SimpleAcp::Models::Run.new(
      agent_name: "test-agent",
      session_id: "session-123"
    )

    @storage.save_run(run)
    retrieved = @storage.get_run(run.run_id)

    assert_equal run, retrieved
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

  # Session storage tests

  def test_save_session_and_get_session
    session = SimpleAcp::Models::Session.new(id: "session-456")
    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))

    @storage.save_session(session)
    retrieved = @storage.get_session(session.id)

    assert_equal session.id, retrieved.id
    assert_equal 1, retrieved.history.length
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

  def test_stats_returns_storage_statistics
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "test"))
    @storage.save_session(SimpleAcp::Models::Session.new(id: "s1"))
    @storage.add_event("r1", SimpleAcp::Models::GenericEvent.new(data: {}))

    stats = @storage.stats

    assert_equal 1, stats[:runs]
    assert_equal 1, stats[:sessions]
    assert_equal 1, stats[:events]
  end

  def test_clear_removes_all_data
    @storage.save_run(SimpleAcp::Models::Run.new(agent_name: "test"))
    @storage.save_session(SimpleAcp::Models::Session.new(id: "s1"))
    @storage.add_event("r1", SimpleAcp::Models::GenericEvent.new(data: {}))

    @storage.clear!

    assert_equal({ runs: 0, sessions: 0, events: 0 }, @storage.stats)
  end

  def test_ping_returns_true
    assert @storage.ping
  end
end
