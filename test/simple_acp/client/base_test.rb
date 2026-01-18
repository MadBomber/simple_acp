# frozen_string_literal: true

require "test_helper"

class ClientBaseTest < SimpleAcpTestCase
  def setup
    @client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
  end

  def test_initialize_sets_base_url
    assert_equal "http://localhost:8000", @client.base_url
  end

  def test_initialize_strips_trailing_slash
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000/")
    assert_equal "http://localhost:8000", client.base_url
  end

  def test_use_session_sets_session_id
    @client.use_session("my-session")

    # Can't directly test the private variable, but we can test clear_session
    @client.clear_session
    # No assertion needed - just verifying no error
  end

  def test_clear_session_removes_session_id
    @client.use_session("my-session")
    @client.clear_session

    # No direct way to test, but method should work without error
  end

  def test_ping_with_stubbed_response
    stub_request(:get, "http://localhost:8000/ping")
      .to_return(status: 200, body: '{"status":"ok"}', headers: { "Content-Type" => "application/json" })

    assert @client.ping
  end

  def test_ping_returns_false_on_error
    stub_request(:get, "http://localhost:8000/ping")
      .to_return(status: 500)

    refute @client.ping
  end

  def test_agents_returns_agent_list
    stub_request(:get, "http://localhost:8000/agents")
      .with(query: { "limit" => "10", "offset" => "0" })
      .to_return(
        status: 200,
        body: '{"agents":[{"name":"test-agent","description":"Test"}],"total":1,"limit":10,"offset":0}',
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.agents

    assert_instance_of SimpleAcp::Models::AgentListResponse, result
    assert_equal 1, result.agents.length
    assert_equal "test-agent", result.agents.first.name
  end

  def test_agent_returns_manifest
    stub_request(:get, "http://localhost:8000/agents/test-agent")
      .to_return(
        status: 200,
        body: '{"name":"test-agent","description":"Test agent"}',
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.agent("test-agent")

    assert_instance_of SimpleAcp::Models::AgentManifest, result
    assert_equal "test-agent", result.name
  end

  def test_agent_raises_not_found_for_unknown_agent
    stub_request(:get, "http://localhost:8000/agents/unknown")
      .to_return(
        status: 404,
        body: '{"error":{"code":"not_found","message":"Agent not found"}}',
        headers: { "Content-Type" => "application/json" }
      )

    assert_raises(SimpleAcp::NotFoundError) { @client.agent("unknown") }
  end

  def test_run_sync_creates_run
    stub_request(:post, "http://localhost:8000/runs")
      .to_return(
        status: 200,
        body: '{"run_id":"123","agent_name":"test","status":"completed","output":[{"role":"agent","parts":[{"content_type":"text/plain","content":"Hello"}]}]}',
        headers: { "Content-Type" => "application/json" }
      )

    run = @client.run_sync(agent: "test", input: "Hello")

    assert_instance_of SimpleAcp::Models::Run, run
    assert_equal "123", run.run_id
    assert run.completed?
  end

  def test_run_status_returns_run
    stub_request(:get, "http://localhost:8000/runs/123")
      .to_return(
        status: 200,
        body: '{"run_id":"123","agent_name":"test","status":"in-progress","output":[]}',
        headers: { "Content-Type" => "application/json" }
      )

    run = @client.run_status("123")

    assert_instance_of SimpleAcp::Models::Run, run
    assert run.in_progress?
  end

  def test_run_cancel_cancels_run
    stub_request(:post, "http://localhost:8000/runs/123/cancel")
      .to_return(
        status: 200,
        body: '{"run_id":"123","agent_name":"test","status":"cancelled","output":[]}',
        headers: { "Content-Type" => "application/json" }
      )

    run = @client.run_cancel("123")

    assert run.cancelled?
  end

  def test_run_events_returns_events
    stub_request(:get, "http://localhost:8000/runs/123/events")
      .with(query: { "limit" => "100", "offset" => "0" })
      .to_return(
        status: 200,
        body: '{"events":[{"type":"run.created"},{"type":"run.completed"}]}',
        headers: { "Content-Type" => "application/json" }
      )

    events = @client.run_events("123")

    assert_equal 2, events.length
  end

  def test_session_returns_session_response
    stub_request(:get, "http://localhost:8000/session/sess-123")
      .to_return(
        status: 200,
        body: '{"id":"sess-123","history_count":5,"has_state":true}',
        headers: { "Content-Type" => "application/json" }
      )

    response = @client.session("sess-123")

    assert_equal "sess-123", response.id
    assert_equal 5, response.history_count
    assert response.has_state
  end

  def test_close_does_not_raise
    assert_nil @client.close
  end
end
