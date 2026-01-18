# frozen_string_literal: true

module SimpleAcp
  module Models
    # Citation metadata for source attribution
    class CitationMetadata < Base
      attribute :kind, default: "citation"
      attribute :start_index
      attribute :end_index
      attribute :url
      attribute :title
      attribute :description

      def self.from_hash(hash)
        return nil if hash.nil?
        return nil unless hash["kind"] == "citation" || hash[:kind] == "citation"

        super
      end
    end

    # Trajectory metadata for tracking multi-step reasoning
    class TrajectoryMetadata < Base
      attribute :kind, default: "trajectory"
      attribute :message
      attribute :tool_name
      attribute :tool_input
      attribute :tool_output

      def self.from_hash(hash)
        return nil if hash.nil?
        return nil unless hash["kind"] == "trajectory" || hash[:kind] == "trajectory"

        super
      end
    end

    # Author information
    class Author < Base
      attribute :name, required: true
      attribute :email
      attribute :url
    end

    # Contributor information (same structure as Author)
    class Contributor < Base
      attribute :name, required: true
      attribute :email
      attribute :url
    end

    # Link to external resources
    class Link < Base
      attribute :type, required: true
      attribute :url, required: true

      def valid?
        Types::LinkType::ALL.include?(@type) && Types.valid_url?(@url)
      end
    end

    # Dependency declaration
    class Dependency < Base
      attribute :type, required: true
      attribute :name, required: true

      def valid?
        Types::DependencyType::ALL.include?(@type)
      end
    end

    # Agent capability
    class Capability < Base
      attribute :name, required: true
      attribute :description, required: true
    end

    # Annotations for platform-specific metadata
    class Annotations < Base
      attribute :beeai_ui
      attribute :extra, default: -> { {} }

      def [](key)
        @extra[key]
      end

      def []=(key, value)
        @extra[key] = value
      end

      def to_h
        hash = super
        @extra&.each { |k, v| hash[k] = v }
        hash
      end
    end

    # Agent status metrics
    class AgentStatus < Base
      attribute :average_tokens
      attribute :average_run_time
      attribute :success_rate
    end

    # Full agent metadata
    class Metadata < Base
      attribute :annotations
      attribute :documentation
      attribute :license
      attribute :programming_language
      attribute :natural_languages, default: -> { [] }
      attribute :framework
      attribute :capabilities, default: -> { [] }
      attribute :domains, default: -> { [] }
      attribute :tags, default: -> { [] }
      attribute :created_at
      attribute :updated_at
      attribute :author
      attribute :contributors, default: -> { [] }
      attribute :links, default: -> { [] }
      attribute :dependencies, default: -> { [] }
      attribute :recommended_models, default: -> { [] }

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super

        if hash["annotations"] || hash[:annotations]
          instance.annotations = Annotations.from_hash(hash["annotations"] || hash[:annotations])
        end

        if hash["author"] || hash[:author]
          instance.author = Author.from_hash(hash["author"] || hash[:author])
        end

        if hash["contributors"] || hash[:contributors]
          contributors = hash["contributors"] || hash[:contributors]
          instance.contributors = contributors.map { |c| Contributor.from_hash(c) }
        end

        if hash["capabilities"] || hash[:capabilities]
          capabilities = hash["capabilities"] || hash[:capabilities]
          instance.capabilities = capabilities.map { |c| Capability.from_hash(c) }
        end

        if hash["links"] || hash[:links]
          links = hash["links"] || hash[:links]
          instance.links = links.map { |l| Link.from_hash(l) }
        end

        if hash["dependencies"] || hash[:dependencies]
          dependencies = hash["dependencies"] || hash[:dependencies]
          instance.dependencies = dependencies.map { |d| Dependency.from_hash(d) }
        end

        instance
      end
    end
  end
end
