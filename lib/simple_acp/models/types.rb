# frozen_string_literal: true

module SimpleAcp
  module Models
    # Type definitions and validations for ACP
    module Types
      # Agent name must follow RFC 1123 DNS label format
      AGENT_NAME_PATTERN = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/
      AGENT_NAME_MAX_LENGTH = 63

      # Run modes
      module RunMode
        SYNC = "sync"
        ASYNC = "async"
        STREAM = "stream"

        ALL = [SYNC, ASYNC, STREAM].freeze

        def self.valid?(mode)
          ALL.include?(mode)
        end
      end

      # Run statuses
      module RunStatus
        CREATED = "created"
        IN_PROGRESS = "in-progress"
        AWAITING = "awaiting"
        CANCELLING = "cancelling"
        CANCELLED = "cancelled"
        COMPLETED = "completed"
        FAILED = "failed"

        ALL = [CREATED, IN_PROGRESS, AWAITING, CANCELLING, CANCELLED, COMPLETED, FAILED].freeze
        TERMINAL = [COMPLETED, FAILED, CANCELLED].freeze

        def self.valid?(status)
          ALL.include?(status)
        end

        def self.terminal?(status)
          TERMINAL.include?(status)
        end
      end

      # Link types for agent metadata
      module LinkType
        SOURCE_CODE = "source-code"
        CONTAINER_IMAGE = "container-image"
        HOMEPAGE = "homepage"
        DOCUMENTATION = "documentation"

        ALL = [SOURCE_CODE, CONTAINER_IMAGE, HOMEPAGE, DOCUMENTATION].freeze
      end

      # Dependency types
      module DependencyType
        AGENT = "agent"
        TOOL = "tool"
        MODEL = "model"

        ALL = [AGENT, TOOL, MODEL].freeze
      end

      # Content encodings
      module ContentEncoding
        PLAIN = "plain"
        BASE64 = "base64"

        ALL = [PLAIN, BASE64].freeze
      end

      # Event types for streaming
      module EventType
        MESSAGE_CREATED = "message.created"
        MESSAGE_PART = "message.part"
        MESSAGE_COMPLETED = "message.completed"
        RUN_CREATED = "run.created"
        RUN_IN_PROGRESS = "run.in-progress"
        RUN_AWAITING = "run.awaiting"
        RUN_COMPLETED = "run.completed"
        RUN_CANCELLED = "run.cancelled"
        RUN_FAILED = "run.failed"
        GENERIC = "generic"
        ERROR = "error"

        ALL = [
          MESSAGE_CREATED, MESSAGE_PART, MESSAGE_COMPLETED,
          RUN_CREATED, RUN_IN_PROGRESS, RUN_AWAITING,
          RUN_COMPLETED, RUN_CANCELLED, RUN_FAILED,
          GENERIC, ERROR
        ].freeze
      end

      # Message roles
      module Role
        USER = "user"
        AGENT = "agent"

        def self.valid?(role)
          role == USER || role == AGENT || role.to_s.start_with?("agent/")
        end
      end

      # Validation helpers
      class << self
        def valid_agent_name?(name)
          return false if name.nil? || name.empty?
          return false if name.length > AGENT_NAME_MAX_LENGTH

          AGENT_NAME_PATTERN.match?(name)
        end

        def valid_uuid?(value)
          return false if value.nil?

          /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.match?(value.to_s)
        end

        def valid_url?(value)
          return false if value.nil?

          uri = URI.parse(value.to_s)
          uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        rescue URI::InvalidURIError
          false
        end

        def generate_uuid
          SecureRandom.uuid
        end
      end
    end
  end
end
