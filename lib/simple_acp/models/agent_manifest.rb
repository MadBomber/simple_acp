# frozen_string_literal: true

module SimpleAcp
  module Models
    # Describes agent capabilities for discovery.
    #
    # Contains the metadata needed to advertise an agent's capabilities,
    # including what content types it accepts and produces.
    class AgentManifest < Base
      # @!attribute [r] name
      #   @return [String] agent name (RFC 1123 DNS label format)
      attribute :name, required: true

      # @!attribute [r] description
      #   @return [String, nil] human-readable description
      attribute :description

      # @!attribute [r] metadata
      #   @return [Metadata, nil] additional metadata
      attribute :metadata

      # @!attribute [r] input_content_types
      #   @return [Array<String>] accepted MIME types (default: ["text/plain"])
      attribute :input_content_types, default: -> { ["text/plain"] }

      # @!attribute [r] output_content_types
      #   @return [Array<String>] produced MIME types (default: ["text/plain"])
      attribute :output_content_types, default: -> { ["text/plain"] }

      # @!attribute [r] status
      #   @return [AgentStatus, nil] status metrics
      attribute :status

      def initialize(**kwargs)
        super
        @input_content_types ||= ["text/plain"]
        @output_content_types ||= ["text/plain"]
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash, nil] manifest data
      # @return [AgentManifest, nil] the manifest or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super

        if hash["metadata"] || hash[:metadata]
          instance.metadata = Metadata.from_hash(hash["metadata"] || hash[:metadata])
        end

        if hash["status"] || hash[:status]
          instance.status = AgentStatus.from_hash(hash["status"] || hash[:status])
        end

        instance
      end

      # Check if the agent accepts a content type.
      #
      # @param content_type [String] MIME type to check
      # @return [Boolean] true if accepted
      def accepts_content_type?(content_type)
        return true if @input_content_types.include?("*/*")

        @input_content_types.any? do |accepted|
          matches_content_type?(accepted, content_type)
        end
      end

      # Check if the agent produces a content type.
      #
      # @param content_type [String] MIME type to check
      # @return [Boolean] true if produced
      def produces_content_type?(content_type)
        return true if @output_content_types.include?("*/*")

        @output_content_types.any? do |produced|
          matches_content_type?(produced, content_type)
        end
      end

      # Validate the manifest.
      #
      # @return [Boolean] true if name is valid and content types are non-empty
      def valid?
        return false unless Types.valid_agent_name?(@name)
        return false if @input_content_types.empty?
        return false if @output_content_types.empty?

        true
      end

      private

      def matches_content_type?(pattern, content_type)
        return true if pattern == content_type

        # Handle wildcards like "text/*" or "image/*"
        if pattern.end_with?("/*")
          prefix = pattern[0..-3]
          return content_type.start_with?(prefix)
        end

        false
      end
    end

    # Response for listing agents
    class AgentListResponse < Base
      attribute :agents, default: -> { [] }
      attribute :total
      attribute :limit
      attribute :offset

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super

        agents_data = hash["agents"] || hash[:agents] || []
        instance.agents = agents_data.map { |a| AgentManifest.from_hash(a) }

        instance
      end
    end
  end
end
