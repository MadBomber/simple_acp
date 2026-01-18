# frozen_string_literal: true

module SimpleAcp
  module Server
    # Wrapper for registered agent handlers
    class Agent
      attr_reader :manifest, :handler

      def initialize(manifest:, handler:)
        @manifest = manifest
        @handler = handler
      end

      def name
        @manifest.name
      end

      def description
        @manifest.description
      end

      # Execute the agent with given context
      def call(context)
        result = @handler.call(context)

        # Handle different return types
        case result
        when Enumerator, Enumerator::Lazy
          # Generator-style handler that yields messages
          result
        when RunYield, RunYieldAwait
          # Already wrapped
          [result]
        when Models::Message
          # Single message return
          [RunYield.new(result)]
        when Array
          # Array of messages or yields
          result.map { |m| wrap_result_item(m) }
        when String
          # Simple string response
          [RunYield.new(Models::Message.agent(result))]
        else
          # Try to convert to enumerator
          result.respond_to?(:each) ? result.each : [wrap_result_item(result)]
        end
      end

      def valid?
        @manifest.valid? && @handler.respond_to?(:call)
      end

      private

      def wrap_result_item(item)
        case item
        when RunYield, RunYieldAwait
          item
        when Models::Message
          RunYield.new(item)
        when String
          RunYield.new(Models::Message.agent(item))
        else
          item
        end
      end
    end

    # DSL for defining agents
    module AgentDSL
      def self.define(name:, description: nil, **options, &block)
        manifest = Models::AgentManifest.new(
          name: name,
          description: description,
          input_content_types: options[:input_content_types] || ["text/plain"],
          output_content_types: options[:output_content_types] || ["text/plain"],
          metadata: options[:metadata]
        )

        Agent.new(manifest: manifest, handler: block)
      end
    end
  end
end
