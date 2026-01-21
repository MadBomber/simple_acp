# frozen_string_literal: true

module SimpleAcp
  module Models
    # Fundamental communication structure in ACP.
    #
    # Messages represent units of communication between users and agents,
    # containing one or more parts (text, JSON, images, etc.).
    #
    # @example Creating a simple text message
    #   msg = Message.user("Hello, world!")
    #
    # @example Creating a message with multiple parts
    #   msg = Message.agent(
    #     MessagePart.text("Here's the data:"),
    #     MessagePart.json({ count: 42 })
    #   )
    class Message < Base
      # @!attribute [r] role
      #   @return [String] "user" or "agent" (or "agent/name")
      attribute :role, required: true

      # @!attribute [r] parts
      #   @return [Array<MessagePart>] content parts
      attribute :parts, default: -> { [] }

      # @!attribute [r] created_at
      #   @return [Time, nil] when the message was created
      attribute :created_at

      # @!attribute [r] completed_at
      #   @return [Time, nil] when the message was completed
      attribute :completed_at

      def initialize(**kwargs)
        super
        @parts ||= []
        @created_at ||= Time.now
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash, nil] message data
      # @return [Message, nil] the message or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a user message from content.
      #
      # @param contents [Array<String, MessagePart, Hash>] message content
      # @return [Message] the user message
      #
      # @example
      #   Message.user("Hello!")
      #   Message.user(MessagePart.text("Hello"), MessagePart.json({key: "value"}))
      def self.user(*contents)
        parts = contents.map do |content|
          case content
          when MessagePart
            content
          when String
            MessagePart.text(content)
          when Hash
            MessagePart.from_hash(content)
          else
            MessagePart.json(content)
          end
        end

        new(role: Types::Role::USER, parts: parts)
      end

      # Create an agent message from content.
      #
      # @param contents [Array<String, MessagePart, Hash>] message content
      # @return [Message] the agent message
      #
      # @example
      #   Message.agent("Hello, I'm your assistant!")
      def self.agent(*contents)
        parts = contents.map do |content|
          case content
          when MessagePart
            content
          when String
            MessagePart.text(content)
          when Hash
            MessagePart.from_hash(content)
          else
            MessagePart.json(content)
          end
        end

        new(role: Types::Role::AGENT, parts: parts)
      end

      # Check if this is a user message.
      #
      # @return [Boolean] true if role is "user"
      def user?
        @role == Types::Role::USER
      end

      # Check if this is an agent message.
      #
      # @return [Boolean] true if role is "agent" or starts with "agent/"
      def agent?
        @role == Types::Role::AGENT || @role.to_s.start_with?("agent/")
      end

      # Get the agent name if this is a named agent message.
      #
      # @return [String, nil] agent name extracted from "agent/name" role
      def agent_name
        return nil unless agent?

        if @role.to_s.start_with?("agent/")
          @role.to_s.sub("agent/", "")
        end
      end

      # Add a part to this message.
      #
      # @param part [MessagePart, Hash] the part to add
      # @return [self] for chaining
      def add_part(part)
        @parts << (part.is_a?(MessagePart) ? part : MessagePart.from_hash(part))
        self
      end

      # Mark the message as completed.
      #
      # @return [self] for chaining
      def complete!
        @completed_at = Time.now
        self
      end

      # Check if the message is completed.
      #
      # @return [Boolean] true if completed_at is set
      def completed?
        !@completed_at.nil?
      end

      # Combine two messages by appending parts.
      #
      # @param other [Message] message to append
      # @return [Message] new combined message
      def +(other)
        combined = self.class.new(role: @role, parts: @parts.dup)
        other.parts.each { |p| combined.add_part(p) }
        combined
      end

      # Get combined text content from all text parts.
      #
      # @return [String] concatenated text content
      def text_content
        @parts.select(&:text?).map(&:content).join("\n")
      end

      # Create a new message with adjacent text parts combined.
      #
      # @return [Message] compressed message
      def compress
        return self if @parts.length <= 1

        compressed_parts = []
        current_text = nil

        @parts.each do |part|
          if part.text? && !part.base64_encoded?
            if current_text
              current_text = MessagePart.text("#{current_text.content}\n#{part.content}")
            else
              current_text = part.dup
            end
          else
            compressed_parts << current_text if current_text
            current_text = nil
            compressed_parts << part
          end
        end

        compressed_parts << current_text if current_text

        self.class.new(role: @role, parts: compressed_parts, created_at: @created_at)
      end

      # Validate the message.
      #
      # @return [Boolean] true if role is valid, has parts, and all parts are valid
      def valid?
        return false unless Types::Role.valid?(@role)
        return false if @parts.empty?
        return false unless @parts.all?(&:valid?)

        true
      end

      # Convert to string representation.
      #
      # @return [String] concatenated string representation of all parts
      def to_s
        @parts.map(&:to_s).join("\n")
      end

      private

      def initialize_from_hash(hash)
        @role = hash["role"] || hash[:role]
        @created_at = parse_time(hash["created_at"] || hash[:created_at])
        @completed_at = parse_time(hash["completed_at"] || hash[:completed_at])

        parts_data = hash["parts"] || hash[:parts] || []
        @parts = parts_data.map { |p| MessagePart.from_hash(p) }
      end

      def parse_time(value)
        return nil if value.nil?
        return value if value.is_a?(Time)

        Time.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end
  end
end
