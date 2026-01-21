# frozen_string_literal: true

require "faraday"
require "json"

module SimpleAcp
  module Client
    # HTTP client for communicating with ACP servers.
    #
    # Provides methods for agent discovery, run execution (sync, async, stream),
    # run management, and session handling.
    #
    # @example Basic usage
    #   client = SimpleAcp::Client::Base.new(base_url: "http://localhost:8000")
    #   run = client.run_sync(agent: "echo", input: "Hello!")
    #   puts run.output.first.text_content
    #
    # @example Streaming
    #   client.run_stream(agent: "echo", input: "Hello") do |event|
    #     case event
    #     when Models::MessagePartEvent
    #       print event.part.content
    #     end
    #   end
    #
    # @example With session
    #   client.use_session("my-session-id")
    #   client.run_sync(agent: "counter", input: "increment")
    class Base
      # @return [String] the base URL of the ACP server
      attr_reader :base_url

      # Create a new ACP client.
      #
      # @param base_url [String] the base URL of the ACP server
      # @param options [Hash] additional options
      # @option options [Hash] :headers custom HTTP headers
      # @option options [Array] :auth authentication credentials for Faraday
      # @option options [Integer] :timeout request timeout in seconds (default: 30)
      # @option options [Integer] :open_timeout connection timeout in seconds (default: 10)
      def initialize(base_url:, **options)
        @base_url = base_url.chomp("/")
        @options = options
        @session_id = nil
        @connection = build_connection
      end

      # Check if the server is reachable.
      #
      # @return [Boolean] true if server responds to ping
      def ping
        response = @connection.get("/ping")
        handle_response(response)
        true
      rescue StandardError
        false
      end

      # List available agents on the server.
      #
      # @param limit [Integer] maximum number of agents to return (default: 10)
      # @param offset [Integer] number of agents to skip (default: 0)
      # @return [Models::AgentListResponse] list of agent manifests
      def agents(limit: 10, offset: 0)
        response = @connection.get("/agents") do |req|
          req.params["limit"] = limit
          req.params["offset"] = offset
        end

        data = handle_response(response)
        Models::AgentListResponse.from_hash(data)
      end

      # Get a specific agent's manifest.
      #
      # @param name [String] the agent name
      # @return [Models::AgentManifest] the agent's manifest
      # @raise [NotFoundError] if the agent does not exist
      def agent(name)
        response = @connection.get("/agents/#{name}")
        data = handle_response(response)
        Models::AgentManifest.from_hash(data)
      end

      # Run an agent synchronously, blocking until completion.
      #
      # @param agent [String] the agent name
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID
      # @return [Models::Run] the completed run with output
      # @raise [NotFoundError] if the agent does not exist
      def run_sync(agent:, input:, session_id: nil)
        input_messages = normalize_input(input)

        response = @connection.post("/runs") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = {
            agent_name: agent,
            input: input_messages.map(&:to_h),
            mode: Models::Types::RunMode::SYNC,
            session_id: session_id || @session_id
          }.to_json
        end

        data = handle_response(response)
        run = Models::Run.from_hash(data)
        @session_id = run.session_id if run.session_id
        run
      end

      # Run an agent asynchronously, returning immediately.
      #
      # Use {#run_status} or {#wait_for_run} to check completion.
      #
      # @param agent [String] the agent name
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID
      # @return [Models::Run] the run (status will be :created or :in_progress)
      # @raise [NotFoundError] if the agent does not exist
      def run_async(agent:, input:, session_id: nil)
        input_messages = normalize_input(input)

        response = @connection.post("/runs") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = {
            agent_name: agent,
            input: input_messages.map(&:to_h),
            mode: Models::Types::RunMode::ASYNC,
            session_id: session_id || @session_id
          }.to_json
        end

        data = handle_response(response)
        run = Models::Run.from_hash(data)
        @session_id = run.session_id if run.session_id
        run
      end

      # Run an agent with streaming response via Server-Sent Events.
      #
      # @param agent [String] the agent name
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID
      # @yield [Models::Event] events as they occur
      # @return [Enumerator<Models::Event>] if no block given
      # @raise [NotFoundError] if the agent does not exist
      #
      # @example With block
      #   client.run_stream(agent: "echo", input: "Hello") do |event|
      #     puts event.class.name
      #   end
      #
      # @example As enumerator
      #   events = client.run_stream(agent: "echo", input: "Hello")
      #   events.each { |e| puts e }
      def run_stream(agent:, input:, session_id: nil, &block)
        input_messages = normalize_input(input)

        if block_given?
          run_stream_with_block(agent, input_messages, session_id, &block)
        else
          run_stream_enumerable(agent, input_messages, session_id)
        end
      end

      # Get the current status of a run.
      #
      # @param run_id [String] the run ID
      # @return [Models::Run] the run with current status
      # @raise [NotFoundError] if the run does not exist
      def run_status(run_id)
        response = @connection.get("/runs/#{run_id}")
        data = handle_response(response)
        Models::Run.from_hash(data)
      end

      # Get events that occurred during a run.
      #
      # @param run_id [String] the run ID
      # @param limit [Integer] maximum number of events to return (default: 100)
      # @param offset [Integer] number of events to skip (default: 0)
      # @return [Array<Models::Event>] list of events
      def run_events(run_id, limit: 100, offset: 0)
        response = @connection.get("/runs/#{run_id}/events") do |req|
          req.params["limit"] = limit
          req.params["offset"] = offset
        end

        data = handle_response(response)
        (data["events"] || []).map { |e| Models::Events.from_hash(e) }
      end

      # Cancel a running agent execution.
      #
      # @param run_id [String] the run ID to cancel
      # @return [Models::Run] the cancelled run
      # @raise [NotFoundError] if the run does not exist
      def run_cancel(run_id)
        response = @connection.post("/runs/#{run_id}/cancel")
        data = handle_response(response)
        Models::Run.from_hash(data)
      end

      # Resume an awaited run synchronously.
      #
      # @param run_id [String] the run ID to resume
      # @param await_resume [Models::AwaitResume] the resume payload with client response
      # @return [Models::Run] the completed run
      # @raise [NotFoundError] if the run does not exist
      # @raise [ValidationError] if the run is not in awaiting state
      def run_resume_sync(run_id:, await_resume:)
        response = @connection.post("/runs/#{run_id}") do |req|
          req.headers["Content-Type"] = "application/json"
          req.body = {
            await_resume: await_resume.to_h,
            mode: Models::Types::RunMode::SYNC
          }.to_json
        end

        data = handle_response(response)
        Models::Run.from_hash(data)
      end

      # Resume an awaited run with streaming output.
      #
      # @param run_id [String] the run ID to resume
      # @param await_resume [Models::AwaitResume] the resume payload with client response
      # @yield [Models::Event] events as they occur
      # @return [Enumerator<Models::Event>] if no block given
      # @raise [NotFoundError] if the run does not exist
      # @raise [ValidationError] if the run is not in awaiting state
      def run_resume_stream(run_id:, await_resume:, &block)
        if block_given?
          resume_stream_with_block(run_id, await_resume, &block)
        else
          resume_stream_enumerable(run_id, await_resume)
        end
      end

      # Get session details.
      #
      # @param session_id [String] the session ID
      # @return [Models::SessionResponse] session information
      # @raise [NotFoundError] if the session does not exist
      def session(session_id)
        response = @connection.get("/session/#{session_id}")
        data = handle_response(response)
        Models::SessionResponse.from_hash(data)
      end

      # Set a session ID for subsequent requests.
      #
      # @param session_id [String] the session ID to use
      # @return [self] for chaining
      def use_session(session_id)
        @session_id = session_id
        self
      end

      # Clear the current session ID.
      #
      # @return [self] for chaining
      def clear_session
        @session_id = nil
        self
      end

      # Poll until a run completes or times out.
      #
      # @param run_id [String] the run ID to wait for
      # @param timeout [Integer] maximum seconds to wait (default: 60)
      # @param interval [Integer] seconds between polls (default: 1)
      # @return [Models::Run] the completed run
      # @raise [Error] if timeout is exceeded
      def wait_for_run(run_id, timeout: 60, interval: 1)
        deadline = Time.now + timeout

        loop do
          run = run_status(run_id)
          return run if run.terminal?

          raise SimpleAcp::Error, "Timeout waiting for run to complete" if Time.now > deadline

          sleep(interval)
        end
      end

      # Close the HTTP connection.
      #
      # @return [void]
      def close
        @connection.close if @connection.respond_to?(:close)
      end

      private

      def build_connection
        Faraday.new(url: @base_url) do |conn|
          conn.headers["Accept"] = "application/json"
          conn.headers["User-Agent"] = "acp-ruby/#{SimpleAcp::VERSION}"

          # Add any custom headers
          @options[:headers]&.each do |key, value|
            conn.headers[key] = value
          end

          # Authentication
          if @options[:auth]
            conn.request :authorization, *@options[:auth]
          end

          # Timeout settings
          conn.options.timeout = @options[:timeout] || 30
          conn.options.open_timeout = @options[:open_timeout] || 10

          conn.adapter Faraday.default_adapter
        end
      end

      def handle_response(response)
        case response.status
        when 200..299
          parse_json(response.body)
        when 404
          error_data = parse_json(response.body)
          raise SimpleAcp::NotFoundError, error_data.dig("error", "message") || "Not found"
        when 400
          error_data = parse_json(response.body)
          raise SimpleAcp::ValidationError, error_data.dig("error", "message") || "Invalid request"
        else
          error_data = parse_json(response.body)
          raise SimpleAcp::Error, error_data.dig("error", "message") || "Request failed with status #{response.status}"
        end
      end

      def parse_json(body)
        return {} if body.nil? || body.empty?

        JSON.parse(body)
      rescue JSON::ParserError
        {}
      end

      def normalize_input(input)
        case input
        when Array
          input.map { |i| normalize_message(i) }
        else
          [normalize_message(input)]
        end
      end

      def normalize_message(msg)
        case msg
        when Models::Message
          msg
        when Models::MessagePart
          Models::Message.user(msg)
        when String
          Models::Message.user(msg)
        when Hash
          Models::Message.from_hash(msg)
        else
          Models::Message.user(msg.to_s)
        end
      end

      def run_stream_with_block(agent, input_messages, session_id)
        stream_request("/runs", {
          agent_name: agent,
          input: input_messages.map(&:to_h),
          mode: Models::Types::RunMode::STREAM,
          session_id: session_id || @session_id
        }) do |event|
          if event.is_a?(Models::RunCompletedEvent) && event.run&.session_id
            @session_id = event.run.session_id
          end
          yield event
        end
      end

      def run_stream_enumerable(agent, input_messages, session_id)
        Enumerator.new do |yielder|
          run_stream_with_block(agent, input_messages, session_id) do |event|
            yielder << event
          end
        end
      end

      def resume_stream_with_block(run_id, await_resume)
        stream_request("/runs/#{run_id}", {
          await_resume: await_resume.to_h,
          mode: Models::Types::RunMode::STREAM
        }) do |event|
          yield event
        end
      end

      def resume_stream_enumerable(run_id, await_resume)
        Enumerator.new do |yielder|
          resume_stream_with_block(run_id, await_resume) do |event|
            yielder << event
          end
        end
      end

      def stream_request(path, body)
        uri = URI.join(@base_url, path)

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
          request = Net::HTTP::Post.new(uri)
          request["Content-Type"] = "application/json"
          request["Accept"] = "text/event-stream"
          request["User-Agent"] = "acp-ruby/#{SimpleAcp::VERSION}"
          request.body = body.to_json

          http.request(request) do |response|
            unless response.is_a?(Net::HTTPSuccess)
              raise SimpleAcp::Error, "Stream request failed with status #{response.code}"
            end

            parser = SSEParser.new

            response.read_body do |chunk|
              parser.feed(chunk)
              parser.each_event do |raw_event|
                event = parse_sse_event(raw_event)
                yield event if event

                # Check for error events
                if event.is_a?(Models::ErrorEvent)
                  raise SimpleAcp::RunError, event.error&.message || "Unknown error"
                end
              end
            end
          end
        end
      end

      def parse_sse_event(raw_event)
        data = JSON.parse(raw_event[:data])
        Models::Events.from_hash(data)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
