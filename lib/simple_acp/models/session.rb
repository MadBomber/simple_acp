# frozen_string_literal: true

module SimpleAcp
  module Models
    # Maintains state and conversation history across interactions.
    #
    # Sessions allow agents to maintain context between requests,
    # storing both conversation history and arbitrary state data.
    #
    # @example Using sessions with the client
    #   client.use_session("my-session")
    #   client.run_sync(agent: "counter", input: "increment")  # Count: 1
    #   client.run_sync(agent: "counter", input: "increment")  # Count: 2
    class Session < Base
      # @!attribute [r] id
      #   @return [String] unique session ID
      attribute :id, required: true

      # @!attribute [r] history
      #   @return [Array<Message>] conversation history
      attribute :history, default: -> { [] }

      # @!attribute [r] state
      #   @return [Object, nil] arbitrary state data
      attribute :state

      def initialize(**kwargs)
        super
        @id ||= Types.generate_uuid
        @history ||= []
      end

      # Create from a hash (JSON deserialization).
      #
      # @param hash [Hash, nil] session data
      # @return [Session, nil] the session or nil
      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a new session with a generated ID.
      #
      # @return [Session] new session
      def self.create
        new(id: Types.generate_uuid)
      end

      # Add a message to the conversation history.
      #
      # @param message [Message, Hash] the message to add
      # @return [self] for chaining
      def add_to_history(message)
        @history << (message.is_a?(Message) ? message : Message.from_hash(message))
        self
      end

      # Clear all conversation history.
      #
      # @return [self] for chaining
      def clear_history!
        @history = []
        self
      end

      # Set the session state.
      #
      # @param state_data [Object] arbitrary state data
      # @return [self] for chaining
      def set_state(state_data)
        @state = state_data
        self
      end

      # Clear the session state.
      #
      # @return [self] for chaining
      def clear_state!
        @state = nil
        self
      end

      # Get the number of messages in history.
      #
      # @return [Integer] message count
      def message_count
        @history.length
      end

      # Check if the session has no history or state.
      #
      # @return [Boolean] true if no history and no state
      def empty?
        @history.empty? && @state.nil?
      end

      # Validate the session.
      #
      # @return [Boolean] true if ID is a valid UUID
      def valid?
        Types.valid_uuid?(@id)
      end

      private

      def initialize_from_hash(hash)
        @id = hash["id"] || hash[:id]
        @state = hash["state"] || hash[:state]

        history_data = hash["history"] || hash[:history] || []
        @history = history_data.map do |item|
          item.is_a?(Message) ? item : Message.from_hash(item)
        end
      end
    end

    # Response for getting session details
    class SessionResponse < Base
      attribute :id
      attribute :history_count
      attribute :has_state
      attribute :created_at

      def self.from_session(session)
        new(
          id: session.id,
          history_count: session.history.length,
          has_state: !session.state.nil?,
          created_at: Time.now
        )
      end
    end
  end
end
