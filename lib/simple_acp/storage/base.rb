# frozen_string_literal: true

module SimpleAcp
  module Storage
    # Abstract base class for storage backends.
    #
    # Defines the interface for storing runs, sessions, and events.
    # Implementations include Memory, Redis, and PostgreSQL.
    #
    # @abstract Subclass and implement all methods
    #
    # @example Custom storage backend
    #   class MyStorage < SimpleAcp::Storage::Base
    #     def get_run(run_id)
    #       # ...
    #     end
    #     # ... implement other methods
    #   end
    class Base
      # Initialize the storage backend.
      #
      # @param options [Hash] backend-specific options
      def initialize(options = {})
        @options = options
      end

      # Retrieve a run by ID.
      #
      # @param run_id [String] the run ID
      # @return [Models::Run, nil] the run or nil if not found
      # @raise [NotImplementedError] if not implemented
      def get_run(run_id)
        raise NotImplementedError, "#{self.class}#get_run must be implemented"
      end

      # Save a run.
      #
      # @param run [Models::Run] the run to save
      # @return [Models::Run] the saved run
      # @raise [NotImplementedError] if not implemented
      def save_run(run)
        raise NotImplementedError, "#{self.class}#save_run must be implemented"
      end

      # Delete a run.
      #
      # @param run_id [String] the run ID to delete
      # @return [void]
      # @raise [NotImplementedError] if not implemented
      def delete_run(run_id)
        raise NotImplementedError, "#{self.class}#delete_run must be implemented"
      end

      # List runs with optional filtering.
      #
      # @param agent_name [String, nil] filter by agent name
      # @param session_id [String, nil] filter by session ID
      # @param limit [Integer] maximum number to return (default: 10)
      # @param offset [Integer] number to skip (default: 0)
      # @return [Hash] with :runs and :total keys
      # @raise [NotImplementedError] if not implemented
      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
        raise NotImplementedError, "#{self.class}#list_runs must be implemented"
      end

      # Retrieve a session by ID.
      #
      # @param session_id [String] the session ID
      # @return [Models::Session, nil] the session or nil if not found
      # @raise [NotImplementedError] if not implemented
      def get_session(session_id)
        raise NotImplementedError, "#{self.class}#get_session must be implemented"
      end

      # Save a session.
      #
      # @param session [Models::Session] the session to save
      # @return [Models::Session] the saved session
      # @raise [NotImplementedError] if not implemented
      def save_session(session)
        raise NotImplementedError, "#{self.class}#save_session must be implemented"
      end

      # Delete a session.
      #
      # @param session_id [String] the session ID to delete
      # @return [void]
      # @raise [NotImplementedError] if not implemented
      def delete_session(session_id)
        raise NotImplementedError, "#{self.class}#delete_session must be implemented"
      end

      # Add an event to a run.
      #
      # @param run_id [String] the run ID
      # @param event [Models::Event] the event to add
      # @return [Models::Event] the added event
      # @raise [NotImplementedError] if not implemented
      def add_event(run_id, event)
        raise NotImplementedError, "#{self.class}#add_event must be implemented"
      end

      # Get events for a run.
      #
      # @param run_id [String] the run ID
      # @param limit [Integer] maximum number to return (default: 100)
      # @param offset [Integer] number to skip (default: 0)
      # @return [Array<Models::Event>] list of events
      # @raise [NotImplementedError] if not implemented
      def get_events(run_id, limit: 100, offset: 0)
        raise NotImplementedError, "#{self.class}#get_events must be implemented"
      end

      # Close the storage connection.
      #
      # @return [void]
      def close
        # Override in subclasses if needed
      end

      # Check if the storage is accessible.
      #
      # @return [Boolean] true if accessible
      def ping
        true
      end
    end
  end
end
