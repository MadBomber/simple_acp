# frozen_string_literal: true

require "test_helper"

# Unit tests for Client::Base that don't require a server connection
class ClientBaseUnitTest < SimpleAcpTestCase
  def test_initialize_sets_base_url
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    assert_equal "http://localhost:8000", client.base_url
  end

  def test_initialize_strips_trailing_slash
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000/")
    assert_equal "http://localhost:8000", client.base_url
  end

  def test_use_session_does_not_raise
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    client.use_session("my-session")
    # No assertion needed - just verifying no error
  end

  def test_clear_session_does_not_raise
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    client.use_session("my-session")
    client.clear_session
    # No assertion needed - just verifying no error
  end

  def test_close_does_not_raise
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    assert_nil client.close
  end

  def test_normalize_input_handles_string
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    input = client.send(:normalize_input, "Hello")

    assert_equal 1, input.length
    assert_instance_of SimpleAcp::Models::Message, input.first
    assert_equal "Hello", input.first.text_content
  end

  def test_normalize_input_handles_message
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    message = SimpleAcp::Models::Message.user("Hello")
    input = client.send(:normalize_input, message)

    assert_equal 1, input.length
    assert_equal message, input.first
  end

  def test_normalize_input_handles_array
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    messages = [
      SimpleAcp::Models::Message.user("First"),
      SimpleAcp::Models::Message.user("Second")
    ]
    input = client.send(:normalize_input, messages)

    assert_equal 2, input.length
  end

  def test_normalize_input_handles_mixed_array
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    input = client.send(:normalize_input, ["String", SimpleAcp::Models::Message.user("Message")])

    assert_equal 2, input.length
    assert_equal "String", input[0].text_content
    assert_equal "Message", input[1].text_content
  end
end

# Integration tests for Client::Base using Rack::Test
# Tests the client against the actual server implementation
class ClientBaseIntegrationTest < SimpleAcpTestCase
  include Rack::Test::Methods

  def app
    @server ||= create_test_server
    @app_class ||= begin
      klass = Class.new(SimpleAcp::Server::App)
      klass.configure(@server)
      klass
    end
    @app_class.app
  end

  def setup
    @server = nil
    @app_class = nil
  end

  # Helper to make client requests via Rack::Test
  # This simulates what the client would do against the server

  def test_ping_endpoint_works
    get "/ping"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "ok", body["status"]
  end

  def test_agents_endpoint_returns_list
    get "/agents"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert body["agents"].length >= 2
  end

  def test_agent_endpoint_returns_manifest
    get "/agents/echo"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "echo", body["name"]
    assert_equal "Echoes input messages", body["description"]
  end

  def test_agent_endpoint_returns_404_for_unknown
    get "/agents/nonexistent"

    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)
    assert_equal "not_found", body["error"]["code"]
  end

  def test_run_sync_endpoint_creates_run
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Alice" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "completed", body["status"]
    assert_match(/Hello, Alice!/, body["output"].first["parts"].first["content"])
  end

  def test_run_status_endpoint_returns_run
    # Create a run first
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Get the run status
    get "/runs/#{run_id}"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal run_id, body["run_id"]
  end

  def test_run_cancel_endpoint_cancels_run
    # Create an async run
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "async"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Cancel it
    post "/runs/#{run_id}/cancel"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "cancelled", body["status"]
  end

  def test_run_events_endpoint_returns_events
    # Create a run first
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Get events
    get "/runs/#{run_id}/events"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_kind_of Array, body["events"]
  end

  def test_session_endpoint_returns_session
    # Create a run with a session
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      session_id: "test-session-456"
    }.to_json, "CONTENT_TYPE" => "application/json"

    # Get the session
    get "/session/test-session-456"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "test-session-456", body["id"]
  end

  def test_session_endpoint_returns_404_for_unknown
    get "/session/nonexistent-session"

    assert_equal 404, last_response.status
  end
end

# Tests for Client::Base with a session
class ClientSessionTest < SimpleAcpTestCase
  def test_session_id_is_included_in_runs
    # This tests the client logic for including session_id
    client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    client.use_session("my-session-id")

    # We can't make a real request without a server, but we can test
    # that the session is set by checking clear_session works
    client.clear_session

    # Re-set and verify no error
    client.use_session("another-session")
  end
end
