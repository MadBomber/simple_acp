# frozen_string_literal: true

module SimpleAcp
  module Models
    # Base class for all ACP models providing common serialization
    class Base
      class << self
        def attribute(name, type: nil, default: nil, required: false)
          @attributes ||= {}
          @attributes[name] = { type: type, default: default, required: required }

          attr_reader name

          define_method(:"#{name}=") do |value|
            instance_variable_set(:"@#{name}", value)
          end
        end

        def attributes
          @attributes ||= {}

          # Inherit attributes from parent class
          if superclass.respond_to?(:attributes)
            superclass.attributes.merge(@attributes)
          else
            @attributes
          end
        end

        def own_attributes
          @attributes ||= {}
        end

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

      def initialize(**kwargs)
        self.class.attributes.each do |name, opts|
          value = kwargs.fetch(name) { opts[:default].is_a?(Proc) ? opts[:default].call : opts[:default] }
          instance_variable_set(:"@#{name}", value)
        end
      end

      def to_h
        self.class.attributes.each_with_object({}) do |(name, _opts), hash|
          value = send(name)
          next if value.nil?

          hash[name] = serialize_value(value)
        end
      end

      def to_json(*args)
        to_h.to_json(*args)
      end

      def ==(other)
        return false unless other.is_a?(self.class)

        self.class.attributes.keys.all? do |name|
          send(name) == other.send(name)
        end
      end

      alias eql? ==

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
