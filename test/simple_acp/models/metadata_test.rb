# frozen_string_literal: true

require "test_helper"

class CitationMetadataTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    citation = SimpleAcp::Models::CitationMetadata.new(
      start_index: 0,
      end_index: 50,
      url: "https://example.com",
      title: "Example",
      description: "An example citation"
    )

    assert_equal "citation", citation.kind
    assert_equal 0, citation.start_index
    assert_equal 50, citation.end_index
    assert_equal "https://example.com", citation.url
    assert_equal "Example", citation.title
    assert_equal "An example citation", citation.description
  end

  def test_kind_defaults_to_citation
    citation = SimpleAcp::Models::CitationMetadata.new
    assert_equal "citation", citation.kind
  end

  def test_from_hash_with_correct_kind
    hash = {
      "kind" => "citation",
      "start_index" => 10,
      "end_index" => 20,
      "url" => "https://test.com"
    }

    citation = SimpleAcp::Models::CitationMetadata.from_hash(hash)

    assert_instance_of SimpleAcp::Models::CitationMetadata, citation
    assert_equal 10, citation.start_index
    assert_equal 20, citation.end_index
  end

  def test_from_hash_returns_nil_for_wrong_kind
    hash = { "kind" => "trajectory" }
    assert_nil SimpleAcp::Models::CitationMetadata.from_hash(hash)
  end

  def test_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::CitationMetadata.from_hash(nil)
  end

  def test_to_h_serializes_properly
    citation = SimpleAcp::Models::CitationMetadata.new(
      start_index: 5,
      end_index: 15,
      url: "https://example.com"
    )
    hash = citation.to_h

    assert_equal "citation", hash[:kind]
    assert_equal 5, hash[:start_index]
    assert_equal 15, hash[:end_index]
    assert_equal "https://example.com", hash[:url]
  end
end

class TrajectoryMetadataTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    trajectory = SimpleAcp::Models::TrajectoryMetadata.new(
      message: "Calling search tool",
      tool_name: "search",
      tool_input: { query: "test" },
      tool_output: { results: [] }
    )

    assert_equal "trajectory", trajectory.kind
    assert_equal "Calling search tool", trajectory.message
    assert_equal "search", trajectory.tool_name
    assert_equal({ query: "test" }, trajectory.tool_input)
    assert_equal({ results: [] }, trajectory.tool_output)
  end

  def test_kind_defaults_to_trajectory
    trajectory = SimpleAcp::Models::TrajectoryMetadata.new
    assert_equal "trajectory", trajectory.kind
  end

  def test_from_hash_with_correct_kind
    hash = {
      "kind" => "trajectory",
      "message" => "Processing",
      "tool_name" => "calculator"
    }

    trajectory = SimpleAcp::Models::TrajectoryMetadata.from_hash(hash)

    assert_instance_of SimpleAcp::Models::TrajectoryMetadata, trajectory
    assert_equal "Processing", trajectory.message
    assert_equal "calculator", trajectory.tool_name
  end

  def test_from_hash_returns_nil_for_wrong_kind
    hash = { "kind" => "citation" }
    assert_nil SimpleAcp::Models::TrajectoryMetadata.from_hash(hash)
  end

  def test_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::TrajectoryMetadata.from_hash(nil)
  end

  def test_to_h_serializes_properly
    trajectory = SimpleAcp::Models::TrajectoryMetadata.new(
      message: "Test",
      tool_name: "test_tool"
    )
    hash = trajectory.to_h

    assert_equal "trajectory", hash[:kind]
    assert_equal "Test", hash[:message]
    assert_equal "test_tool", hash[:tool_name]
  end
end

class AuthorTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    author = SimpleAcp::Models::Author.new(
      name: "John Doe",
      email: "john@example.com",
      url: "https://johndoe.com"
    )

    assert_equal "John Doe", author.name
    assert_equal "john@example.com", author.email
    assert_equal "https://johndoe.com", author.url
  end

  def test_name_is_required
    # The required flag is currently just metadata
    author = SimpleAcp::Models::Author.new(name: "Jane")
    assert_equal "Jane", author.name
  end

  def test_from_hash_deserializes
    hash = {
      "name" => "Alice",
      "email" => "alice@example.com"
    }

    author = SimpleAcp::Models::Author.from_hash(hash)

    assert_equal "Alice", author.name
    assert_equal "alice@example.com", author.email
    assert_nil author.url
  end

  def test_to_h_serializes
    author = SimpleAcp::Models::Author.new(name: "Bob", email: "bob@test.com")
    hash = author.to_h

    assert_equal "Bob", hash[:name]
    assert_equal "bob@test.com", hash[:email]
    refute_includes hash.keys, :url
  end
end

class ContributorTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    contributor = SimpleAcp::Models::Contributor.new(
      name: "Jane Smith",
      email: "jane@example.com",
      url: "https://janesmith.com"
    )

    assert_equal "Jane Smith", contributor.name
    assert_equal "jane@example.com", contributor.email
    assert_equal "https://janesmith.com", contributor.url
  end

  def test_from_hash_deserializes
    hash = { "name" => "Charlie", "url" => "https://charlie.dev" }
    contributor = SimpleAcp::Models::Contributor.from_hash(hash)

    assert_equal "Charlie", contributor.name
    assert_equal "https://charlie.dev", contributor.url
  end
end

class LinkTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    link = SimpleAcp::Models::Link.new(
      type: "homepage",
      url: "https://example.com"
    )

    assert_equal "homepage", link.type
    assert_equal "https://example.com", link.url
  end

  def test_valid_returns_true_for_valid_link
    link = SimpleAcp::Models::Link.new(
      type: SimpleAcp::Models::Types::LinkType::HOMEPAGE,
      url: "https://example.com"
    )

    assert link.valid?
  end

  def test_valid_returns_false_for_invalid_type
    link = SimpleAcp::Models::Link.new(
      type: "invalid-type",
      url: "https://example.com"
    )

    refute link.valid?
  end

  def test_valid_returns_false_for_invalid_url
    link = SimpleAcp::Models::Link.new(
      type: SimpleAcp::Models::Types::LinkType::HOMEPAGE,
      url: "not-a-url"
    )

    refute link.valid?
  end

  def test_all_link_types
    SimpleAcp::Models::Types::LinkType::ALL.each do |link_type|
      link = SimpleAcp::Models::Link.new(
        type: link_type,
        url: "https://example.com/#{link_type}"
      )
      assert link.valid?, "Link type #{link_type} should be valid"
    end
  end
end

class DependencyTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    dependency = SimpleAcp::Models::Dependency.new(
      type: "agent",
      name: "helper-agent"
    )

    assert_equal "agent", dependency.type
    assert_equal "helper-agent", dependency.name
  end

  def test_valid_returns_true_for_valid_dependency
    dependency = SimpleAcp::Models::Dependency.new(
      type: SimpleAcp::Models::Types::DependencyType::AGENT,
      name: "my-agent"
    )

    assert dependency.valid?
  end

  def test_valid_returns_false_for_invalid_type
    dependency = SimpleAcp::Models::Dependency.new(
      type: "invalid",
      name: "something"
    )

    refute dependency.valid?
  end

  def test_all_dependency_types
    SimpleAcp::Models::Types::DependencyType::ALL.each do |dep_type|
      dependency = SimpleAcp::Models::Dependency.new(
        type: dep_type,
        name: "test-#{dep_type}"
      )
      assert dependency.valid?, "Dependency type #{dep_type} should be valid"
    end
  end
end

class CapabilityTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    capability = SimpleAcp::Models::Capability.new(
      name: "text-generation",
      description: "Generates natural language text"
    )

    assert_equal "text-generation", capability.name
    assert_equal "Generates natural language text", capability.description
  end

  def test_from_hash_deserializes
    hash = {
      "name" => "code-execution",
      "description" => "Executes code snippets"
    }

    capability = SimpleAcp::Models::Capability.from_hash(hash)

    assert_equal "code-execution", capability.name
    assert_equal "Executes code snippets", capability.description
  end

  def test_to_h_serializes
    capability = SimpleAcp::Models::Capability.new(
      name: "search",
      description: "Searches the web"
    )
    hash = capability.to_h

    assert_equal "search", hash[:name]
    assert_equal "Searches the web", hash[:description]
  end
end

class AnnotationsTest < SimpleAcpTestCase
  def test_initialize_with_defaults
    annotations = SimpleAcp::Models::Annotations.new
    assert_equal({}, annotations.extra)
  end

  def test_initialize_with_beeai_ui
    annotations = SimpleAcp::Models::Annotations.new(beeai_ui: { theme: "dark" })
    assert_equal({ theme: "dark" }, annotations.beeai_ui)
  end

  def test_bracket_accessor_reads_from_extra
    annotations = SimpleAcp::Models::Annotations.new(extra: { custom: "value" })
    assert_equal "value", annotations[:custom]
  end

  def test_bracket_setter_writes_to_extra
    annotations = SimpleAcp::Models::Annotations.new
    annotations[:custom_key] = "custom_value"

    assert_equal "custom_value", annotations[:custom_key]
    assert_equal "custom_value", annotations.extra[:custom_key]
  end

  def test_to_h_includes_extra_keys_at_top_level
    annotations = SimpleAcp::Models::Annotations.new(
      beeai_ui: { theme: "light" },
      extra: { custom1: "val1", custom2: "val2" }
    )
    hash = annotations.to_h

    assert_equal({ theme: "light" }, hash[:beeai_ui])
    assert_equal "val1", hash[:custom1]
    assert_equal "val2", hash[:custom2]
  end
end

class AgentStatusTest < SimpleAcpTestCase
  def test_initialize_with_attributes
    status = SimpleAcp::Models::AgentStatus.new(
      average_tokens: 1500,
      average_run_time: 2.5,
      success_rate: 0.95
    )

    assert_equal 1500, status.average_tokens
    assert_equal 2.5, status.average_run_time
    assert_equal 0.95, status.success_rate
  end

  def test_from_hash_deserializes
    hash = {
      "average_tokens" => 2000,
      "average_run_time" => 3.0,
      "success_rate" => 0.98
    }

    status = SimpleAcp::Models::AgentStatus.from_hash(hash)

    assert_equal 2000, status.average_tokens
    assert_equal 3.0, status.average_run_time
    assert_equal 0.98, status.success_rate
  end

  def test_to_h_serializes
    status = SimpleAcp::Models::AgentStatus.new(
      average_tokens: 500,
      success_rate: 1.0
    )
    hash = status.to_h

    assert_equal 500, hash[:average_tokens]
    assert_equal 1.0, hash[:success_rate]
    refute_includes hash.keys, :average_run_time
  end
end

