# frozen_string_literal: true

require "test_helper"

class MessagePartTest < SimpleAcpTestCase
  def test_text_creates_text_part
    part = SimpleAcp::Models::MessagePart.text("Hello")

    assert_equal "text/plain", part.content_type
    assert_equal "Hello", part.content
    assert part.text?
  end

  def test_json_creates_json_part
    part = SimpleAcp::Models::MessagePart.json({ key: "value" })

    assert_equal "application/json", part.content_type
    assert part.json?
  end

  def test_image_creates_image_part_with_base64
    part = SimpleAcp::Models::MessagePart.image("base64data", mime_type: "image/png")

    assert_equal "image/png", part.content_type
    assert_equal "base64data", part.content
    assert_equal SimpleAcp::Models::Types::ContentEncoding::BASE64, part.content_encoding
    assert part.image?
    assert part.base64_encoded?
  end

  def test_from_url_creates_url_reference
    part = SimpleAcp::Models::MessagePart.from_url(
      "https://example.com/image.png",
      content_type: "image/png"
    )

    assert_equal "https://example.com/image.png", part.content_url
    assert part.url_reference?
    assert_nil part.content
  end

  def test_valid_returns_false_without_content_type
    part = SimpleAcp::Models::MessagePart.new(content: "test")
    refute part.valid?
  end

  def test_valid_returns_false_with_both_content_and_content_url
    assert_raises(SimpleAcp::ValidationError) do
      SimpleAcp::Models::MessagePart.new(
        content_type: "text/plain",
        content: "test",
        content_url: "https://example.com"
      )
    end
  end

  def test_valid_returns_true_for_valid_part
    part = SimpleAcp::Models::MessagePart.text("Hello")
    assert part.valid?
  end

  def test_to_h_serializes_correctly
    part = SimpleAcp::Models::MessagePart.text("Hello")
    hash = part.to_h

    assert_equal "text/plain", hash[:content_type]
    assert_equal "Hello", hash[:content]
  end

  def test_from_hash_deserializes_correctly
    hash = {
      "content_type" => "text/plain",
      "content" => "Hello"
    }

    part = SimpleAcp::Models::MessagePart.from_hash(hash)

    assert_equal "text/plain", part.content_type
    assert_equal "Hello", part.content
  end

  def test_parsed_json_returns_parsed_data
    part = SimpleAcp::Models::MessagePart.json({ key: "value" })

    assert_equal({ "key" => "value" }, part.parsed_json)
  end

  def test_to_s_returns_content_for_text
    part = SimpleAcp::Models::MessagePart.text("Hello")
    assert_equal "Hello", part.to_s
  end

  def test_to_s_returns_content_url_for_url_reference
    part = SimpleAcp::Models::MessagePart.from_url(
      "https://example.com/image.png",
      content_type: "image/png"
    )
    assert_equal "https://example.com/image.png", part.to_s
  end
end
