# frozen_string_literal: true

module SimpleAcp
  module Server
    # Main ACP Server class
    class Base
      attr_reader :agents, :storage, :options

      def initialize(storage: nil, **options)
        @agents = {}
        @storage = storage || SimpleAcp::Storage::Memory.new
        @options = options
        @running_contexts = Concurrent::Map.new
      end

      # Register an agent using decorator-style syntax
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

      # Register an agent instance
      def register(agent)
        raise SimpleAcp::ValidationError, "Invalid agent" unless agent.valid?
        raise SimpleAcp::ConfigurationError, "Agent '#{agent.name}' already registered" if @agents.key?(agent.name)

        @agents[agent.name] = agent
        agent
      end

      # Unregister an agent
      def unregister(name)
        @agents.delete(name)
      end

      # Run an agent synchronously
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

      # Run an agent asynchronously (returns immediately)
      def run_async(agent_name:, input:, session_id: nil, session: nil)
        run, context = prepare_run(agent_name, input, session_id, session)

        Thread.new do
          begin
            run.start!
            @storage.save_run(run)

            output_messages = []
            execute_agent(context) do |yielded|
              case yielded
              when RunYield
                output_messages << yielded.message
              when RunYieldAwait
                return
              end
            end

            # Check if cancelled before completing
            if context.cancelled?
              run.cancelled!
            else
              run.complete!(output_messages)
              update_session_history(context.session, input, output_messages)
            end
          rescue StandardError => e
            run.fail!(e.message)
          ensure
            @storage.save_run(run)
            @running_contexts.delete(run.run_id)
          end
        end

        run
      end

      # Run an agent with streaming output
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

      # Resume an awaited run synchronously
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

      # Resume an awaited run with streaming
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

      # Cancel a running agent
      def cancel_run(run_id)
        run = @storage.get_run(run_id)
        raise SimpleAcp::NotFoundError, "Run '#{run_id}' not found" unless run

        context = @running_contexts[run_id]
        context&.cancel!

        run.cancelled!
        @storage.save_run(run)
        run
      end

      # Create the Rack application
      def to_app
        App.configure(self)
        App.freeze.app
      end

      # Start the server
      def run(port: 8000, host: "0.0.0.0", **puma_options)
        require "puma"

        app = to_app

        events = Puma::Events.new
        binder = Puma::Binder.new(events)
        binder.parse(["tcp://#{host}:#{port}"], events)

        server = Puma::Server.new(app, events)
        server.binder = binder

        puts "ACP Server running on http://#{host}:#{port}"
        puts "Registered agents: #{@agents.keys.join(', ')}"

        begin
          server.run.join
        rescue Interrupt
          puts "\nShutting down..."
          server.stop(true)
        end
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
