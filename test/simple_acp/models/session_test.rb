# frozen_string_literal: true

require "test_helper"

class SessionTest < SimpleAcpTestCase
  def test_create_generates_uuid
    session = SimpleAcp::Models::Session.create

    assert_match(/\A[0-9a-f-]{36}\z/, session.id)
  end

  def test_add_to_history_adds_message
    session = SimpleAcp::Models::Session.create
    message = SimpleAcp::Models::Message.user("Hello")

    session.add_to_history(message)

    assert_equal 1, session.history.length
    assert_equal message, session.history.first
  end

  def test_clear_history_removes_all_messages
    session = SimpleAcp::Models::Session.create
    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))
    session.add_to_history(SimpleAcp::Models::Message.agent("World"))

    session.clear_history!

    assert_empty session.history
  end

  def test_set_state_updates_state
    session = SimpleAcp::Models::Session.create

    session.set_state({ count: 5 })

    assert_equal({ count: 5 }, session.state)
  end

  def test_clear_state_removes_state
    session = SimpleAcp::Models::Session.create
    session.set_state({ count: 5 })

    session.clear_state!

    assert_nil session.state
  end

  def test_message_count_returns_history_length
    session = SimpleAcp::Models::Session.create
    session.add_to_history(SimpleAcp::Models::Message.user("1"))
    session.add_to_history(SimpleAcp::Models::Message.user("2"))
    session.add_to_history(SimpleAcp::Models::Message.user("3"))

    assert_equal 3, session.message_count
  end

  def test_empty_returns_true_for_new_session
    session = SimpleAcp::Models::Session.create
    assert session.empty?
  end

  def test_empty_returns_false_when_has_history
    session = SimpleAcp::Models::Session.create
    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))

    refute session.empty?
  end

  def test_empty_returns_false_when_has_state
    session = SimpleAcp::Models::Session.create
    session.set_state({ key: "value" })

    refute session.empty?
  end

  def test_valid_returns_true_for_valid_session
    session = SimpleAcp::Models::Session.create
    assert session.valid?
  end

  def test_to_h_serializes_correctly
    session = SimpleAcp::Models::Session.new(id: "test-session-id")
    session.add_to_history(SimpleAcp::Models::Message.user("Hello"))
    session.set_state({ count: 1 })

    hash = session.to_h

    assert_equal "test-session-id", hash[:id]
    assert_equal 1, hash[:history].length
    assert_equal({ count: 1 }, hash[:state])
  end

  def test_from_hash_deserializes_correctly
    hash = {
      "id" => "test-session-id",
      "history" => [
        { "role" => "user", "parts" => [{ "content_type" => "text/plain", "content" => "Hello" }] }
      ],
      "state" => { "count" => 5 }
    }

    session = SimpleAcp::Models::Session.from_hash(hash)

    assert_equal "test-session-id", session.id
    assert_equal 1, session.history.length
    assert_equal({ "count" => 5 }, session.state)
  end
end
