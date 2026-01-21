# frozen_string_literal: true

require "concurrent"

module SimpleAcp
  module Storage
    # Thread-safe in-memory storage backend.
    #
    # This is the default storage backend. Data is lost when the process exits.
    # Uses concurrent-ruby for thread safety.
    #
    # @example
    #   storage = SimpleAcp::Storage::Memory.new
    #   server = SimpleAcp::Server::Base.new(storage: storage)
    class Memory < Base
      def initialize(options = {})
        super
        @runs = Concurrent::Map.new
        @sessions = Concurrent::Map.new
        @events = Concurrent::Map.new
        @mutex = Mutex.new
      end

      # @see Base#get_run
      def get_run(run_id)
        @runs[run_id]
      end

      # @see Base#save_run
      def save_run(run)
        @runs[run.run_id] = run
        run
      end

      # @see Base#delete_run
      def delete_run(run_id)
        @events.delete(run_id)
        @runs.delete(run_id)
      end

      # @see Base#list_runs
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

      # @see Base#get_session
      def get_session(session_id)
        @sessions[session_id]
      end

      # @see Base#save_session
      def save_session(session)
        @sessions[session.id] = session
        session
      end

      # @see Base#delete_session
      def delete_session(session_id)
        @sessions.delete(session_id)
      end

      # @see Base#add_event
      def add_event(run_id, event)
        @mutex.synchronize do
          @events[run_id] ||= []
          @events[run_id] << event
        end
        event
      end

      # @see Base#get_events
      def get_events(run_id, limit: 100, offset: 0)
        events = @events[run_id] || []
        events.drop(offset).take(limit)
      end

      # Clear all stored data.
      #
      # @return [void]
      def clear!
        @runs.clear
        @sessions.clear
        @events.clear
      end

      # Get storage statistics.
      #
      # @return [Hash] counts of runs, sessions, and events
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
