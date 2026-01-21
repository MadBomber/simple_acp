# frozen_string_literal: true

require "test_helper"

class AwaitRequestTest < SimpleAcpTestCase
  # AwaitRequest base class tests
  def test_await_request_has_type_attribute
    request = SimpleAcp::Models::AwaitRequest.new(type: "custom")
    assert_equal "custom", request.type
  end

  def test_await_request_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::AwaitRequest.from_hash(nil)
  end

  def test_await_request_from_hash_dispatches_to_message_await_request
    hash = { "type" => "message", "message" => { "role" => "agent", "parts" => [] } }
    request = SimpleAcp::Models::AwaitRequest.from_hash(hash)

    assert_instance_of SimpleAcp::Models::MessageAwaitRequest, request
  end

  def test_await_request_from_hash_handles_unknown_type
    hash = { "type" => "unknown" }
    request = SimpleAcp::Models::AwaitRequest.from_hash(hash)

    assert_instance_of SimpleAcp::Models::AwaitRequest, request
    assert_equal "unknown", request.type
  end

  def test_await_request_to_h_serializes_type
    request = SimpleAcp::Models::AwaitRequest.new(type: "custom")
    hash = request.to_h

    assert_equal "custom", hash[:type]
  end
end

class MessageAwaitRequestTest < SimpleAcpTestCase
  def test_initialize_sets_type_to_message
    request = SimpleAcp::Models::MessageAwaitRequest.new
    assert_equal "message", request.type
  end

  def test_initialize_with_prompt_message
    prompt = SimpleAcp::Models::Message.agent("What is your name?")
    request = SimpleAcp::Models::MessageAwaitRequest.new(message: prompt)

    assert_equal "message", request.type
    assert_equal prompt, request.message
  end

  def test_from_hash_with_string_keys
    hash = {
      "type" => "message",
      "message" => {
        "role" => "agent",
        "parts" => [{ "content_type" => "text/plain", "content" => "Enter name:" }]
      }
    }

    request = SimpleAcp::Models::MessageAwaitRequest.from_hash(hash)

    assert_equal "message", request.type
    assert_instance_of SimpleAcp::Models::Message, request.message
    assert_equal "Enter name:", request.message.text_content
  end

  def test_from_hash_with_symbol_keys
    hash = {
      type: "message",
      message: {
        role: "agent",
        parts: [{ content_type: "text/plain", content: "Enter name:" }]
      }
    }

    request = SimpleAcp::Models::MessageAwaitRequest.from_hash(hash)

    assert_equal "message", request.type
    assert_instance_of SimpleAcp::Models::Message, request.message
  end

  def test_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::MessageAwaitRequest.from_hash(nil)
  end

  def test_from_hash_without_message
    hash = { "type" => "message" }
    request = SimpleAcp::Models::MessageAwaitRequest.from_hash(hash)

    assert_equal "message", request.type
    assert_nil request.message
  end

  def test_to_h_serializes_properly
    prompt = SimpleAcp::Models::Message.agent("What is your name?")
    request = SimpleAcp::Models::MessageAwaitRequest.new(message: prompt)
    hash = request.to_h

    assert_equal "message", hash[:type]
    assert_kind_of Hash, hash[:message]
    assert_equal "agent", hash[:message][:role]
  end

  def test_round_trip_serialization
    prompt = SimpleAcp::Models::Message.agent("Enter value:")
    original = SimpleAcp::Models::MessageAwaitRequest.new(message: prompt)

    hash = original.to_h
    restored = SimpleAcp::Models::MessageAwaitRequest.from_hash(hash)

    assert_equal original.type, restored.type
    assert_equal original.message.text_content, restored.message.text_content
  end
end

class AwaitResumeTest < SimpleAcpTestCase
  # AwaitResume base class tests
  def test_await_resume_has_type_attribute
    resume = SimpleAcp::Models::AwaitResume.new(type: "custom")
    assert_equal "custom", resume.type
  end

  def test_await_resume_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::AwaitResume.from_hash(nil)
  end

  def test_await_resume_from_hash_dispatches_to_message_await_resume
    hash = { "type" => "message", "message" => { "role" => "user", "parts" => [] } }
    resume = SimpleAcp::Models::AwaitResume.from_hash(hash)

    assert_instance_of SimpleAcp::Models::MessageAwaitResume, resume
  end

  def test_await_resume_from_hash_handles_unknown_type
    hash = { "type" => "unknown" }
    resume = SimpleAcp::Models::AwaitResume.from_hash(hash)

    assert_instance_of SimpleAcp::Models::AwaitResume, resume
    assert_equal "unknown", resume.type
  end

  def test_await_resume_to_h_serializes_type
    resume = SimpleAcp::Models::AwaitResume.new(type: "custom")
    hash = resume.to_h

    assert_equal "custom", hash[:type]
  end
