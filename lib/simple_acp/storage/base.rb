# frozen_string_literal: true

module SimpleAcp
  module Storage
    # Abstract base class for storage backends
    class Base
      def initialize(options = {})
        @options = options
      end

      # Run storage

      def get_run(run_id)
        raise NotImplementedError, "#{self.class}#get_run must be implemented"
      end

      def save_run(run)
        raise NotImplementedError, "#{self.class}#save_run must be implemented"
      end

      def delete_run(run_id)
        raise NotImplementedError, "#{self.class}#delete_run must be implemented"
      end

      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
        raise NotImplementedError, "#{self.class}#list_runs must be implemented"
      end

      # Session storage

      def get_session(session_id)
        raise NotImplementedError, "#{self.class}#get_session must be implemented"
      end

      def save_session(session)
        raise NotImplementedError, "#{self.class}#save_session must be implemented"
      end

      def delete_session(session_id)
        raise NotImplementedError, "#{self.class}#delete_session must be implemented"
      end

      # Event storage

      def add_event(run_id, event)
        raise NotImplementedError, "#{self.class}#add_event must be implemented"
      end

      def get_events(run_id, limit: 100, offset: 0)
        raise NotImplementedError, "#{self.class}#get_events must be implemented"
      end

      # Lifecycle

      def close
        # Override in subclasses if needed
      end

      def ping
        true
      end
    end
  end
end
