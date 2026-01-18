# frozen_string_literal: true

module SimpleAcp
  module Models
    # Base class for await requests
    class AwaitRequest < Base
      attribute :type, required: true

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

    # Request for a message from the client
    class MessageAwaitRequest < AwaitRequest
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

    # Base class for await resume payloads
    class AwaitResume < Base
      attribute :type, required: true

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

    # Resume payload with a message
    class MessageAwaitResume < AwaitResume
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
