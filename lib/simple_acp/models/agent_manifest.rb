# frozen_string_literal: true

module SimpleAcp
  module Models
    # Describes agent capabilities for discovery
    class AgentManifest < Base
      attribute :name, required: true
      attribute :description
      attribute :metadata
      attribute :input_content_types, default: -> { ["text/plain"] }
      attribute :output_content_types, default: -> { ["text/plain"] }
      attribute :status

      def initialize(**kwargs)
        super
        @input_content_types ||= ["text/plain"]
        @output_content_types ||= ["text/plain"]
      end

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

      def accepts_content_type?(content_type)
        return true if @input_content_types.include?("*/*")

        @input_content_types.any? do |accepted|
          matches_content_type?(accepted, content_type)
        end
      end

      def produces_content_type?(content_type)
        return true if @output_content_types.include?("*/*")

        @output_content_types.any? do |produced|
          matches_content_type?(produced, content_type)
        end
      end

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
