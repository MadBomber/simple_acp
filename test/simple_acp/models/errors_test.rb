# frozen_string_literal: true

require "test_helper"

class ErrorsTest < SimpleAcpTestCase
  def test_server_error_creates_error_with_correct_code
    error = SimpleAcp::Models::Error.server_error("Something went wrong")

    assert_equal SimpleAcp::Models::ErrorCode::SERVER_ERROR, error.code
    assert_equal "Something went wrong", error.message
  end

  def test_invalid_input_creates_error_with_correct_code
    error = SimpleAcp::Models::Error.invalid_input("Bad request")

    assert_equal SimpleAcp::Models::ErrorCode::INVALID_INPUT, error.code
    assert_equal "Bad request", error.message
  end

  def test_not_found_creates_error_with_correct_code
    error = SimpleAcp::Models::Error.not_found("Resource not found")

    assert_equal SimpleAcp::Models::ErrorCode::NOT_FOUND, error.code
    assert_equal "Resource not found", error.message
  end

  def test_error_with_data
    error = SimpleAcp::Models::Error.server_error("Error", data: { field: "value" })

    assert_equal({ field: "value" }, error.data)
  end

  def test_to_h_serializes_correctly
    error = SimpleAcp::Models::Error.server_error("Error", data: { field: "value" })
    hash = error.to_h

    assert_equal "server_error", hash[:code]
    assert_equal "Error", hash[:message]
    assert_equal({ field: "value" }, hash[:data])
  end

  def test_to_h_omits_nil_data
    error = SimpleAcp::Models::Error.server_error("Error")
    hash = error.to_h

    refute hash.key?(:data)
  end

  def test_from_hash_deserializes_correctly
    hash = {
      "code" => "not_found",
      "message" => "Not found",
      "data" => { "id" => 123 }
    }

    error = SimpleAcp::Models::Error.from_hash(hash)

    assert_equal "not_found", error.code
    assert_equal "Not found", error.message
    assert_equal({ "id" => 123 }, error.data)
  end

  def test_to_json_returns_valid_json
    error = SimpleAcp::Models::Error.server_error("Error")
    json = error.to_json

    parsed = JSON.parse(json)
    assert_equal "server_error", parsed["code"]
    assert_equal "Error", parsed["message"]
  end
end
