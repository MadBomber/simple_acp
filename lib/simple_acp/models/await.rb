# frozen_string_literal: true

module SimpleAcp
  module Models
    # Base class for await requests.
    #
    # When an agent needs client input during execution, it creates
    # an await request describing what input is needed.
    #
    # @abstract Subclass for specific await types
    class AwaitRequest < Base
      # @!attribute [r] type
      #   @return [String] await request type
      attribute :type, required: true

      # Parse from hash, creating the appropriate subclass.
      #
      # @param hash [Hash, nil] await request data
      # @return [AwaitRequest, nil] the request or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        type = hash["type"] || hash[:type]

        case type
        when "message"
          MessageAwaitRequest.from_hash(hash)
        else
          super
        end
      end
    end

    # Request for a message from the client.
    #
    # Used when an agent needs text or other message input to continue.
    class MessageAwaitRequest < AwaitRequest
      # @!attribute [r] message
      #   @return [Message, nil] prompt message to display to client
      attribute :message

      def initialize(**kwargs)
        kwargs[:type] = "message"
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.instance_variable_set(:@type, "message")

        if hash["message"] || hash[:message]
          instance.instance_variable_set(
            :@message,
            Message.from_hash(hash["message"] || hash[:message])
          )
        end

        instance
      end
    end

    # Base class for await resume payloads.
    #
    # Clients send resume payloads to continue an awaited run
    # with the requested input.
    #
    # @abstract Subclass for specific resume types
    class AwaitResume < Base
      # @!attribute [r] type
      #   @return [String] resume type
      attribute :type, required: true

      # Parse from hash, creating the appropriate subclass.
      #
      # @param hash [Hash, nil] resume payload data
      # @return [AwaitResume, nil] the resume or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        type = hash["type"] || hash[:type]

        case type
        when "message"
          MessageAwaitResume.from_hash(hash)
        else
          super
        end
      end
    end

    # Resume payload containing a message response.
    #
    # Used to provide text or other message input to an awaiting run.
    class MessageAwaitResume < AwaitResume
      # @!attribute [r] message
      #   @return [Message, nil] the client's response message
      attribute :message

      def initialize(**kwargs)
        kwargs[:type] = "message"
        super
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.instance_variable_set(:@type, "message")

        if hash["message"] || hash[:message]
          instance.instance_variable_set(
            :@message,
            Message.from_hash(hash["message"] || hash[:message])
          )
        end

        instance
      end
    end
  end
end
