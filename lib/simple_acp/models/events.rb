# frozen_string_literal: true

module SimpleAcp
  module Models
    # Base class for all Server-Sent Events (SSE).
    #
    # Events are streamed during run execution to provide
    # real-time updates on progress and output.
    #
    # @abstract Subclass and set type in initializer
    class Event < Base
      # @!attribute [r] type
      #   @return [String] event type (see Types::EventType)
      attribute :type, required: true

      # Format for Server-Sent Events protocol.
      #
      # @return [String] SSE-formatted event
      def sse_format
        "event: #{@type}\ndata: #{to_json}\n\n"
      end
    end

    # Message created event
    class MessageCreatedEvent < Event
      attribute :message

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::MESSAGE_CREATED
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["message"] || hash[:message]
          instance.message = Message.from_hash(hash["message"] || hash[:message])
        end
        instance
      end
    end

    # Message part event (for streaming individual parts)
    class MessagePartEvent < Event
      attribute :part

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::MESSAGE_PART
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["part"] || hash[:part]
          instance.part = MessagePart.from_hash(hash["part"] || hash[:part])
        end
        instance
      end
    end

    # Message completed event
    class MessageCompletedEvent < Event
      attribute :message

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::MESSAGE_COMPLETED
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["message"] || hash[:message]
          instance.message = Message.from_hash(hash["message"] || hash[:message])
        end
        instance
      end
    end

    # Run created event
    class RunCreatedEvent < Event
      attribute :run

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_CREATED
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["run"] || hash[:run]
          instance.run = Run.from_hash(hash["run"] || hash[:run])
        end
        instance
      end
    end

    # Run in-progress event
    class RunInProgressEvent < Event
      attribute :run_id

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_IN_PROGRESS
        super
      end
    end

    # Run awaiting event
    class RunAwaitingEvent < Event
      attribute :run_id
      attribute :await_request

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_AWAITING
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["await_request"] || hash[:await_request]
          instance.await_request = AwaitRequest.from_hash(hash["await_request"] || hash[:await_request])
        end
        instance
      end
    end

    # Run completed event
    class RunCompletedEvent < Event
      attribute :run

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_COMPLETED
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["run"] || hash[:run]
          instance.run = Run.from_hash(hash["run"] || hash[:run])
        end
        instance
      end
    end

    # Run cancelled event
    class RunCancelledEvent < Event
      attribute :run_id

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_CANCELLED
        super
      end
    end

    # Run failed event
    class RunFailedEvent < Event
      attribute :run_id
      attribute :error

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::RUN_FAILED
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["error"] || hash[:error]
          instance.error = Error.from_hash(hash["error"] || hash[:error])
        end
        instance
      end
    end

    # Generic event
    class GenericEvent < Event
      attribute :data

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::GENERIC
        super
      end
    end

    # Error event
    class ErrorEvent < Event
      attribute :error

      def initialize(**kwargs)
        kwargs[:type] = Types::EventType::ERROR
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = super
        if hash["error"] || hash[:error]
          instance.error = Error.from_hash(hash["error"] || hash[:error])
        end
        instance
      end
    end

    # Factory module for parsing events from hashes.
    module Events
      # Mapping of event types to classes
      EVENT_CLASSES = {
        Types::EventType::MESSAGE_CREATED => MessageCreatedEvent,
        Types::EventType::MESSAGE_PART => MessagePartEvent,
        Types::EventType::MESSAGE_COMPLETED => MessageCompletedEvent,
        Types::EventType::RUN_CREATED => RunCreatedEvent,
        Types::EventType::RUN_IN_PROGRESS => RunInProgressEvent,
        Types::EventType::RUN_AWAITING => RunAwaitingEvent,
        Types::EventType::RUN_COMPLETED => RunCompletedEvent,
        Types::EventType::RUN_CANCELLED => RunCancelledEvent,
        Types::EventType::RUN_FAILED => RunFailedEvent,
        Types::EventType::GENERIC => GenericEvent,
        Types::EventType::ERROR => ErrorEvent
      }.freeze

      # Parse an event from a hash.
      #
      # @param hash [Hash, nil] event data with "type" key
      # @return [Event, nil] the appropriate event subclass or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        type = hash["type"] || hash[:type]
        klass = EVENT_CLASSES[type] || GenericEvent
        klass.from_hash(hash)
      end

      # Parse JSON SSE data.
      #
      # @param data [String] JSON string
      # @return [Hash, nil] parsed hash or nil if invalid
      def self.parse_sse(data)
        JSON.parse(data)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
