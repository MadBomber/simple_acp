# frozen_string_literal: true

require "test_helper"

class StorageBaseTest < SimpleAcpTestCase
  def test_get_run_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.get_run("id") }
  end

  def test_save_run_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new
    run = SimpleAcp::Models::Run.new(agent_name: "test")

    assert_raises(NotImplementedError) { storage.save_run(run) }
  end

  def test_delete_run_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.delete_run("id") }
  end

  def test_list_runs_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.list_runs }
  end

  def test_get_session_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.get_session("id") }
  end

  def test_save_session_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new
    session = SimpleAcp::Models::Session.create

    assert_raises(NotImplementedError) { storage.save_session(session) }
  end

  def test_delete_session_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.delete_session("id") }
  end

  def test_add_event_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new
    event = SimpleAcp::Models::GenericEvent.new(data: {})

    assert_raises(NotImplementedError) { storage.add_event("run_id", event) }
  end

  def test_get_events_raises_not_implemented
    storage = SimpleAcp::Storage::Base.new

    assert_raises(NotImplementedError) { storage.get_events("run_id") }
  end

  def test_ping_returns_true_by_default
    storage = SimpleAcp::Storage::Base.new

    assert storage.ping
  end

  def test_close_does_not_raise
    storage = SimpleAcp::Storage::Base.new

    assert_nil storage.close
  end
end