class MetadataTest < SimpleAcpTestCase
  def test_initialize_with_simple_attributes
    metadata = SimpleAcp::Models::Metadata.new(
      documentation: "https://docs.example.com",
      license: "MIT",
      programming_language: "Ruby",
      framework: "Rails"
    )

    assert_equal "https://docs.example.com", metadata.documentation
    assert_equal "MIT", metadata.license
    assert_equal "Ruby", metadata.programming_language
    assert_equal "Rails", metadata.framework
  end

  def test_array_attributes_default_to_empty_arrays
    metadata = SimpleAcp::Models::Metadata.new
    assert_equal [], metadata.natural_languages
    assert_equal [], metadata.capabilities
    assert_equal [], metadata.domains
    assert_equal [], metadata.tags
    assert_equal [], metadata.contributors
    assert_equal [], metadata.links
    assert_equal [], metadata.dependencies
    assert_equal [], metadata.recommended_models
  end

  def test_from_hash_with_nested_annotations
    hash = {
      "annotations" => { "beeai_ui" => { "theme" => "dark" } }
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_instance_of SimpleAcp::Models::Annotations, metadata.annotations
    assert_equal({ "theme" => "dark" }, metadata.annotations.beeai_ui)
  end

  def test_from_hash_with_nested_author
    hash = {
      "author" => { "name" => "John", "email" => "john@example.com" }
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_instance_of SimpleAcp::Models::Author, metadata.author
    assert_equal "John", metadata.author.name
    assert_equal "john@example.com", metadata.author.email
  end

  def test_from_hash_with_contributors_array
    hash = {
      "contributors" => [
        { "name" => "Alice" },
        { "name" => "Bob", "email" => "bob@test.com" }
      ]
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_equal 2, metadata.contributors.length
    assert_instance_of SimpleAcp::Models::Contributor, metadata.contributors.first
    assert_equal "Alice", metadata.contributors[0].name
    assert_equal "Bob", metadata.contributors[1].name
  end

  def test_from_hash_with_capabilities_array
    hash = {
      "capabilities" => [
        { "name" => "search", "description" => "Search the web" },
        { "name" => "code", "description" => "Write code" }
      ]
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_equal 2, metadata.capabilities.length
    assert_instance_of SimpleAcp::Models::Capability, metadata.capabilities.first
    assert_equal "search", metadata.capabilities[0].name
  end

  def test_from_hash_with_links_array
    hash = {
      "links" => [
        { "type" => "homepage", "url" => "https://example.com" },
        { "type" => "documentation", "url" => "https://docs.example.com" }
      ]
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_equal 2, metadata.links.length
    assert_instance_of SimpleAcp::Models::Link, metadata.links.first
    assert_equal "homepage", metadata.links[0].type
  end

  def test_from_hash_with_dependencies_array
    hash = {
      "dependencies" => [
        { "type" => "agent", "name" => "helper" },
        { "type" => "tool", "name" => "calculator" }
      ]
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(hash)

    assert_equal 2, metadata.dependencies.length
    assert_instance_of SimpleAcp::Models::Dependency, metadata.dependencies.first
    assert_equal "agent", metadata.dependencies[0].type
    assert_equal "helper", metadata.dependencies[0].name
  end

  def test_from_hash_returns_nil_for_nil
    assert_nil SimpleAcp::Models::Metadata.from_hash(nil)
  end

  def test_comprehensive_metadata_round_trip
    original_hash = {
      "documentation" => "https://docs.example.com",
      "license" => "MIT",
      "programming_language" => "Ruby",
      "natural_languages" => ["en", "es"],
      "framework" => "Rails",
      "domains" => ["web", "api"],
      "tags" => ["ai", "automation"],
      "author" => { "name" => "Test Author", "email" => "test@example.com" },
      "contributors" => [{ "name" => "Contributor 1" }],
      "capabilities" => [{ "name" => "cap1", "description" => "desc1" }],
      "links" => [{ "type" => "homepage", "url" => "https://example.com" }],
      "dependencies" => [{ "type" => "agent", "name" => "dep1" }],
      "recommended_models" => ["gpt-4", "claude-3"]
    }

    metadata = SimpleAcp::Models::Metadata.from_hash(original_hash)
    serialized = metadata.to_h

    assert_equal "https://docs.example.com", serialized[:documentation]
    assert_equal "MIT", serialized[:license]
    assert_equal "Ruby", serialized[:programming_language]
    assert_equal ["en", "es"], serialized[:natural_languages]
    assert_equal ["web", "api"], serialized[:domains]
    assert_equal ["ai", "automation"], serialized[:tags]
    assert_equal ["gpt-4", "claude-3"], serialized[:recommended_models]

    # Nested objects are serialized to hashes
    assert_kind_of Hash, serialized[:author]
    assert_equal "Test Author", serialized[:author][:name]
  end
end
