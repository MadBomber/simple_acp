# frozen_string_literal: true

require "test_helper"

class ClientSseTest < SimpleAcpTestCase
  def test_sse_parser_parses_single_event
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed("event: test\ndata: {\"key\":\"value\"}\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal 1, events.length
    assert_equal "test", events.first[:event]
    assert_equal '{"key":"value"}', events.first[:data]
  end

  def test_sse_parser_parses_multiple_events
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed("event: one\ndata: first\n\nevent: two\ndata: second\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal 2, events.length
    assert_equal "one", events[0][:event]
    assert_equal "two", events[1][:event]
  end

  def test_sse_parser_handles_multiline_data
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed("event: test\ndata: line1\ndata: line2\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal "line1\nline2", events.first[:data]
  end

  def test_sse_parser_ignores_comments
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed(": this is a comment\nevent: test\ndata: value\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal 1, events.length
    assert_equal "test", events.first[:event]
  end

  def test_sse_parser_uses_message_as_default_event
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed("data: no event type\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal "message", events.first[:event]
  end

  def test_sse_parser_handles_chunked_input
    parser = SimpleAcp::Client::SSEParser.new

    # Feed data in chunks
    parser.feed("event: te")
    parser.feed("st\ndata: val")
    parser.feed("ue\n\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal 1, events.length
    assert_equal "test", events.first[:event]
    assert_equal "value", events.first[:data]
  end

  def test_sse_parser_handles_carriage_return
    parser = SimpleAcp::Client::SSEParser.new
    parser.feed("event: test\r\ndata: value\r\n\r\n")

    events = []
    parser.each_event { |e| events << e }

    assert_equal 1, events.length
  end
end
