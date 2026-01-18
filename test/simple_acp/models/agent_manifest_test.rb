# frozen_string_literal: true

require "test_helper"

class AgentManifestTest < SimpleAcpTestCase
  def test_initialize_with_defaults
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")

    assert_equal "test-agent", manifest.name
    assert_equal ["text/plain"], manifest.input_content_types
    assert_equal ["text/plain"], manifest.output_content_types
  end

  def test_accepts_content_type_for_matching_type
    manifest = SimpleAcp::Models::AgentManifest.new(
      name: "test-agent",
      input_content_types: ["text/plain", "application/json"]
    )

    assert manifest.accepts_content_type?("text/plain")
    assert manifest.accepts_content_type?("application/json")
    refute manifest.accepts_content_type?("image/png")
  end

  def test_accepts_content_type_with_wildcard
    manifest = SimpleAcp::Models::AgentManifest.new(
      name: "test-agent",
      input_content_types: ["text/*"]
    )

    assert manifest.accepts_content_type?("text/plain")
    assert manifest.accepts_content_type?("text/html")
    refute manifest.accepts_content_type?("application/json")
  end

  def test_valid_returns_true_for_valid_manifest
    manifest = SimpleAcp::Models::AgentManifest.new(name: "test-agent")
    assert manifest.valid?
  end

  def test_valid_returns_false_for_invalid_name
    manifest = SimpleAcp::Models::AgentManifest.new(name: "Invalid Agent")
    refute manifest.valid?
  end

  def test_to_h_serializes_correctly
    manifest = SimpleAcp::Models::AgentManifest.new(
      name: "test-agent",
      description: "A test agent"
    )
    hash = manifest.to_h

    assert_equal "test-agent", hash[:name]
    assert_equal "A test agent", hash[:description]
  end

  def test_from_hash_deserializes_correctly
    hash = {
      "name" => "test-agent",
      "description" => "A test agent",
      "input_content_types" => ["text/plain", "application/json"]
    }

    manifest = SimpleAcp::Models::AgentManifest.from_hash(hash)

    assert_equal "test-agent", manifest.name
    assert_equal "A test agent", manifest.description
    assert_equal ["text/plain", "application/json"], manifest.input_content_types
  end
end
