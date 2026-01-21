# frozen_string_literal: true

module SimpleAcp
  module Server
    # Wrapper for registered agent handlers.
    #
    # Encapsulates an agent's manifest (metadata) and handler (execution logic),
    # normalizing different handler return types into a consistent format.
    class Agent
      # @return [Models::AgentManifest] the agent's metadata
      attr_reader :manifest

      # @return [#call] the handler that processes requests
      attr_reader :handler

      # Create a new agent.
      #
      # @param manifest [Models::AgentManifest] agent metadata
      # @param handler [#call] callable that accepts a Context and returns messages
      def initialize(manifest:, handler:)
        @manifest = manifest
        @handler = handler
      end

      # @return [String] the agent's name
      def name
        @manifest.name
      end

      # @return [String, nil] the agent's description
      def description
        @manifest.description
      end

      # Execute the agent handler with the given context.
      #
      # Normalizes various return types (Message, String, Array, Enumerator)
      # into a consistent enumerable of {RunYield} or {RunYieldAwait} objects.
      #
      # @param context [Context] the execution context
      # @return [Enumerable<RunYield, RunYieldAwait>] yielded results
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

      # Check if the agent is valid for registration.
      #
      # @return [Boolean] true if manifest is valid and handler is callable
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

    # DSL module for defining agents with block syntax.
    module AgentDSL
      # Define an agent from a block.
      #
      # @param name [String] agent name (must follow RFC 1123 DNS label format)
      # @param description [String, nil] human-readable description
      # @param options [Hash] additional manifest options
      # @option options [Array<String>] :input_content_types accepted MIME types
      # @option options [Array<String>] :output_content_types produced MIME types
      # @option options [Hash] :metadata agent metadata
      # @yield [Context] block that handles agent requests
      # @return [Agent] the created agent
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
