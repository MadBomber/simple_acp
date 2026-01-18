# frozen_string_literal: true

require "test_helper"

class TypesTest < SimpleAcpTestCase
  def test_valid_agent_name_for_valid_names
    assert SimpleAcp::Models::Types.valid_agent_name?("test-agent")
    assert SimpleAcp::Models::Types.valid_agent_name?("a")
    assert SimpleAcp::Models::Types.valid_agent_name?("my-agent-123")
    assert SimpleAcp::Models::Types.valid_agent_name?("agent1")
  end

  def test_valid_agent_name_for_invalid_names
    refute SimpleAcp::Models::Types.valid_agent_name?(nil)
    refute SimpleAcp::Models::Types.valid_agent_name?("")
    refute SimpleAcp::Models::Types.valid_agent_name?("Invalid Agent")
    refute SimpleAcp::Models::Types.valid_agent_name?("-invalid")
    refute SimpleAcp::Models::Types.valid_agent_name?("invalid-")
    refute SimpleAcp::Models::Types.valid_agent_name?("UPPERCASE")
    refute SimpleAcp::Models::Types.valid_agent_name?("a" * 64) # Too long
  end

  def test_valid_uuid_for_valid_uuids
    assert SimpleAcp::Models::Types.valid_uuid?("123e4567-e89b-12d3-a456-426614174000")
    assert SimpleAcp::Models::Types.valid_uuid?("550e8400-e29b-41d4-a716-446655440000")
  end

  def test_valid_uuid_for_invalid_uuids
    refute SimpleAcp::Models::Types.valid_uuid?(nil)
    refute SimpleAcp::Models::Types.valid_uuid?("not-a-uuid")
    refute SimpleAcp::Models::Types.valid_uuid?("123")
  end

  def test_generate_uuid_returns_valid_uuid
    uuid = SimpleAcp::Models::Types.generate_uuid

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/, uuid)
  end

  def test_run_mode_valid
    assert SimpleAcp::Models::Types::RunMode.valid?("sync")
    assert SimpleAcp::Models::Types::RunMode.valid?("async")
    assert SimpleAcp::Models::Types::RunMode.valid?("stream")
    refute SimpleAcp::Models::Types::RunMode.valid?("invalid")
  end

  def test_run_status_valid
    assert SimpleAcp::Models::Types::RunStatus.valid?("created")
    assert SimpleAcp::Models::Types::RunStatus.valid?("in-progress")
    assert SimpleAcp::Models::Types::RunStatus.valid?("completed")
    refute SimpleAcp::Models::Types::RunStatus.valid?("invalid")
  end

  def test_run_status_terminal
    assert SimpleAcp::Models::Types::RunStatus.terminal?("completed")
    assert SimpleAcp::Models::Types::RunStatus.terminal?("failed")
    assert SimpleAcp::Models::Types::RunStatus.terminal?("cancelled")
    refute SimpleAcp::Models::Types::RunStatus.terminal?("in-progress")
    refute SimpleAcp::Models::Types::RunStatus.terminal?("created")
  end

  def test_role_valid
    assert SimpleAcp::Models::Types::Role.valid?("user")
    assert SimpleAcp::Models::Types::Role.valid?("agent")
    assert SimpleAcp::Models::Types::Role.valid?("agent/my-agent")
    refute SimpleAcp::Models::Types::Role.valid?("invalid")
  end
end
