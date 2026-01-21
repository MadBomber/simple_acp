# frozen_string_literal: true

require "test_helper"

class ServerAppTest < SimpleAcpTestCase
  include Rack::Test::Methods

  def app
    # Create fresh app for each test to avoid state pollution
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

  # Health check tests
  def test_ping_returns_ok_status
    get "/ping"

    assert last_response.ok?
    body = JSON.parse(last_response.body)
    assert_equal "ok", body["status"]
  end

  def test_ping_returns_json_content_type
    get "/ping"

    assert_equal "application/json", last_response.content_type
  end

  # List agents tests
  def test_get_agents_returns_list
    get "/agents"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_includes body.keys, "agents"
    assert_includes body.keys, "total"
    assert_includes body.keys, "limit"
    assert_includes body.keys, "offset"
    assert body["total"] >= 2 # echo and greeter from test server
  end

  def test_get_agents_with_limit_parameter
    get "/agents", limit: 1

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal 1, body["limit"]
    assert_equal 1, body["agents"].length
  end

  def test_get_agents_with_offset_parameter
    get "/agents", offset: 1

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal 1, body["offset"]
    assert_equal 1, body["agents"].length # Only one remaining after offset
  end

  def test_get_agents_limit_clamped_to_max
    get "/agents", limit: 5000

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal 1000, body["limit"]
  end

  def test_get_agents_limit_clamped_to_min
    get "/agents", limit: 0

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal 1, body["limit"]
  end

  # Get specific agent tests
  def test_get_agent_returns_manifest
    get "/agents/echo"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal "echo", body["name"]
    assert_equal "Echoes input messages", body["description"]
  end

  def test_get_agent_not_found
    get "/agents/nonexistent"

    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)

    assert_includes body.keys, "error"
    assert_equal "not_found", body["error"]["code"]
  end

  # Create run tests (sync mode)
  def test_post_runs_sync_creates_and_completes_run
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Alice" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_includes body.keys, "run_id"
    assert_equal "completed", body["status"]
    assert_equal "greeter", body["agent_name"]
    assert body["output"].length >= 1
    assert_match(/Hello, Alice!/, body["output"].first["parts"].first["content"])
  end

  def test_post_runs_sync_default_mode
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Bob" }] }]
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal "completed", body["status"]
  end

  def test_post_runs_with_agent_not_found
    post "/runs", {
      agent_name: "nonexistent",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "test" }] }]
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal "not_found", body["error"]["code"]
  end

  def test_post_runs_with_invalid_input
    post "/runs", {}.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 400, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal "invalid_input", body["error"]["code"]
  end

  def test_post_runs_with_invalid_mode
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "test" }] }],
      mode: "invalid"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 400, last_response.status
  end

  # Async mode tests
  def test_post_runs_async_returns_immediately
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Charlie" }] }],
      mode: "async"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_includes body.keys, "run_id"
    # Status might be created or in-progress depending on timing
    assert_includes ["created", "in-progress", "completed"], body["status"]
  end

  # Stream mode tests
  def test_post_runs_stream_returns_sse_headers
    post "/runs", {
      agent_name: "echo",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "test" }] }],
      mode: "stream"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    assert_equal "text/event-stream", last_response.content_type
    assert_equal "no-cache", last_response.headers["Cache-Control"]
  end

  # Get run status tests
  def test_get_run_returns_run_details
    # First create a run
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Now get the run
    get "/runs/#{run_id}"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal run_id, body["run_id"]
    assert_equal "greeter", body["agent_name"]
    assert_equal "completed", body["status"]
  end

  def test_get_run_not_found
    get "/runs/nonexistent-run-id"

    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal "not_found", body["error"]["code"]
  end

  # Cancel run tests
  def test_post_cancel_run
    # Create an async run
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "async"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Cancel it
    post "/runs/#{run_id}/cancel"

    # Should return the cancelled run
    body = JSON.parse(last_response.body)
    assert_includes body.keys, "run_id"
    assert_equal "cancelled", body["status"]
  end

  def test_post_cancel_run_not_found
    post "/runs/nonexistent/cancel"

    assert_equal 404, last_response.status
  end

  # Get run events tests
  def test_get_run_events
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

    assert_includes body.keys, "events"
    assert_kind_of Array, body["events"]
  end

  def test_get_run_events_with_pagination
    # Create a run first
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Get events with pagination
    get "/runs/#{run_id}/events", limit: 5, offset: 0

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_kind_of Array, body["events"]
  end

  # Session tests
  def test_get_session
    # Create a run with a session
    post "/runs", {
      agent_name: "greeter",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }],
      session_id: "test-session-123"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?

    # Get the session
    get "/session/test-session-123"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal "test-session-123", body["id"]
  end

  def test_get_session_not_found
    get "/session/nonexistent-session"

    assert_equal 404, last_response.status
    body = JSON.parse(last_response.body)

    assert_equal "not_found", body["error"]["code"]
  end

  # Echo agent specific tests
  def test_echo_agent_echoes_multiple_inputs
    post "/runs", {
      agent_name: "echo",
      input: [
        { role: "user", parts: [{ content_type: "text/plain", content: "First" }] },
        { role: "user", parts: [{ content_type: "text/plain", content: "Second" }] }
      ],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal 2, body["output"].length
    assert_equal "First", body["output"][0]["parts"][0]["content"]
    assert_equal "Second", body["output"][1]["parts"][0]["content"]
  end

  # Content type tests
  def test_all_responses_are_json
    endpoints = [
      [:get, "/ping"],
      [:get, "/agents"],
      [:get, "/agents/echo"]
    ]

    endpoints.each do |method, path|
      send(method, path)
      assert_equal "application/json", last_response.content_type,
        "#{method.upcase} #{path} should return JSON"
    end
  end
end

class ServerAppAwaitResumeTest < SimpleAcpTestCase
  include Rack::Test::Methods

  def app
    @server ||= create_awaiting_server
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

  def create_awaiting_server
    server = SimpleAcp::Server::Base.new

    server.agent("questioner", description: "Asks questions") do |context|
      if context.resume_message
        # Being resumed - return the response
        name = context.resume_message.text_content
        SimpleAcp::Models::Message.agent("Hello, #{name}!")
      else
        # Initial call - need to yield an await through an Enumerator
        Enumerator.new do |yielder|
          yielder << context.await_message(
            SimpleAcp::Models::Message.agent("What is your name?")
          )
        end
      end
    end

    server
  end

  def test_await_and_resume_workflow
    # Start a run that will await
    post "/runs", {
      agent_name: "questioner",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "start" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal "awaiting", body["status"]
    run_id = body["run_id"]

    # Resume with a response
    post "/runs/#{run_id}", {
      await_resume: {
        type: "message",
        message: {
          role: "user",
          parts: [{ content_type: "text/plain", content: "Alice" }]
        }
      },
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert last_response.ok?
    body = JSON.parse(last_response.body)

    assert_equal "completed", body["status"]
    assert_match(/Hello, Alice!/, body["output"].last["parts"].first["content"])
  end

  def test_resume_not_awaiting_run_fails
    # Create and complete a normal run
    post "/runs", {
      agent_name: "questioner",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "start" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Complete it first
    post "/runs/#{run_id}", {
      await_resume: {
        type: "message",
        message: { role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }
      },
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    # Try to resume again (should fail since run is now completed)
    post "/runs/#{run_id}", {
      await_resume: {
        type: "message",
        message: { role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }
      },
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    # Should return an error since run is not awaiting
    assert_equal 500, last_response.status
  end

  def test_resume_nonexistent_run
    # Use a valid UUID format that doesn't exist
    fake_run_id = "00000000-0000-0000-0000-000000000000"
    post "/runs/#{fake_run_id}", {
      await_resume: {
        type: "message",
        message: { role: "user", parts: [{ content_type: "text/plain", content: "Test" }] }
      },
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 404, last_response.status
  end

  def test_resume_with_invalid_request
    # Start a run that will await
    post "/runs", {
      agent_name: "questioner",
      input: [{ role: "user", parts: [{ content_type: "text/plain", content: "start" }] }],
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    run_id = JSON.parse(last_response.body)["run_id"]

    # Resume with invalid request (missing await_resume)
    post "/runs/#{run_id}", {
      mode: "sync"
    }.to_json, "CONTENT_TYPE" => "application/json"

    assert_equal 400, last_response.status
  end
end
