# frozen_string_literal: true

module SimpleAcp
  module Models
    # Type definitions, constants, and validations for ACP.
    #
    # Contains all the enumerated types and validation helpers
    # used throughout the protocol.
    module Types
      # Agent name must follow RFC 1123 DNS label format
      AGENT_NAME_PATTERN = /\A[a-z0-9]([-a-z0-9]*[a-z0-9])?\z/

      # Maximum length for agent names
      AGENT_NAME_MAX_LENGTH = 63

      # Run execution modes.
      module RunMode
        # Synchronous execution (blocks until complete)
        SYNC = "sync"
        # Asynchronous execution (returns immediately)
        ASYNC = "async"
        # Streaming execution (SSE events)
        STREAM = "stream"

        # All valid modes
        ALL = [SYNC, ASYNC, STREAM].freeze

        # Check if a mode is valid.
        #
        # @param mode [String] mode to check
        # @return [Boolean] true if valid
        def self.valid?(mode)
          ALL.include?(mode)
        end
      end

      # Run status values.
      module RunStatus
        # Run created but not started
        CREATED = "created"
        # Run is executing
        IN_PROGRESS = "in-progress"
        # Run is waiting for client input
        AWAITING = "awaiting"
        # Run is being cancelled
        CANCELLING = "cancelling"
        # Run was cancelled
        CANCELLED = "cancelled"
        # Run completed successfully
        COMPLETED = "completed"
        # Run failed with error
        FAILED = "failed"

        # All valid statuses
        ALL = [CREATED, IN_PROGRESS, AWAITING, CANCELLING, CANCELLED, COMPLETED, FAILED].freeze

        # Terminal (final) statuses
        TERMINAL = [COMPLETED, FAILED, CANCELLED].freeze

        # Check if a status is valid.
        #
        # @param status [String] status to check
        # @return [Boolean] true if valid
        def self.valid?(status)
          ALL.include?(status)
        end

        # Check if a status is terminal (run is finished).
        #
        # @param status [String] status to check
        # @return [Boolean] true if terminal
        def self.terminal?(status)
          TERMINAL.include?(status)
        end
      end

      # Link types for agent metadata.
      module LinkType
        # Link to source code repository
        SOURCE_CODE = "source-code"
        # Link to container image
        CONTAINER_IMAGE = "container-image"
        # Link to homepage
        HOMEPAGE = "homepage"
        # Link to documentation
        DOCUMENTATION = "documentation"

        # All valid link types
        ALL = [SOURCE_CODE, CONTAINER_IMAGE, HOMEPAGE, DOCUMENTATION].freeze
      end

      # Dependency types for agent metadata.
      module DependencyType
        # Depends on another agent
        AGENT = "agent"
        # Depends on a tool
        TOOL = "tool"
        # Depends on a model
        MODEL = "model"

        # All valid dependency types
        ALL = [AGENT, TOOL, MODEL].freeze
      end

      # Content encoding types.
      module ContentEncoding
        # Plain text (no encoding)
        PLAIN = "plain"
        # Base64 encoded
        BASE64 = "base64"

        # All valid encodings
        ALL = [PLAIN, BASE64].freeze
      end

      # Event types for SSE streaming.
      module EventType
        # New message created
        MESSAGE_CREATED = "message.created"
        # Message part received
        MESSAGE_PART = "message.part"
        # Message completed
        MESSAGE_COMPLETED = "message.completed"
        # Run created
        RUN_CREATED = "run.created"
        # Run started executing
        RUN_IN_PROGRESS = "run.in-progress"
        # Run awaiting client input
        RUN_AWAITING = "run.awaiting"
        # Run completed successfully
        RUN_COMPLETED = "run.completed"
        # Run was cancelled
        RUN_CANCELLED = "run.cancelled"
        # Run failed
        RUN_FAILED = "run.failed"
        # Generic event
        GENERIC = "generic"
        # Error event
        ERROR = "error"

        # All valid event types
        ALL = [
          MESSAGE_CREATED, MESSAGE_PART, MESSAGE_COMPLETED,
          RUN_CREATED, RUN_IN_PROGRESS, RUN_AWAITING,
          RUN_COMPLETED, RUN_CANCELLED, RUN_FAILED,
          GENERIC, ERROR
        ].freeze
      end

      # Message role types.
      module Role
        # Message from user
        USER = "user"
        # Message from agent
        AGENT = "agent"

        # Check if a role is valid.
        #
        # @param role [String] role to check
        # @return [Boolean] true if "user", "agent", or "agent/name"
        def self.valid?(role)
          role == USER || role == AGENT || role.to_s.start_with?("agent/")
        end
      end

      class << self
        # Validate an agent name.
        #
        # @param name [String, nil] name to validate
        # @return [Boolean] true if valid RFC 1123 DNS label
        def valid_agent_name?(name)
          return false if name.nil? || name.empty?
          return false if name.length > AGENT_NAME_MAX_LENGTH

          AGENT_NAME_PATTERN.match?(name)
        end

        # Validate a UUID.
        #
        # @param value [String, nil] value to validate
        # @return [Boolean] true if valid UUID format
        def valid_uuid?(value)
          return false if value.nil?

          /\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i.match?(value.to_s)
        end

        # Validate a URL.
        #
        # @param value [String, nil] value to validate
        # @return [Boolean] true if valid HTTP/HTTPS URL
        def valid_url?(value)
          return false if value.nil?

          uri = URI.parse(value.to_s)
          uri.is_a?(URI::HTTP) || uri.is_a?(URI::HTTPS)
        rescue URI::InvalidURIError
          false
        end

        # Generate a new UUID.
        #
        # @return [String] UUID string
        def generate_uuid
          SecureRandom.uuid
        end
      end
    end
  end
end
