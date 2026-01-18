# frozen_string_literal: true

module SimpleAcp
  module Storage
    # PostgreSQL-backed storage for persistent deployments
    class PostgreSQL < Base
      def initialize(options = {})
        super
        @db = options[:db] || connect_db(options)
        setup_tables unless options[:skip_setup]
      end

      # Run storage

      def get_run(run_id)
        row = @db[:acp_runs].where(run_id: run_id).first
        return nil unless row

        deserialize_run(row)
      end

      def save_run(run)
        data = {
          run_id: run.run_id,
          agent_name: run.agent_name,
          session_id: run.session_id,
          status: run.status,
          output: run.output.to_json,
          error: run.error&.to_json,
          await_request: run.await_request&.to_json,
          created_at: run.created_at,
          finished_at: run.finished_at,
          updated_at: Time.now
        }

        if @db[:acp_runs].where(run_id: run.run_id).count.positive?
          @db[:acp_runs].where(run_id: run.run_id).update(data)
        else
          @db[:acp_runs].insert(data)
        end

        run
      end

      def delete_run(run_id)
        @db[:acp_events].where(run_id: run_id).delete
        @db[:acp_runs].where(run_id: run_id).delete
      end

      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
        dataset = @db[:acp_runs]
        dataset = dataset.where(agent_name: agent_name) if agent_name
        dataset = dataset.where(session_id: session_id) if session_id

        total = dataset.count
        rows = dataset.order(Sequel.desc(:created_at)).limit(limit).offset(offset).all

        {
          runs: rows.map { |row| deserialize_run(row) },
          total: total
        }
      end

      # Session storage

      def get_session(session_id)
        row = @db[:acp_sessions].where(id: session_id).first
        return nil unless row

        deserialize_session(row)
      end

      def save_session(session)
        data = {
          id: session.id,
          history: session.history.to_json,
          state: session.state&.to_json,
          updated_at: Time.now
        }

        if @db[:acp_sessions].where(id: session.id).count.positive?
          @db[:acp_sessions].where(id: session.id).update(data)
        else
          data[:created_at] = Time.now
          @db[:acp_sessions].insert(data)
        end

        session
      end

      def delete_session(session_id)
        @db[:acp_sessions].where(id: session_id).delete
      end

      # Event storage

      def add_event(run_id, event)
        @db[:acp_events].insert(
          run_id: run_id,
          event_type: event.type,
          data: event.to_json,
          created_at: Time.now
        )
        event
      end

      def get_events(run_id, limit: 100, offset: 0)
        rows = @db[:acp_events]
          .where(run_id: run_id)
          .order(:created_at)
          .limit(limit)
          .offset(offset)
          .all

        rows.map { |row| Models::Events.from_hash(JSON.parse(row[:data])) }
      end

      # Lifecycle

      def close
        @db.disconnect if @db.respond_to?(:disconnect)
      end

      def ping
        @db.test_connection
      rescue StandardError
        false
      end

      def clear!
        @db[:acp_events].delete
        @db[:acp_runs].delete
        @db[:acp_sessions].delete
      end

      private

      def connect_db(options)
        require "sequel"
        Sequel.connect(
          options[:url] || ENV.fetch("DATABASE_URL", "postgres://localhost/acp"),
          **options.slice(:host, :port, :database, :user, :password)
        )
      end

      def setup_tables
        @db.create_table?(:acp_runs) do
          String :run_id, primary_key: true
          String :agent_name, null: false, index: true
          String :session_id, index: true
          String :status, null: false
          Text :output
          Text :error
          Text :await_request
          DateTime :created_at
          DateTime :finished_at
          DateTime :updated_at
        end

        @db.create_table?(:acp_sessions) do
          String :id, primary_key: true
          Text :history
          Text :state
          DateTime :created_at
          DateTime :updated_at
        end

        @db.create_table?(:acp_events) do
          primary_key :id
          String :run_id, null: false, index: true
          String :event_type, null: false
          Text :data
          DateTime :created_at
        end
      end

      def deserialize_run(row)
        output = row[:output] ? JSON.parse(row[:output]).map { |m| Models::Message.from_hash(m) } : []
        error = row[:error] ? Models::Error.from_hash(JSON.parse(row[:error])) : nil
        await_request = row[:await_request] ? Models::AwaitRequest.from_hash(JSON.parse(row[:await_request])) : nil

        run = Models::Run.new(
          run_id: row[:run_id],
          agent_name: row[:agent_name],
          session_id: row[:session_id],
          status: row[:status]
        )
        run.instance_variable_set(:@output, output)
        run.instance_variable_set(:@error, error)
        run.instance_variable_set(:@await_request, await_request)
        run.instance_variable_set(:@created_at, row[:created_at])
        run.instance_variable_set(:@finished_at, row[:finished_at])
        run
      end

      def deserialize_session(row)
        history = row[:history] ? JSON.parse(row[:history]).map { |m| Models::Message.from_hash(m) } : []
        state = row[:state] ? JSON.parse(row[:state]) : nil

        session = Models::Session.new(id: row[:id])
        session.instance_variable_set(:@history, history)
        session.instance_variable_set(:@state, state)
        session
      end
    end
  end
end
