# frozen_string_literal: true

module SimpleAcp
  module Models
    # Maintains state and conversation history across interactions
    class Session < Base
      attribute :id, required: true
      attribute :history, default: -> { [] }
      attribute :state

      def initialize(**kwargs)
        super
        @id ||= Types.generate_uuid
        @history ||= []
      end

      def self.from_hash(hash)
        return nil if hash.nil?

        instance = allocate
        instance.send(:initialize_from_hash, hash)
        instance
      end

      # Create a new session with a generated ID
      def self.create
        new(id: Types.generate_uuid)
      end

      def add_to_history(message)
        @history << (message.is_a?(Message) ? message : Message.from_hash(message))
        self
      end

      def clear_history!
        @history = []
        self
      end

      def set_state(state_data)
        @state = state_data
        self
      end

      def clear_state!
        @state = nil
        self
      end

      def message_count
        @history.length
      end

      def empty?
        @history.empty? && @state.nil?
      end

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
