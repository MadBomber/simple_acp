# frozen_string_literal: true

require "test_helper"

class ServerBaseTest < SimpleAcpTestCase
  def setup
    @server = SimpleAcp::Server::Base.new
  end

  def test_agent_registers_agent_with_block
    @server.agent("my-agent", description: "Test agent") do |_context|
      SimpleAcp::Models::Message.agent("Response")
    end

    assert @server.agents.key?("my-agent")
    assert_equal "Test agent", @server.agents["my-agent"].description
  end

  def test_agent_validates_agent_names
    assert_raises(SimpleAcp::ValidationError) do
      @server.agent("Invalid Agent Name") { |_| }
    end
  end

  def test_agent_prevents_duplicate_registration
    @server.agent("unique-agent") { |_| }

    assert_raises(SimpleAcp::ConfigurationError) do
      @server.agent("unique-agent") { |_| }
    end
  end

  def test_unregister_removes_agent
    @server.agent("temp-agent") { |_| }
    assert @server.agents.key?("temp-agent")

    @server.unregister("temp-agent")

    refute @server.agents.key?("temp-agent")
  end

  def test_run_sync_executes_agent_synchronously
    @server.agent("echo") do |context|
      Enumerator.new do |yielder|
        context.input.each do |msg|
          yielder << SimpleAcp::Server::RunYield.new(
            SimpleAcp::Models::Message.agent(msg.text_content)
          )
        end
      end
    end

    input = [SimpleAcp::Models::Message.user("Hello")]
    run = @server.run_sync(agent_name: "echo", input: input)

    assert run.completed?
    assert_equal 1, run.output.length
    assert_equal "Hello", run.output.first.text_content
  end

  def test_run_sync_raises_not_found_for_unknown_agents
    assert_raises(SimpleAcp::NotFoundError) do
      @server.run_sync(agent_name: "unknown", input: [])
    end
  end

  def test_run_sync_handles_agent_errors_gracefully
    @server.agent("failing-agent") do |_context|
      raise "Something went wrong"
    end

    run = @server.run_sync(
      agent_name: "failing-agent",
      input: [SimpleAcp::Models::Message.user("Test")]
    )

    assert run.failed?
    assert_equal "Something went wrong", run.error.message
  end

  def test_run_stream_yields_events_during_execution
    @server.agent("streamer") do |_context|
      Enumerator.new do |yielder|
        3.times do |i|
          yielder << SimpleAcp::Server::RunYield.new(
            SimpleAcp::Models::Message.agent("Message #{i + 1}")
          )
        end
      end
    end

    events = []
    @server.run_stream(
      agent_name: "streamer",
      input: [SimpleAcp::Models::Message.user("Start")]
    ) do |event|
      events << event
    end

    event_types = events.map(&:type)

    assert_includes event_types, "run.created"
    assert_includes event_types, "run.in-progress"
    assert_includes event_types, "message.created"
    assert_includes event_types, "run.completed"
  end

  def test_run_stream_handles_errors
    @server.agent("failing-streamer") do |_context|
      raise "Stream error"
    end

    events = []
    @server.run_stream(
      agent_name: "failing-streamer",
      input: [SimpleAcp::Models::Message.user("Start")]
    ) do |event|
      events << event
    end

    event_types = events.map(&:type)
    assert_includes event_types, "run.failed"
  end

  def test_session_management_maintains_state_across_runs
    @server.agent("stateful") do |context|
      count = (context.state || 0) + 1
      context.set_state(count)

      [SimpleAcp::Server::RunYield.new(
        SimpleAcp::Models::Message.agent("Count: #{count}")
      )]
    end

    session = SimpleAcp::Models::Session.create
    @server.storage.save_session(session)

    run1 = @server.run_sync(
      agent_name: "stateful",
      input: [SimpleAcp::Models::Message.user("Increment")],
      session_id: session.id
    )
    assert_equal "Count: 1", run1.output.first.text_content

    run2 = @server.run_sync(
      agent_name: "stateful",
      input: [SimpleAcp::Models::Message.user("Increment")],
      session_id: session.id
    )
    assert_equal "Count: 2", run2.output.first.text_content
  end

  def test_agent_can_return_single_message
    @server.agent("simple") do |_context|
      SimpleAcp::Models::Message.agent("Simple response")
    end

    run = @server.run_sync(
      agent_name: "simple",
      input: [SimpleAcp::Models::Message.user("Test")]
    )

    assert run.completed?
    assert_equal "Simple response", run.output.first.text_content
  end

  def test_agent_can_return_string
    @server.agent("string-agent") do |_context|
      "String response"
    end

    run = @server.run_sync(
      agent_name: "string-agent",
      input: [SimpleAcp::Models::Message.user("Test")]
    )

    assert run.completed?
    assert_equal "String response", run.output.first.text_content
  end

  def test_cancel_run_cancels_running_agent
    started = Concurrent::Event.new

    @server.agent("cancellable") do |context|
      Enumerator.new do |yielder|
        started.set # Signal that the agent has started
        loop do
          break if context.cancelled?

          yielder << SimpleAcp::Server::RunYield.new(
            SimpleAcp::Models::Message.agent("Working...")
          )
          sleep 0.01 # Small sleep to prevent tight loop
        end
      end
    end

    # Start async run
    run = @server.run_async(
      agent_name: "cancellable",
      input: [SimpleAcp::Models::Message.user("Start")]
    )

    # Wait for agent to start before cancelling
    started.wait(1.0)

    # Cancel it
    @server.cancel_run(run.run_id)

    # Give it time to process cancellation
    sleep 0.1

    cancelled_run = @server.storage.get_run(run.run_id)
    assert cancelled_run.cancelled?
  end

  def test_to_app_creates_rack_app
    app = @server.to_app

    assert app.respond_to?(:call)
  end
end
