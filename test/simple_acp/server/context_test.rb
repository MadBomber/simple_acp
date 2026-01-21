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

  def test_resume_message_returns_nil_for_base_context
    context = create_context

    assert_nil context.resume_message
  end

  def test_await_message_returns_run_yield_await
    context = create_context
    @server.storage.save_run(@run)

    prompt = SimpleAcp::Models::Message.agent("What is your name?")
    result = context.await_message(prompt)

    assert_instance_of SimpleAcp::Server::RunYieldAwait, result
    assert_instance_of SimpleAcp::Models::MessageAwaitRequest, result.request
    assert_equal prompt, result.request.message
  end

  def test_await_message_sets_run_to_awaiting
    context = create_context
    @server.storage.save_run(@run)

    prompt = SimpleAcp::Models::Message.agent("Enter input:")
    context.await_message(prompt)

    # The run should now be awaiting
    assert @run.awaiting?
  end

  def test_await_message_saves_run_to_storage
    context = create_context
    @server.storage.save_run(@run)

    prompt = SimpleAcp::Models::Message.agent("Enter value:")
    context.await_message(prompt)

    # Verify run was saved with awaiting status
    saved_run = @server.storage.get_run(@run.run_id)
    assert saved_run.awaiting?
  end

  def test_log_does_not_raise_without_logger
    # SimpleAcp.logger is nil by default
    context = create_context
    # Should not raise
    context.log("test message")
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

class RunYieldTest < SimpleAcpTestCase
  def test_initialize_with_message_object
    message = SimpleAcp::Models::Message.agent("Hello")
    run_yield = SimpleAcp::Server::RunYield.new(message)

    assert_equal message, run_yield.message
  end

  def test_initialize_with_hash
    hash = {
      role: "agent",
      parts: [{ content_type: "text/plain", content: "Hello" }]
    }
    run_yield = SimpleAcp::Server::RunYield.new(hash)

    assert_instance_of SimpleAcp::Models::Message, run_yield.message
    assert_equal "Hello", run_yield.message.text_content
  end
end

class RunYieldAwaitTest < SimpleAcpTestCase
  def test_initialize_with_request
    request = SimpleAcp::Models::MessageAwaitRequest.new(
      message: SimpleAcp::Models::Message.agent("What is your name?")
    )
    run_yield_await = SimpleAcp::Server::RunYieldAwait.new(request: request)

    assert_equal request, run_yield_await.request
  end
end

class ResumeContextTest < SimpleAcpTestCase
  def setup
    @run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    @session = SimpleAcp::Models::Session.create
    @input = [SimpleAcp::Models::Message.user("Hello")]
    @server = SimpleAcp::Server::Base.new

    @await_resume = SimpleAcp::Models::MessageAwaitResume.new(
      message: SimpleAcp::Models::Message.user("My response")
    )
  end

  def test_resume_context_inherits_from_context
    context = create_resume_context

    assert_kind_of SimpleAcp::Server::Context, context
  end

  def test_resume_context_provides_await_resume
    context = create_resume_context

    assert_equal @await_resume, context.await_resume
  end

  def test_resume_message_returns_message_from_await_resume
    context = create_resume_context

    assert_equal @await_resume.message, context.resume_message
    assert_equal "My response", context.resume_message.text_content
  end

  def test_resume_message_returns_nil_when_no_await_resume
    context = SimpleAcp::Server::ResumeContext.new(
      run: @run,
      session: @session,
      input: @input,
      server: @server,
      await_resume: nil
    )

    assert_nil context.resume_message
  end

  def test_resume_context_still_provides_base_context_methods
    context = create_resume_context

    assert_equal "test-agent", context.agent_name
    assert_equal @run.run_id, context.run_id
    assert_equal @session.id, context.session_id
    assert_equal @input, context.input
    refute context.cancelled?
  end

  private

  def create_resume_context
    SimpleAcp::Server::ResumeContext.new(
      run: @run,
      session: @session,
      input: @input,
      server: @server,
      await_resume: @await_resume
    )
  end
end
