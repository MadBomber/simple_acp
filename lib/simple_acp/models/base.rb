# frozen_string_literal: true

module SimpleAcp
  module Models
    # Base class for all ACP models providing common serialization.
    #
    # Provides a simple DSL for declaring attributes with defaults,
    # automatic JSON serialization/deserialization, and equality comparisons.
    #
    # @example Defining a model
    #   class MyModel < Base
    #     attribute :name, required: true
    #     attribute :count, default: 0
    #     attribute :tags, default: -> { [] }
    #   end
    #
    # @abstract Subclass and use {.attribute} to define attributes
    class Base
      class << self
        # Define an attribute on this model.
        #
        # @param name [Symbol] the attribute name
        # @param type [Class, nil] optional type hint (for documentation)
        # @param default [Object, Proc, nil] default value or proc
        # @param required [Boolean] whether the attribute is required
        # @return [void]
        def attribute(name, type: nil, default: nil, required: false)
          @attributes ||= {}
          @attributes[name] = { type: type, default: default, required: required }

          attr_reader name

          define_method(:"#{name}=") do |value|
            instance_variable_set(:"@#{name}", value)
          end
        end

        # Get all attributes including inherited ones.
        #
        # @return [Hash<Symbol, Hash>] attribute definitions
        def attributes
          @attributes ||= {}

          # Inherit attributes from parent class
          if superclass.respond_to?(:attributes)
            superclass.attributes.merge(@attributes)
          else
            @attributes
          end
        end

        # Get only attributes defined on this class (not inherited).
        #
        # @return [Hash<Symbol, Hash>] attribute definitions
        def own_attributes
          @attributes ||= {}
        end

        # Create an instance from a hash.
        #
        # @param hash [Hash, nil] attribute values (string or symbol keys)
        # @return [Base, nil] the new instance or nil if hash is nil
        def from_hash(hash)
          return nil if hash.nil?

          instance = new
          attributes.each do |name, _opts|
            key = name.to_s
            value = hash.key?(key) ? hash[key] : hash[name]
            instance.send(:"#{name}=", value) unless value.nil?
          end
          instance
        end

        alias from_h from_hash
      end

      # Initialize with keyword arguments.
      #
      # @param kwargs [Hash] attribute values
      def initialize(**kwargs)
        self.class.attributes.each do |name, opts|
          value = kwargs.fetch(name) { opts[:default].is_a?(Proc) ? opts[:default].call : opts[:default] }
          instance_variable_set(:"@#{name}", value)
        end
      end

      # Convert to a hash for JSON serialization.
      #
      # @return [Hash] attribute values (nil values excluded)
      def to_h
        self.class.attributes.each_with_object({}) do |(name, _opts), hash|
          value = send(name)
          next if value.nil?

          hash[name] = serialize_value(value)
        end
      end

      # Convert to JSON string.
      #
      # @param args [Array] arguments passed to Hash#to_json
      # @return [String] JSON representation
      def to_json(*args)
        to_h.to_json(*args)
      end

      # Check equality based on all attributes.
      #
      # @param other [Object] object to compare
      # @return [Boolean] true if same class and all attributes equal
      def ==(other)
        return false unless other.is_a?(self.class)

        self.class.attributes.keys.all? do |name|
          send(name) == other.send(name)
        end
      end

      alias eql? ==

      # Compute hash based on all attributes.
      #
      # @return [Integer] hash code
      def hash
        self.class.attributes.keys.map { |name| send(name) }.hash
      end

      private

      def serialize_value(value)
        case value
        when Base
          value.to_h
        when Array
          value.map { |v| serialize_value(v) }
        when Hash
          value.transform_values { |v| serialize_value(v) }
        when Time
          value.utc.iso8601
        else
          value
        end
      end
    end
  end
end
