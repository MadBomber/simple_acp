# frozen_string_literal: true

require "concurrent"

module SimpleAcp
  module Storage
    # Thread-safe in-memory storage backend
    class Memory < Base
      def initialize(options = {})
        super
        @runs = Concurrent::Map.new
        @sessions = Concurrent::Map.new
        @events = Concurrent::Map.new
        @mutex = Mutex.new
      end

      # Run storage

      def get_run(run_id)
        @runs[run_id]
      end

      def save_run(run)
        @runs[run.run_id] = run
        run
      end

      def delete_run(run_id)
        @events.delete(run_id)
        @runs.delete(run_id)
      end

      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
        runs = @runs.values

        runs = runs.select { |r| r.agent_name == agent_name } if agent_name
        runs = runs.select { |r| r.session_id == session_id } if session_id

        runs = runs.sort_by { |r| r.created_at || Time.at(0) }.reverse

        {
          runs: runs.drop(offset).take(limit),
          total: runs.length
        }
      end

      # Session storage

      def get_session(session_id)
        @sessions[session_id]
      end

      def save_session(session)
        @sessions[session.id] = session
        session
      end

      def delete_session(session_id)
        @sessions.delete(session_id)
      end

      # Event storage

      def add_event(run_id, event)
        @mutex.synchronize do
          @events[run_id] ||= []
          @events[run_id] << event
        end
        event
      end

      def get_events(run_id, limit: 100, offset: 0)
        events = @events[run_id] || []
        events.drop(offset).take(limit)
      end

      # Lifecycle

      def clear!
        @runs.clear
        @sessions.clear
        @events.clear
      end

      def stats
        {
          runs: @runs.size,
          sessions: @sessions.size,
          events: @events.values.sum(&:length)
        }
      end
    end
  end
end
