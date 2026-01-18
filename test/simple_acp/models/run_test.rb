# frozen_string_literal: true

require "test_helper"

class RunTest < SimpleAcpTestCase
  def test_initialize_generates_uuid_for_run_id
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")

    assert_match(/\A[0-9a-f-]{36}\z/, run.run_id)
  end

  def test_initialize_sets_default_status_to_created
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")

    assert_equal SimpleAcp::Models::Types::RunStatus::CREATED, run.status
  end

  def test_start_transitions_to_in_progress
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")

    run.start!

    assert run.in_progress?
  end

  def test_complete_transitions_to_completed
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!

    run.complete!([])

    assert run.completed?
    assert run.terminal?
  end

  def test_fail_sets_error_and_transitions_to_failed
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!

    run.fail!("Something went wrong")

    assert run.failed?
    assert run.terminal?
    assert_equal "Something went wrong", run.error.message
  end

  def test_cancel_transitions_to_cancelling
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!

    run.cancel!

    assert run.cancelling?
  end

  def test_cancelled_transitions_to_cancelled
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    run.cancel!

    run.cancelled!

    assert run.cancelled?
    assert run.terminal?
  end

  def test_await_transitions_to_awaiting
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.start!
    request = SimpleAcp::Models::MessageAwaitRequest.new(
      message: SimpleAcp::Models::Message.agent("Need more info")
    )

    run.await!(request)

    assert run.awaiting?
    assert_equal request, run.await_request
  end

  def test_to_h_serializes_to_hash
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    hash = run.to_h

    assert_equal run.run_id, hash[:run_id]
    assert_equal "test-agent", hash[:agent_name]
    assert_equal "created", hash[:status]
  end

  def test_from_hash_deserializes_from_hash
    hash = {
      "run_id" => "abc-123",
      "agent_name" => "test-agent",
      "status" => "completed",
      "output" => [
        { "role" => "agent", "parts" => [{ "content_type" => "text/plain", "content" => "Done" }] }
      ]
    }

    run = SimpleAcp::Models::Run.from_hash(hash)

    assert_equal "abc-123", run.run_id
    assert_equal "test-agent", run.agent_name
    assert run.completed?
    assert_equal 1, run.output.length
  end

  def test_raise_for_status_returns_self_when_not_failed
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    assert_equal run, run.raise_for_status!
  end

  def test_raise_for_status_raises_when_failed
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    run.fail!("Error occurred")

    assert_raises(SimpleAcp::RunError) { run.raise_for_status! }
  end

  def test_add_output_adds_message
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    message = SimpleAcp::Models::Message.agent("Response")

    run.add_output(message)

    assert_equal 1, run.output.length
    assert_equal message, run.output.first
  end

  def test_valid_returns_true_for_valid_run
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    assert run.valid?
  end

  def test_valid_returns_false_for_invalid_agent_name
    run = SimpleAcp::Models::Run.new(agent_name: "Invalid Agent Name")
    refute run.valid?
  end
end
