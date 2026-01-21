# frozen_string_literal: true

module SimpleAcp
  module Storage
    # Redis-backed storage for distributed deployments.
    #
    # Stores data in Redis with configurable TTL for automatic expiration.
    # Suitable for multi-process or multi-server deployments.
    #
    # @example
    #   storage = SimpleAcp::Storage::Redis.new(
    #     url: "redis://localhost:6379",
    #     ttl: 3600  # 1 hour
    #   )
    #   server = SimpleAcp::Server::Base.new(storage: storage)
    class Redis < Base
      # Default TTL of 24 hours
      DEFAULT_TTL = 86_400

      # Default key prefix
      KEY_PREFIX = "acp:"

      # Initialize Redis storage.
      #
      # @param options [Hash] configuration options
      # @option options [Redis] :redis existing Redis connection
      # @option options [String] :url Redis URL (default: $REDIS_URL or localhost)
      # @option options [Integer] :ttl TTL in seconds (default: 86400)
      # @option options [String] :prefix key prefix (default: "acp:")
      # @option options [String] :host Redis host
      # @option options [Integer] :port Redis port
      # @option options [Integer] :db Redis database number
      # @option options [String] :password Redis password
      # @option options [Boolean] :ssl use SSL
      def initialize(options = {})
        super
        @redis = options[:redis] || connect_redis(options)
        @ttl = options[:ttl] || DEFAULT_TTL
        @prefix = options[:prefix] || KEY_PREFIX
      end

      # @see Base#get_run
      def get_run(run_id)
        data = @redis.get(run_key(run_id))
        return nil unless data

        Models::Run.from_hash(JSON.parse(data))
      end

      # @see Base#save_run
      def save_run(run)
        @redis.setex(run_key(run.run_id), @ttl, run.to_json)

        # Index by agent name
        @redis.sadd(agent_runs_key(run.agent_name), run.run_id)

        # Index by session if present
        if run.session_id
          @redis.sadd(session_runs_key(run.session_id), run.run_id)
        end

        run
      end

      # @see Base#delete_run
      def delete_run(run_id)
        run = get_run(run_id)
        return unless run

        @redis.del(run_key(run_id))
        @redis.del(events_key(run_id))
        @redis.srem(agent_runs_key(run.agent_name), run_id)
        @redis.srem(session_runs_key(run.session_id), run_id) if run.session_id
      end

      # @see Base#list_runs
      def list_runs(agent_name: nil, session_id: nil, limit: 10, offset: 0)
        run_ids = if agent_name
                    @redis.smembers(agent_runs_key(agent_name))
                  elsif session_id
                    @redis.smembers(session_runs_key(session_id))
                  else
                    @redis.keys("#{@prefix}run:*").map { |k| k.sub("#{@prefix}run:", "") }
                  end

        runs = run_ids.filter_map { |id| get_run(id) }
        runs = runs.sort_by { |r| r.created_at || Time.at(0) }.reverse

        {
          runs: runs.drop(offset).take(limit),
          total: runs.length
        }
      end

      # @see Base#get_session
      def get_session(session_id)
        data = @redis.get(session_key(session_id))
        return nil unless data

        Models::Session.from_hash(JSON.parse(data))
      end

      # @see Base#save_session
      def save_session(session)
        @redis.setex(session_key(session.id), @ttl, session.to_json)
        session
      end

      # @see Base#delete_session
      def delete_session(session_id)
        @redis.del(session_key(session_id))
      end

      # @see Base#add_event
      def add_event(run_id, event)
        @redis.rpush(events_key(run_id), event.to_json)
        @redis.expire(events_key(run_id), @ttl)
        event
      end

      # @see Base#get_events
      def get_events(run_id, limit: 100, offset: 0)
        events_data = @redis.lrange(events_key(run_id), offset, offset + limit - 1)
        events_data.map { |data| Models::Events.from_hash(JSON.parse(data)) }
      end

      # @see Base#close
      def close
        @redis.close if @redis.respond_to?(:close)
      end

      # @see Base#ping
      def ping
        @redis.ping == "PONG"
      rescue StandardError
        false
      end

      # Clear all stored data.
      #
      # @return [void]
      def clear!
        keys = @redis.keys("#{@prefix}*")
        @redis.del(*keys) unless keys.empty?
      end

      private

      def connect_redis(options)
        require "redis"
        ::Redis.new(
          url: options[:url] || ENV.fetch("REDIS_URL", "redis://localhost:6379"),
          **options.slice(:host, :port, :db, :password, :ssl)
        )
      end

      def run_key(run_id)
        "#{@prefix}run:#{run_id}"
      end

      def session_key(session_id)
        "#{@prefix}session:#{session_id}"
      end

      def events_key(run_id)
        "#{@prefix}events:#{run_id}"
      end

      def agent_runs_key(agent_name)
        "#{@prefix}agent_runs:#{agent_name}"
      end

      def session_runs_key(session_id)
        "#{@prefix}session_runs:#{session_id}"
      end
    end
  end
end
