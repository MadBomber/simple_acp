# frozen_string_literal: true

require "test_helper"

class MessageTest < SimpleAcpTestCase
  def test_user_creates_message_with_string_content
    message = SimpleAcp::Models::Message.user("Hello")

    assert_equal SimpleAcp::Models::Types::Role::USER, message.role
    assert_equal 1, message.parts.length
    assert_equal "Hello", message.parts.first.content
  end

  def test_user_creates_message_with_multiple_parts
    message = SimpleAcp::Models::Message.user("Part 1", "Part 2")

    assert_equal 2, message.parts.length
    assert_equal ["Part 1", "Part 2"], message.parts.map(&:content)
  end

  def test_agent_creates_agent_message
    message = SimpleAcp::Models::Message.agent("Response")

    assert_equal SimpleAcp::Models::Types::Role::AGENT, message.role
    assert_equal "Response", message.parts.first.content
  end

  def test_text_content_returns_combined_text_from_all_parts
    message = SimpleAcp::Models::Message.user("Hello", "World")

    assert_equal "Hello\nWorld", message.text_content
  end

  def test_to_h_serializes_to_hash
    message = SimpleAcp::Models::Message.user("Test")
    hash = message.to_h

    assert_equal "user", hash[:role]
    assert_equal "Test", hash[:parts].first[:content]
  end

  def test_from_hash_deserializes_from_hash
    hash = {
      "role" => "agent",
      "parts" => [{ "content_type" => "text/plain", "content" => "Response" }]
    }

    message = SimpleAcp::Models::Message.from_hash(hash)

    assert_equal "agent", message.role
    assert_equal "Response", message.parts.first.content
  end

  def test_plus_combines_two_messages
    m1 = SimpleAcp::Models::Message.user("Hello")
    m2 = SimpleAcp::Models::Message.user("World")

    combined = m1 + m2

    assert_equal 2, combined.parts.length
    assert_equal "Hello\nWorld", combined.text_content
  end

  def test_compress_combines_adjacent_text_parts
    part1 = SimpleAcp::Models::MessagePart.text("Line 1")
    part2 = SimpleAcp::Models::MessagePart.text("Line 2")
    part3 = SimpleAcp::Models::MessagePart.json({ key: "value" })
    part4 = SimpleAcp::Models::MessagePart.text("Line 3")

    message = SimpleAcp::Models::Message.new(role: "user", parts: [part1, part2, part3, part4])
    compressed = message.compress

    assert_equal 3, compressed.parts.length
    assert compressed.parts[0].text?
    assert compressed.parts[1].json?
    assert compressed.parts[2].text?
  end

  def test_user_predicate_returns_true_for_user_messages
    message = SimpleAcp::Models::Message.user("Hello")
    assert message.user?
    refute message.agent?
  end

  def test_agent_predicate_returns_true_for_agent_messages
    message = SimpleAcp::Models::Message.agent("Response")
    assert message.agent?
    refute message.user?
  end

  def test_valid_returns_false_for_empty_parts
    message = SimpleAcp::Models::Message.new(role: "user", parts: [])
    refute message.valid?
  end

  def test_valid_returns_true_for_valid_message
    message = SimpleAcp::Models::Message.user("Hello")
    assert message.valid?
  end

  def test_complete_marks_message_as_completed
    message = SimpleAcp::Models::Message.user("Hello")
    refute message.completed?

    message.complete!

    assert message.completed?
    assert_instance_of Time, message.completed_at
  end

  def test_add_part_adds_message_part
    message = SimpleAcp::Models::Message.user("Hello")
    message.add_part(SimpleAcp::Models::MessagePart.text("World"))

    assert_equal 2, message.parts.length
    assert_equal "Hello\nWorld", message.text_content
  end
end
