# frozen_string_literal: true

module SimpleAcp
  module Server
    # Main ACP Server class for hosting agents and handling requests.
    #
    # The server manages agent registration, run execution (sync, async, stream),
    # session state, and exposes an HTTP API via Roda/Falcon.
    #
    # @example Creating and running a server
    #   server = SimpleAcp::Server::Base.new
    #   server.agent("echo", description: "Echoes input") do |context|
    #     SimpleAcp::Models::Message.agent(context.input.first.text_content)
    #   end
    #   server.run(port: 8000)
    #
    # @example Using custom storage
    #   storage = SimpleAcp::Storage::Redis.new(url: "redis://localhost:6379")
    #   server = SimpleAcp::Server::Base.new(storage: storage)
    class Base
      # @return [Hash<String, Agent>] registered agents indexed by name
      attr_reader :agents

      # @return [Storage::Base] storage backend for runs, sessions, and events
      attr_reader :storage

      # @return [Hash] additional configuration options
      attr_reader :options

      # Initialize a new ACP server.
      #
      # @param storage [Storage::Base, nil] storage backend (defaults to Memory)
      # @param options [Hash] additional configuration options
      def initialize(storage: nil, **options)
        @agents = {}
        @storage = storage || SimpleAcp::Storage::Memory.new
        @options = options
        @running_contexts = Concurrent::Map.new
      end

      # Register an agent using block syntax or decorator-style.
      #
      # @param name [String, nil] agent name (must follow RFC 1123 DNS label format)
      # @param description [String, nil] human-readable description
      # @param options [Hash] additional options
      # @option options [Array<String>] :input_content_types accepted MIME types
      # @option options [Array<String>] :output_content_types produced MIME types
      # @option options [Hash] :metadata agent metadata
      # @yield [Context] block that handles agent requests
      # @return [Agent, Proc] the registered agent or a decorator lambda
      #
      # @example Block syntax
      #   server.agent("greeter", description: "Greets users") do |context|
      #     name = context.input.first&.text_content || "World"
      #     SimpleAcp::Models::Message.agent("Hello, #{name}!")
      #   end
      #
      # @example Streaming agent
      #   server.agent("counter") do |context|
      #     Enumerator.new do |yielder|
      #       3.times { |i| yielder << SimpleAcp::Models::Message.agent("Count: #{i}") }
      #     end
      #   end
      def agent(name = nil, description: nil, **options, &block)
        if block_given?
          # Direct registration with block
          agent_obj = AgentDSL.define(
            name: name,
            description: description,
            **options,
            &block
          )
          register(agent_obj)
          agent_obj
        else
          # Return a lambda for decorator-style usage
          ->(handler) do
            agent_name = name || handler_name(handler)
            agent_obj = Agent.new(
              manifest: Models::AgentManifest.new(
                name: agent_name,
                description: description,
                **options
              ),
              handler: handler
            )
            register(agent_obj)
            handler
          end
        end
      end

      # Register an agent instance directly.
      #
      # @param agent [Agent] the agent to register
      # @return [Agent] the registered agent
      # @raise [ValidationError] if the agent is invalid
      # @raise [ConfigurationError] if an agent with the same name exists
      def register(agent)
        raise SimpleAcp::ValidationError, "Invalid agent" unless agent.valid?
        raise SimpleAcp::ConfigurationError, "Agent '#{agent.name}' already registered" if @agents.key?(agent.name)

        @agents[agent.name] = agent
        agent
      end

      # Unregister an agent by name.
      #
      # @param name [String] the agent name to remove
      # @return [Agent, nil] the removed agent or nil if not found
      def unregister(name)
        @agents.delete(name)
      end

      # Run an agent synchronously, blocking until completion.
      #
      # @param agent_name [String] name of the agent to run
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID for stateful interactions
      # @param session [Models::Session, Hash, nil] optional session data
      # @return [Models::Run] the completed run with output
      # @raise [NotFoundError] if the agent is not found
      def run_sync(agent_name:, input:, session_id: nil, session: nil)
        run, context = prepare_run(agent_name, input, session_id, session)

        begin
          run.start!
          @storage.save_run(run)

          output_messages = []
          execute_agent(context) do |yielded|
            case yielded
            when RunYield
              output_messages << yielded.message
            when RunYieldAwait
              # Agent is awaiting - save state and return
              return run
            end
          end

          run.complete!(output_messages)
          update_session_history(context.session, input, output_messages)
        rescue StandardError => e
          run.fail!(e.message)
        end

        @storage.save_run(run)
        run
      end

      # Run an agent asynchronously, returning immediately with a run ID.
      #
      # The agent executes in a background thread. Use {#cancel_run} to stop
      # or poll the storage to check status.
      #
      # @param agent_name [String] name of the agent to run
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID
      # @param session [Models::Session, Hash, nil] optional session data
      # @return [Models::Run] the run (status will be :created or :in_progress)
      # @raise [NotFoundError] if the agent is not found
      def run_async(agent_name:, input:, session_id: nil, session: nil)
        run, context = prepare_run(agent_name, input, session_id, session)

        Thread.new do
          begin
            run.start!
            @storage.save_run(run)

            output_messages = []
            awaiting = false

            execute_agent(context) do |yielded|
              case yielded
              when RunYield
                output_messages << yielded.message
              when RunYieldAwait
                awaiting = true
                break
              end
            end

            # Check if cancelled or awaiting before completing
            if context.cancelled?
              run.cancelled!
            elsif !awaiting
              run.complete!(output_messages)
              update_session_history(context.session, input, output_messages)
            end
            # If awaiting, run is already in awaiting state from await_message
          rescue StandardError => e
            run.fail!(e.message)
          ensure
            @storage.save_run(run)
            @running_contexts.delete(run.run_id)
          end
        end

        run
      end

      # Run an agent with streaming output via Server-Sent Events.
      #
      # Yields events as the agent executes, enabling real-time response streaming.
      #
      # @param agent_name [String] name of the agent to run
      # @param input [Array<Models::Message>, Models::Message, String] input messages
      # @param session_id [String, nil] optional session ID
      # @param session [Models::Session, Hash, nil] optional session data
      # @yield [Models::Event] events as they occur during execution
      # @yieldparam event [Models::RunCreatedEvent, Models::MessagePartEvent, Models::RunCompletedEvent, etc.]
      # @return [void]
      # @raise [NotFoundError] if the agent is not found
      #
      # @example
      #   server.run_stream(agent_name: "echo", input: "Hello") do |event|
      #     case event
      #     when Models::MessagePartEvent
      #       print event.part.content
      #     when Models::RunCompletedEvent
      #       puts "\nDone!"
      #     end
      #   end
      def run_stream(agent_name:, input:, session_id: nil, session: nil)
        run, context = prepare_run(agent_name, input, session_id, session)

        begin
          yield Models::RunCreatedEvent.new(run: run)
          @storage.add_event(run.run_id, Models::RunCreatedEvent.new(run: run))

          run.start!
          @storage.save_run(run)
          yield Models::RunInProgressEvent.new(run_id: run.run_id)
          @storage.add_event(run.run_id, Models::RunInProgressEvent.new(run_id: run.run_id))

          output_messages = []

          execute_agent(context) do |yielded|
            case yielded
            when RunYield
              message = yielded.message
              output_messages << message

              yield Models::MessageCreatedEvent.new(message: message)
              @storage.add_event(run.run_id, Models::MessageCreatedEvent.new(message: message))

              message.parts.each do |part|
                yield Models::MessagePartEvent.new(part: part)
                @storage.add_event(run.run_id, Models::MessagePartEvent.new(part: part))
              end

              yield Models::MessageCompletedEvent.new(message: message)
              @storage.add_event(run.run_id, Models::MessageCompletedEvent.new(message: message))
            when RunYieldAwait
              yield Models::RunAwaitingEvent.new(run_id: run.run_id, await_request: yielded.request)
              @storage.add_event(run.run_id, Models::RunAwaitingEvent.new(run_id: run.run_id, await_request: yielded.request))
              return
            end
          end

          run.complete!(output_messages)
          update_session_history(context.session, input, output_messages)

          yield Models::RunCompletedEvent.new(run: run)
          @storage.add_event(run.run_id, Models::RunCompletedEvent.new(run: run))
        rescue StandardError => e
          run.fail!(e.message)
          yield Models::RunFailedEvent.new(run_id: run.run_id, error: run.error)
          @storage.add_event(run.run_id, Models::RunFailedEvent.new(run_id: run.run_id, error: run.error))
        ensure
          @storage.save_run(run)
          @running_contexts.delete(run.run_id)
        end
      end

      # Resume an awaited run synchronously.
      #
      # When an agent yields a {RunYieldAwait}, the run enters an "awaiting" state.
      # Use this method to provide the requested input and continue execution.
      #
      # @param run_id [String] the run ID to resume
      # @param await_resume [Models::AwaitResume] the resume payload with client response
      # @return [Models::Run] the completed run
      # @raise [NotFoundError] if the run is not found
      # @raise [ValidationError] if the run is not in awaiting state
      def resume_sync(run_id:, await_resume:)
        run, context = prepare_resume(run_id, await_resume)

        begin
          run.start!
          @storage.save_run(run)

          output_messages = run.output.dup

          execute_agent(context) do |yielded|
            case yielded
            when RunYield
              output_messages << yielded.message
            when RunYieldAwait
              return run
            end
          end

          run.complete!(output_messages)
          update_session_history(context.session, [await_resume.message].compact, output_messages)
        rescue StandardError => e
          run.fail!(e.message)
        end

        @storage.save_run(run)
        run
      end

      # Resume an awaited run with streaming output.
      #
      # @param run_id [String] the run ID to resume
      # @param await_resume [Models::AwaitResume] the resume payload with client response
      # @yield [Models::Event] events as they occur during execution
      # @return [void]
      # @raise [NotFoundError] if the run is not found
      # @raise [ValidationError] if the run is not in awaiting state
      def resume_stream(run_id:, await_resume:)
        run, context = prepare_resume(run_id, await_resume)

        begin
          run.start!
          @storage.save_run(run)
          yield Models::RunInProgressEvent.new(run_id: run.run_id)
          @storage.add_event(run.run_id, Models::RunInProgressEvent.new(run_id: run.run_id))

          output_messages = run.output.dup

          execute_agent(context) do |yielded|
            case yielded
            when RunYield
              message = yielded.message
              output_messages << message

              yield Models::MessageCreatedEvent.new(message: message)
              @storage.add_event(run.run_id, Models::MessageCreatedEvent.new(message: message))

              yield Models::MessageCompletedEvent.new(message: message)
              @storage.add_event(run.run_id, Models::MessageCompletedEvent.new(message: message))
            when RunYieldAwait
              yield Models::RunAwaitingEvent.new(run_id: run.run_id, await_request: yielded.request)
              @storage.add_event(run.run_id, Models::RunAwaitingEvent.new(run_id: run.run_id, await_request: yielded.request))
              return
            end
          end

          run.complete!(output_messages)
          yield Models::RunCompletedEvent.new(run: run)
          @storage.add_event(run.run_id, Models::RunCompletedEvent.new(run: run))
        rescue StandardError => e
          run.fail!(e.message)
          yield Models::RunFailedEvent.new(run_id: run.run_id, error: run.error)
          @storage.add_event(run.run_id, Models::RunFailedEvent.new(run_id: run.run_id, error: run.error))
        ensure
          @storage.save_run(run)
          @running_contexts.delete(run.run_id)
        end
      end

      # Cancel a running agent execution.
      #
      # @param run_id [String] the run ID to cancel
      # @return [Models::Run] the cancelled run
      # @raise [NotFoundError] if the run is not found
      def cancel_run(run_id)
        run = @storage.get_run(run_id)
        raise SimpleAcp::NotFoundError, "Run '#{run_id}' not found" unless run

        context = @running_contexts[run_id]
        context&.cancel!

        run.cancelled!
        @storage.save_run(run)
        run
      end

      # Create a Rack-compatible application.
      #
      # @return [Roda] the Rack application
      def to_app
        # Create a subclass to avoid freezing the base App class
        app_class = Class.new(App)
        app_class.configure(self)
        app_class.freeze.app
      end

      # Start the HTTP server using Falcon.
      #
      # Falcon provides fiber-based concurrency for efficient handling
      # of SSE streams and long-lived connections.
      #
      # @param port [Integer] port to listen on (default: 8000)
      # @param host [String] host to bind to (default: "0.0.0.0")
      # @param options [Hash] additional Falcon configuration options
      # @return [void]
      def run(port: 8000, host: "0.0.0.0", **options)
        require_relative "falcon_runner"

        app = to_app

        puts "Registered agents: #{@agents.keys.join(', ')}"

        FalconRunner.run(app, port: port, host: host, **options)
      end

      private

      def prepare_run(agent_name, input, session_id, session_data)
        agent = @agents[agent_name]
        raise SimpleAcp::NotFoundError, "Agent '#{agent_name}' not found" unless agent

        session = resolve_session(session_id, session_data)

        run = Models::Run.new(
          agent_name: agent_name,
          session_id: session&.id
        )
        @storage.save_run(run)

        context = Context.new(
          run: run,
          session: session,
          input: input,
          server: self
        )
        @running_contexts[run.run_id] = context

        [run, context]
      end

      def prepare_resume(run_id, await_resume)
        run = @storage.get_run(run_id)
        raise SimpleAcp::NotFoundError, "Run '#{run_id}' not found" unless run
        raise SimpleAcp::ValidationError, "Run is not awaiting" unless run.awaiting?

        session = run.session_id ? @storage.get_session(run.session_id) : nil

        context = ResumeContext.new(
          run: run,
          session: session,
          input: [],
          server: self,
          await_resume: await_resume
        )
        @running_contexts[run.run_id] = context

        [run, context]
      end

      def resolve_session(session_id, session_data)
        if session_data
          session = Models::Session.from_hash(session_data.is_a?(Hash) ? session_data : session_data.to_h)
          @storage.save_session(session)
          session
        elsif session_id
          @storage.get_session(session_id) || begin
            session = Models::Session.new(id: session_id)
            @storage.save_session(session)
            session
          end
        end
      end

      def execute_agent(context)
        agent = @agents[context.agent_name]
        return unless agent

        result = agent.call(context)

        if result.respond_to?(:each)
          result.each do |item|
            break if context.cancelled?

            case item
            when RunYield, RunYieldAwait
              yield item
            when Models::Message
              yield RunYield.new(item)
            when String
              yield RunYield.new(Models::Message.agent(item))
            end
          end
        end
      end

      def update_session_history(session, input, output)
        return unless session

        Array(input).each { |msg| session.add_to_history(msg) }
        Array(output).each { |msg| session.add_to_history(msg) }
        @storage.save_session(session)
      end

      def handler_name(handler)
        case handler
        when Method
          handler.name.to_s
        when Proc
          "anonymous_agent"
        else
          handler.class.name.downcase.gsub("::", "_")
        end
      end
    end
  end
end