end

class MessageAwaitResumeTest < SimpleAcpTestCase
  def test_initialize_sets_type_to_message
    resume = SimpleAcp::Models::MessageAwaitResume.new
    assert_equal "message", resume.type
  end

  def test_initialize_with_response_message
    response = SimpleAcp::Models::Message.user("My name is Alice")
    resume = SimpleAcp::Models::MessageAwaitResume.new(message: response)

    assert_equal "message", resume.type
    assert_equal response, resume.message
  end

  def test_from_hash_with_string_keys
    hash = {
      "type" => "message",
      "message" => {
        "role" => "user",
        "parts" => [{ "content_type" => "text/plain", "content" => "Alice" }]
      }
    }

    resume = SimpleAcp::Models::MessageAwaitResume.from_hash(hash)

    assert_equal "message", resume.type
    assert_instance_of SimpleAcp::Models::Message, resume.message
    assert_equal "Alice", resume.message.text_content
  end

  def test_from_hash_with_symbol_keys
    hash = {
      type: "message",
      message: {
        role: "user",
        parts: [{ content_type: "text/plain", content: "Bob" }]
      }
    }

    resume = SimpleAcp::Models::MessageAwaitResume.from_hash(hash)

    assert_equal "message", resume.type
    assert_instance_of SimpleAcp::Models::Message, resume.message
    assert_equal "Bob", resume.message.text_content
  end

  def test_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::MessageAwaitResume.from_hash(nil)
  end

  def test_from_hash_without_message
    hash = { "type" => "message" }
    resume = SimpleAcp::Models::MessageAwaitResume.from_hash(hash)

    assert_equal "message", resume.type
    assert_nil resume.message
  end

  def test_to_h_serializes_properly
    response = SimpleAcp::Models::Message.user("My answer")
    resume = SimpleAcp::Models::MessageAwaitResume.new(message: response)
    hash = resume.to_h

    assert_equal "message", hash[:type]
    assert_kind_of Hash, hash[:message]
    assert_equal "user", hash[:message][:role]
  end

  def test_round_trip_serialization
    response = SimpleAcp::Models::Message.user("Test response")
    original = SimpleAcp::Models::MessageAwaitResume.new(message: response)

    hash = original.to_h
    restored = SimpleAcp::Models::MessageAwaitResume.from_hash(hash)

    assert_equal original.type, restored.type
    assert_equal original.message.text_content, restored.message.text_content
  end
end

class AwaitRequestResumeIntegrationTest < SimpleAcpTestCase
  def test_request_and_resume_workflow
    # Simulate a complete await/resume workflow

    # 1. Agent creates an await request with a prompt
    prompt = SimpleAcp::Models::Message.agent("What is your favorite color?")
    request = SimpleAcp::Models::MessageAwaitRequest.new(message: prompt)

    # 2. Serialize for transmission
    request_json = request.to_json
    parsed_request = JSON.parse(request_json)

    # 3. Deserialize on the other side
    received_request = SimpleAcp::Models::AwaitRequest.from_hash(parsed_request)
    assert_instance_of SimpleAcp::Models::MessageAwaitRequest, received_request
    assert_equal "What is your favorite color?", received_request.message.text_content

    # 4. Client creates a resume with their response
    response = SimpleAcp::Models::Message.user("Blue")
    resume = SimpleAcp::Models::MessageAwaitResume.new(message: response)

    # 5. Serialize resume for transmission
    resume_json = resume.to_json
    parsed_resume = JSON.parse(resume_json)

    # 6. Deserialize on the server
    received_resume = SimpleAcp::Models::AwaitResume.from_hash(parsed_resume)
    assert_instance_of SimpleAcp::Models::MessageAwaitResume, received_resume
    assert_equal "Blue", received_resume.message.text_content
  end
end
