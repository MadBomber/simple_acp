# frozen_string_literal: true

require "test_helper"

class ServerContextTest < SimpleAcpTestCase
  def setup
    @run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    @session = SimpleAcp::Models::Session.create
    @input = [SimpleAcp::Models::Message.user("Hello")]
    @server = SimpleAcp::Server::Base.new
  end

  def test_context_provides_agent_name
    context = create_context

    assert_equal "test-agent", context.agent_name
  end

  def test_context_provides_run_id
    context = create_context

    assert_equal @run.run_id, context.run_id
  end

  def test_context_provides_session_id
    context = create_context

    assert_equal @session.id, context.session_id
  end

  def test_context_provides_input
    context = create_context

    assert_equal @input, context.input
  end

  def test_context_provides_history_from_session
    @session.add_to_history(SimpleAcp::Models::Message.user("Previous"))
    context = create_context

    assert_equal 1, context.history.length
  end

  def test_context_provides_state_from_session
    @session.set_state({ count: 5 })
    context = create_context

    assert_equal({ count: 5 }, context.state)
  end

  def test_cancelled_is_false_by_default
    context = create_context

    refute context.cancelled?
  end

  def test_cancel_sets_cancelled_to_true
    context = create_context
    context.cancel!

    assert context.cancelled?
  end

  def test_set_state_updates_session_state
    context = create_context
    @server.storage.save_session(@session)

    context.set_state({ new_count: 10 })

    updated_session = @server.storage.get_session(@session.id)
    assert_equal({ new_count: 10 }, updated_session.state)
  end

  def test_history_returns_empty_array_when_no_session
    context = SimpleAcp::Server::Context.new(
      run: @run,
      session: nil,
      input: @input,
      server: @server
    )

    assert_equal [], context.history
  end

  def test_state_returns_nil_when_no_session
    context = SimpleAcp::Server::Context.new(
      run: @run,
      session: nil,
      input: @input,
      server: @server
    )

    assert_nil context.state
  end

  private

  def create_context
    SimpleAcp::Server::Context.new(
      run: @run,
      session: @session,
      input: @input,
      server: @server
    )
  end
end
