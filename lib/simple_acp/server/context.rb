# frozen_string_literal: true

module SimpleAcp
  module Server
    # Request context passed to agent handlers during execution.
    #
    # Provides access to input messages, session state, conversation history,
    # and methods for controlling execution flow.
    #
    # @example Accessing input
    #   server.agent("echo") do |context|
    #     text = context.input.first.text_content
    #     Models::Message.agent("You said: #{text}")
    #   end
    #
    # @example Using session state
    #   server.agent("counter") do |context|
    #     count = (context.state || 0) + 1
    #     context.set_state(count)
    #     Models::Message.agent("Count: #{count}")
    #   end
    class Context
      # @return [Models::Run] the current run being executed
      attr_reader :run

      # @return [Models::Session, nil] the session (if any)
      attr_reader :session

      # @return [Array<Models::Message>] input messages for this run
      attr_reader :input

      # @return [Server::Base] reference to the server
      attr_reader :server

      # Initialize a new context.
      #
      # @param run [Models::Run] the run being executed
      # @param session [Models::Session, nil] optional session
      # @param input [Array<Models::Message>] input messages
      # @param server [Server::Base] the server instance
      def initialize(run:, session:, input:, server:)
        @run = run
        @session = session
        @input = input
        @server = server
        @cancelled = false
      end

      # @return [String] the name of the agent being executed
      def agent_name
        @run.agent_name
      end

      # @return [String] the unique run ID
      def run_id
        @run.run_id
      end

      # @return [String, nil] the session ID if a session is active
      def session_id
        @session&.id
      end

      # Check if the run has been cancelled.
      #
      # @return [Boolean] true if cancelled
      def cancelled?
        @cancelled
      end

      # Mark the run as cancelled.
      #
      # @return [void]
      def cancel!
        @cancelled = true
      end

      # Get conversation history from the session.
      #
      # @return [Array<Models::Message>] previous messages in the session
      def history
        @session&.history || []
      end

      # Get arbitrary state data from the session.
      #
      # @return [Object, nil] the stored state data
      def state
        @session&.state
      end

      # Update the session state with new data.
      #
      # @param new_state [Object] the state data to store
      # @return [void]
      def set_state(new_state)
        @session&.set_state(new_state)
        @server.storage.save_session(@session) if @session
      end

      # Request additional input from the client, pausing execution.
      #
      # This puts the run into an "awaiting" state until the client
      # calls resume with the requested input.
      #
      # @param prompt_message [Models::Message] message to display to the client
      # @return [RunYieldAwait] yield this from your agent to pause
      #
      # @example Multi-turn conversation
      #   server.agent("questioner") do |context|
      #     Enumerator.new do |yielder|
      #       result = context.await_message(Models::Message.agent("What is your name?"))
      #       yielder << result
      #       name = context.resume_message&.text_content
      #       yielder << RunYield.new(Models::Message.agent("Hello, #{name}!"))
      #     end
      #   end
      def await_message(prompt_message)
        request = Models::MessageAwaitRequest.new(message: prompt_message)
        @run.await!(request)
        @server.storage.save_run(@run)

        # Return a result that indicates the run is awaiting
        RunYieldAwait.new(request: request)
      end

      # Log a message for debugging or trajectory tracking.
      #
      # @param message [String] the message to log
      # @return [void]
      def log(message)
        SimpleAcp.logger&.info("[#{agent_name}] #{message}")
      end

      # Get the resume message (only available during resume).
      #
      # This method returns nil for initial contexts. Override in
      # ResumeContext to return the actual resume message.
      #
      # @return [Models::Message, nil] nil for initial context
      def resume_message
        nil
      end
    end

    # Wrapper for yielding output messages from an agent.
    #
    # Use this when streaming responses from an Enumerator-based agent handler.
    #
    # @example
    #   Enumerator.new do |yielder|
    #     yielder << RunYield.new(Models::Message.agent("First message"))
    #     yielder << RunYield.new(Models::Message.agent("Second message"))
    #   end
    class RunYield
      # @return [Models::Message] the message to output
      attr_reader :message

      # Create a new message yield.
      #
      # @param message [Models::Message, Hash] the message to yield
      def initialize(message)
        @message = message.is_a?(Models::Message) ? message : Models::Message.from_hash(message)
      end
    end

    # Wrapper for pausing execution and awaiting client input.
    #
    # Yield this from an agent to pause execution until the client
    # resumes with the requested input.
    class RunYieldAwait
      # @return [Models::AwaitRequest] the await request details
      attr_reader :request

      # Create a new await yield.
      #
      # @param request [Models::AwaitRequest] the request for client input
      def initialize(request:)
        @request = request
      end
    end

    # Extended context for resuming an awaited run.
    #
    # Contains the client's response to the await request.
    class ResumeContext < Context
      # @return [Models::AwaitResume] the client's resume payload
      attr_reader :await_resume

      # Initialize a resume context.
      #
      # @param run [Models::Run] the run being resumed
      # @param session [Models::Session, nil] optional session
      # @param input [Array<Models::Message>] original input messages
      # @param server [Server::Base] the server instance
      # @param await_resume [Models::AwaitResume] the client's response
      def initialize(run:, session:, input:, server:, await_resume:)
        super(run: run, session: session, input: input, server: server)
        @await_resume = await_resume
      end

      # Get the message from the client's resume payload.
      #
      # @return [Models::Message, nil] the client's response message
      def resume_message
        @await_resume&.message
      end
    end
  end
end
