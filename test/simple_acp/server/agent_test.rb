# frozen_string_literal: true

require "test_helper"

class ServerAgentTest < SimpleAcpTestCase
  def test_agent_has_name_from_manifest
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent", description: "Test")
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: ->(_) { "response" })

    assert_equal "test-agent", agent.name
  end

  def test_agent_has_description_from_manifest
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent", description: "Test description")
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: ->(_) { "response" })

    assert_equal "Test description", agent.description
  end

  def test_valid_returns_true_for_valid_agent
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: ->(_) { "response" })

    assert agent.valid?
  end

  def test_valid_returns_false_for_invalid_manifest
    manifest = SimpleAcp::Models::AgentManifest.new(name: "Invalid Name")
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: ->(_) { "response" })

    refute agent.valid?
  end

  def test_valid_returns_false_for_non_callable_handler
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: "not callable")

    refute agent.valid?
  end

  def test_call_wraps_message_return_in_run_yield
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    handler = ->(_context) { SimpleAcp::Models::Message.agent("Response") }
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: handler)

    context = mock_context
    result = agent.call(context)

    assert_equal 1, result.length
    assert_instance_of SimpleAcp::Server::RunYield, result.first
  end

  def test_call_wraps_string_return_in_run_yield
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    handler = ->(_context) { "String response" }
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: handler)

    context = mock_context
    result = agent.call(context)

    assert_equal 1, result.length
    assert_instance_of SimpleAcp::Server::RunYield, result.first
  end

  def test_call_passes_through_enumerator
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    handler = ->(_context) do
      Enumerator.new { |y| y << SimpleAcp::Server::RunYield.new(SimpleAcp::Models::Message.agent("Test")) }
    end
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: handler)

    context = mock_context
    result = agent.call(context)

    assert_instance_of Enumerator, result
  end

  def test_call_handles_array_of_run_yields
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    handler = ->(_context) do
      [
        SimpleAcp::Server::RunYield.new(SimpleAcp::Models::Message.agent("One")),
        SimpleAcp::Server::RunYield.new(SimpleAcp::Models::Message.agent("Two"))
      ]
    end
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: handler)

    context = mock_context
    result = agent.call(context)

    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(SimpleAcp::Server::RunYield) }
  end

  def test_call_handles_array_of_messages
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    handler = ->(_context) do
      [
        SimpleAcp::Models::Message.agent("One"),
        SimpleAcp::Models::Message.agent("Two")
      ]
    end
    agent = SimpleAcp::Server::Agent.new(manifest: manifest, handler: handler)

    context = mock_context
    result = agent.call(context)

    assert_equal 2, result.length
    assert result.all? { |r| r.is_a?(SimpleAcp::Server::RunYield) }
  end

  private

  def mock_context
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    SimpleAcp::Server::Context.new(
      run: run,
      session: nil,
      input: [SimpleAcp::Models::Message.user("Test")],
      server: nil
    )
  end
end
