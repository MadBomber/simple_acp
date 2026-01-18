# frozen_string_literal: true

require "test_helper"

class EventsTest < SimpleAcpTestCase
  def test_run_created_event_has_correct_type
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    event = SimpleAcp::Models::RunCreatedEvent.new(run: run)

    assert_equal "run.created", event.type
    assert_equal run, event.run
  end

  def test_run_in_progress_event_has_correct_type
    event = SimpleAcp::Models::RunInProgressEvent.new(run_id: "run-123")

    assert_equal "run.in-progress", event.type
    assert_equal "run-123", event.run_id
  end

  def test_run_completed_event_has_correct_type
    run = SimpleAcp::Models::Run.new(agent_name: "test-agent")
    event = SimpleAcp::Models::RunCompletedEvent.new(run: run)

    assert_equal "run.completed", event.type
  end

  def test_run_failed_event_has_correct_type
    error = SimpleAcp::Models::Error.server_error("Something went wrong")
    event = SimpleAcp::Models::RunFailedEvent.new(run_id: "run-123", error: error)

    assert_equal "run.failed", event.type
    assert_equal error, event.error
  end

  def test_message_created_event_has_correct_type
    message = SimpleAcp::Models::Message.agent("Hello")
    event = SimpleAcp::Models::MessageCreatedEvent.new(message: message)

    assert_equal "message.created", event.type
    assert_equal message, event.message
  end

  def test_message_part_event_has_correct_type
    part = SimpleAcp::Models::MessagePart.text("Hello")
    event = SimpleAcp::Models::MessagePartEvent.new(part: part)

    assert_equal "message.part", event.type
    assert_equal part, event.part
  end

  def test_generic_event_has_correct_type
    event = SimpleAcp::Models::GenericEvent.new(data: { key: "value" })

    assert_equal "generic", event.type
    assert_equal({ key: "value" }, event.data)
  end

  def test_error_event_has_correct_type
    error = SimpleAcp::Models::Error.server_error("Error")
    event = SimpleAcp::Models::ErrorEvent.new(error: error)

    assert_equal "error", event.type
  end

  def test_sse_format_returns_valid_sse
    event = SimpleAcp::Models::GenericEvent.new(data: { key: "value" })
    sse = event.sse_format

    assert_includes sse, "event: generic"
    assert_includes sse, "data:"
    assert sse.end_with?("\n\n")
  end

  def test_events_from_hash_creates_correct_event_type
    hash = {
      "type" => "run.created",
      "run" => { "run_id" => "123", "agent_name" => "test", "status" => "created" }
    }

    event = SimpleAcp::Models::Events.from_hash(hash)

    assert_instance_of SimpleAcp::Models::RunCreatedEvent, event
    assert_equal "run.created", event.type
  end

  def test_events_from_hash_falls_back_to_generic
    hash = {
      "type" => "unknown.type",
      "data" => { "foo" => "bar" }
    }

    event = SimpleAcp::Models::Events.from_hash(hash)

    assert_instance_of SimpleAcp::Models::GenericEvent, event
  end
end
