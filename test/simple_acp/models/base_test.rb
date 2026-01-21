# frozen_string_literal: true

require "test_helper"

class ModelsBaseTest < SimpleAcpTestCase
  # Test model with various attribute types
  class TestModel < SimpleAcp::Models::Base
    attribute :name, required: true
    attribute :count, default: 0
    attribute :tags, default: -> { [] }
    attribute :metadata, default: -> { {} }
    attribute :optional_field
  end

  # Child model for inheritance tests
  class ChildModel < TestModel
    attribute :child_field
  end

  # Model with nested Base objects
  class ContainerModel < SimpleAcp::Models::Base
    attribute :nested
    attribute :nested_array, default: -> { [] }
  end

  # Attribute definition tests
  def test_attribute_defines_reader
    model = TestModel.new(name: "test")
    assert_equal "test", model.name
  end

  def test_attribute_defines_writer
    model = TestModel.new(name: "test")
    model.name = "updated"
    assert_equal "updated", model.name
  end

  def test_attribute_with_default_value
    model = TestModel.new(name: "test")
    assert_equal 0, model.count
  end

  def test_attribute_with_proc_default
    model1 = TestModel.new(name: "test1")
    model2 = TestModel.new(name: "test2")

    # Each instance should get its own array
    model1.tags << "tag1"
    assert_equal ["tag1"], model1.tags
    assert_equal [], model2.tags
  end

  def test_attribute_without_default_is_nil
    model = TestModel.new(name: "test")
    assert_nil model.optional_field
  end

  def test_attributes_returns_all_defined_attributes
    attributes = TestModel.attributes
    assert_includes attributes.keys, :name
    assert_includes attributes.keys, :count
    assert_includes attributes.keys, :tags
    assert_includes attributes.keys, :metadata
    assert_includes attributes.keys, :optional_field
  end

  def test_own_attributes_returns_only_class_attributes
    own = TestModel.own_attributes
    assert_includes own.keys, :name
  end

  # Inheritance tests
  def test_child_inherits_parent_attributes
    attributes = ChildModel.attributes
    assert_includes attributes.keys, :name
    assert_includes attributes.keys, :count
    assert_includes attributes.keys, :child_field
  end

  def test_child_can_override_inherited_attributes
    child = ChildModel.new(name: "child", child_field: "extra")
    assert_equal "child", child.name
    assert_equal "extra", child.child_field
    assert_equal 0, child.count
  end

  # Initialization tests
  def test_initialize_with_keyword_arguments
    model = TestModel.new(name: "test", count: 5, tags: ["a", "b"])
    assert_equal "test", model.name
    assert_equal 5, model.count
    assert_equal ["a", "b"], model.tags
  end

  def test_initialize_with_missing_required_field
    # Currently no validation on required, just documents intent
    model = TestModel.new
    assert_nil model.name
  end

  # from_hash tests
  def test_from_hash_with_string_keys
    model = TestModel.from_hash("name" => "test", "count" => 10)
    assert_equal "test", model.name
    assert_equal 10, model.count
  end

  def test_from_hash_with_symbol_keys
    model = TestModel.from_hash(name: "test", count: 10)
    assert_equal "test", model.name
    assert_equal 10, model.count
  end

  def test_from_hash_with_nil_returns_nil
    assert_nil TestModel.from_hash(nil)
  end

  def test_from_hash_ignores_nil_values
    model = TestModel.from_hash("name" => "test", "count" => nil)
    assert_equal "test", model.name
    assert_equal 0, model.count # Uses default, not nil
  end

  def test_from_h_alias
    model = TestModel.from_h("name" => "test")
    assert_equal "test", model.name
  end

  # to_h tests
  def test_to_h_serializes_attributes
    model = TestModel.new(name: "test", count: 5)
    hash = model.to_h

    assert_equal "test", hash[:name]
    assert_equal 5, hash[:count]
  end

  def test_to_h_excludes_nil_values
    model = TestModel.new(name: "test")
    hash = model.to_h

    assert_includes hash.keys, :name
    refute_includes hash.keys, :optional_field
  end

  def test_to_h_serializes_nested_base_objects
    nested = TestModel.new(name: "nested")
    container = ContainerModel.new(nested: nested)
    hash = container.to_h

    assert_kind_of Hash, hash[:nested]
    assert_equal "nested", hash[:nested][:name]
  end

  def test_to_h_serializes_arrays_of_base_objects
    nested1 = TestModel.new(name: "nested1")
    nested2 = TestModel.new(name: "nested2")
    container = ContainerModel.new(nested_array: [nested1, nested2])
    hash = container.to_h

    assert_kind_of Array, hash[:nested_array]
    assert_equal "nested1", hash[:nested_array][0][:name]
    assert_equal "nested2", hash[:nested_array][1][:name]
  end

  def test_to_h_serializes_time_to_iso8601
    time = Time.new(2024, 1, 15, 12, 30, 0, "+00:00")
    model = TestModel.new(name: "test", metadata: { created_at: time })
    hash = model.to_h

    assert_kind_of String, hash[:metadata][:created_at]
    assert_match(/2024-01-15/, hash[:metadata][:created_at])
  end

  def test_to_h_serializes_nested_hashes
    model = TestModel.new(name: "test", metadata: { nested: { deep: "value" } })
    hash = model.to_h

    assert_equal "value", hash[:metadata][:nested][:deep]
  end

  # to_json tests
  def test_to_json_produces_valid_json
    model = TestModel.new(name: "test", count: 5)
    json = model.to_json

    parsed = JSON.parse(json)
    assert_equal "test", parsed["name"]
    assert_equal 5, parsed["count"]
  end

  # Equality tests
  def test_equality_with_same_attributes
    model1 = TestModel.new(name: "test", count: 5)
    model2 = TestModel.new(name: "test", count: 5)

    assert_equal model1, model2
  end

  def test_inequality_with_different_attributes
    model1 = TestModel.new(name: "test", count: 5)
    model2 = TestModel.new(name: "test", count: 10)

    refute_equal model1, model2
  end

  def test_inequality_with_different_class
    model = TestModel.new(name: "test")
    other = "not a model"

    refute_equal model, other
  end

  def test_eql_alias
    model1 = TestModel.new(name: "test")
    model2 = TestModel.new(name: "test")

    assert model1.eql?(model2)
  end

  # Hash code tests
  def test_hash_same_for_equal_objects
    model1 = TestModel.new(name: "test", count: 5)
    model2 = TestModel.new(name: "test", count: 5)

    assert_equal model1.hash, model2.hash
  end

  def test_hash_different_for_different_objects
    model1 = TestModel.new(name: "test1")
    model2 = TestModel.new(name: "test2")

    refute_equal model1.hash, model2.hash
  end

  def test_can_use_as_hash_key
    model1 = TestModel.new(name: "test")
    model2 = TestModel.new(name: "test")

    hash = { model1 => "value" }
    assert_equal "value", hash[model2]
  end

  # Round-trip tests
  def test_round_trip_serialization
    original = TestModel.new(name: "test", count: 42, tags: ["a", "b"])
    restored = TestModel.from_hash(original.to_h)

    assert_equal original.name, restored.name
    assert_equal original.count, restored.count
    assert_equal original.tags, restored.tags
  end

  def test_round_trip_json
    original = TestModel.new(name: "test", count: 42)
    json = original.to_json
    restored = TestModel.from_hash(JSON.parse(json))

    assert_equal original.name, restored.name
    assert_equal original.count, restored.count
  end
end
